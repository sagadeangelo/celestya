from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session, aliased
from sqlalchemy import func, desc, or_

from ..database import get_db
from ..deps import get_current_user
from .. import models, schemas

router = APIRouter()

@router.get("", response_model=List[schemas.ChatListOut])
def get_chats(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """
    Lista las conversaciones del usuario con:
    - info del otro usuario (peer)
    - último mensaje
    - contador de no leídos
    """
    # 1. Buscar conversaciones donde soy A o B
    convs = db.query(models.Conversation).filter(
        or_(
            models.Conversation.user_a_id == current_user.id,
            models.Conversation.user_b_id == current_user.id
        )
    ).all()

    results = []
    for conv in convs:
        # Determinar quién es el "otro"
        if conv.user_a_id == current_user.id:
            peer = conv.user_b
        else:
            peer = conv.user_a

        # Último mensaje
        last_msg = db.query(models.Message).filter(
            models.Message.conversation_id == conv.id
        ).order_by(desc(models.Message.id)).first()

        # Unread count: mensajes donde sender != yo, y read_at is null
        unread_count = db.query(models.Message).filter(
            models.Message.conversation_id == conv.id,
            models.Message.sender_id != current_user.id,
            models.Message.read_at == None
        ).count()

        results.append({
            "id": conv.id,
            "peer": peer,
            "last_message": last_msg,
            "unread_count": unread_count
        })

    # Ordenar por fecha de ultimo mensaje (desc), o created_at de conv
    results.sort(
        key=lambda x: x["last_message"].created_at if x["last_message"] else x["peer"].created_at, # fallback
        reverse=True
    )

    return results


@router.get("/{chat_id}/messages", response_model=List[schemas.MessageOut])
def get_messages(
    chat_id: int,
    before_id: Optional[int] = None,
    limit: int = 20,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    # 1. Validar acceso
    conv = db.query(models.Conversation).get(chat_id)
    if not conv:
        raise HTTPException(status_code=404, detail="Chat not found")
    
    if current_user.id not in [conv.user_a_id, conv.user_b_id]:
        raise HTTPException(status_code=403, detail="Not a member of this chat")

    query = db.query(models.Message).filter(models.Message.conversation_id == chat_id)

    if before_id:
        query = query.filter(models.Message.id < before_id)
    
    # Ordenamos desc para paginacion, luego podemos invertir o cliente maneja
    msgs = query.order_by(desc(models.Message.id)).limit(limit).all()
    
    return msgs


@router.post("/{chat_id}/messages", response_model=schemas.MessageOut)
def send_message(
    chat_id: int,
    msg_in: schemas.MessageCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    # 1. Validar acceso
    conv = db.query(models.Conversation).get(chat_id)
    if not conv:
        raise HTTPException(status_code=404, detail="Chat not found")
    
    if current_user.id not in [conv.user_a_id, conv.user_b_id]:
        raise HTTPException(status_code=403, detail="Not a member of this chat")

    # 2. Rate limit básico (opcional): chequear ultimo mensaje muy reciente?
    # Por ahora simple

    # 3. Crear mensaje
    new_msg = models.Message(
        conversation_id=chat_id,
        sender_id=current_user.id,
        body=msg_in.body.strip()
    )
    db.add(new_msg)
    
    # Actualizar updated_at de la conversacion (para ordenar Inbox)
    conv.updated_at = func.now()
    
    db.commit()
    db.refresh(new_msg)
    return new_msg


@router.post("/{chat_id}/read")
def mark_read(
    chat_id: int,
    read_in: schemas.MarkReadIn,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    conv = db.query(models.Conversation).get(chat_id)
    if not conv:
        raise HTTPException(status_code=404, detail="Chat not found")

    if current_user.id not in [conv.user_a_id, conv.user_b_id]:
        raise HTTPException(status_code=403, detail="Not a member of this chat")

    # Marcar como leídos los mensajes que NO son mios
    query = db.query(models.Message).filter(
        models.Message.conversation_id == chat_id,
        models.Message.sender_id != current_user.id,
        models.Message.read_at == None
    )

    if read_in.until_message_id:
        query = query.filter(models.Message.id <= read_in.until_message_id)

    query.update({models.Message.read_at: func.now()}, synchronize_session=False)
    db.commit()

    return {"ok": True}


# Opcional: Endpoint para iniciar chat desde Match
@router.post("/start/{match_id}", response_model=schemas.ChatListOut)
def start_chat_from_match(
    match_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    # 1. Buscar match
    match = db.query(models.Match).get(match_id)
    if not match:
        raise HTTPException(status_code=404, detail="Match not found")

    # 2. Validar que soy parte
    if current_user.id not in [match.user_a_id, match.user_b_id]:
        raise HTTPException(status_code=403, detail="Not your match")

    peer_id = match.user_b_id if match.user_a_id == current_user.id else match.user_a_id

    # 3. Buscar conversacion existente
    # Ordenamos IDs para busqueda si convención
    # O buscamos OR
    existing = db.query(models.Conversation).filter(
        or_(
            (models.Conversation.user_a_id == current_user.id) & (models.Conversation.user_b_id == peer_id),
            (models.Conversation.user_a_id == peer_id) & (models.Conversation.user_b_id == current_user.id),
        )
    ).first()

    if existing:
        # Reusar logica de retorno de ChatListOut
        peer = db.query(models.User).get(peer_id)
        last_msg = db.query(models.Message).filter(models.Message.conversation_id == existing.id).order_by(desc(models.Message.id)).first()
        return {
            "id": existing.id,
            "peer": peer,
            "last_message": last_msg,
            "unread_count": 0 
        }

    # 4. Crear nueva conversacion
    # Convención opcional user_a < user_b
    u1, u2 = sorted([current_user.id, peer_id])
    
    new_conv = models.Conversation(
        user_a_id=u1,
        user_b_id=u2
    )
    db.add(new_conv)
    db.commit()
    db.refresh(new_conv)

    peer = db.query(models.User).get(peer_id)
    return {
        "id": new_conv.id,
        "peer": peer,
        "last_message": None,
        "unread_count": 0
    }

@router.post("/start-with-user/{target_user_id}", response_model=schemas.ChatListOut)
def start_chat_with_user(
    target_user_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    # 1. Validar si existe MATCH entre yo y target
    # Consulta: Match donde (a=yo y b=target) O (a=target y b=yo)
    match = db.query(models.Match).filter(
        or_(
            (models.Match.user_a_id == current_user.id) & (models.Match.user_b_id == target_user_id),
            (models.Match.user_a_id == target_user_id) & (models.Match.user_b_id == current_user.id)
        )
    ).first()

    if not match:
        raise HTTPException(status_code=403, detail="No match found with this user")
    
    # 2. Reusar lógica de start match (podríamos refactorizar, pero duplicar es seguro aquí por simpleza)
    return start_chat_from_match(match.id, db, current_user)

