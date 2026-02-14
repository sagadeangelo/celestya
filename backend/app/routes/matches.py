from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import or_
from ..database import get_db
from ..deps import get_current_user
from .. import models
from .users import user_to_out

router = APIRouter()


@router.get("/suggested")
def suggested(db: Session = Depends(get_db), user: models.User = Depends(get_current_user)):
    # PASO 3A: Gate de descubrimiento (Sincronizado con front)
    has_photo = bool(user.profile_photo_key or user.photo_path)
    has_gender = bool(user.gender and str(user.gender).strip())
    has_name = bool(user.name and user.name.lower() != "null")
    
    is_ready = has_photo and has_gender and has_name
    
    # Logs para depuración
    print(f"[GATE] user={user.id} photo={has_photo} gender={has_gender} name={has_name} READY={is_ready}")
    
    # Requisitos secundarios (no bloquean pero se loguean)
    has_height = user.height_cm is not None and user.height_cm > 0
    has_body = bool(user.body_type and str(user.body_type).strip())
    if not has_height or not has_body:
        print(f"[GATE-WARN] user={user.id} missing height/body but allowed.")

    if not is_ready:
        missing = []
        if not has_photo: missing.append("photo")
        if not has_gender: missing.append("gender")
        if not has_name: missing.append("name")

    # 1) IDs que yo bloqueé
    my_blocks = (
        db.query(models.Block.blocked_id)
        .filter(models.Block.blocker_id == user.id)
        .all()
    )
    blocked_ids = {b[0] for b in my_blocks}

    # 2) IDs que me bloquearon a mí
    blocked_by = (
        db.query(models.Block.blocker_id)
        .filter(models.Block.blocked_id == user.id)
        .all()
    )
    blocker_ids = {b[0] for b in blocked_by}

    # 3) Excluir: yo + bloqueos
    exclude_ids = blocked_ids | blocker_ids | {user.id}

    # 4) Base query
    q = db.query(models.User).filter(~models.User.id.in_(exclude_ids))

    # 5) ✅ Filtro por preferencia (mutuo)
    # Requiere que models.User ya tenga gender y show_me (y que existan en DB)
    if getattr(user, "gender", None) and getattr(user, "show_me", None):
        # Yo quiero ver: user.show_me
        q = q.filter(models.User.gender == user.show_me)

        # Recomendado: reciprocidad (que esa persona también quiera verme a mí)
        q = q.filter(models.User.show_me == user.gender)

    # 6) Limitar
    candidates = q.limit(20).all()

    return {"matches": [user_to_out(c) for c in candidates]}


@router.get("/confirmed")
def get_confirmed_matches(db: Session = Depends(get_db), user: models.User = Depends(get_current_user)):
    """
    Returns list of users with whom the current user has a confirmed match (mutual likelihood/match).
    In this system, a 'Match' row exists in 'matches' table.
    """
    matches_a = db.query(models.Match).filter(models.Match.user_a_id == user.id).all()
    matches_b = db.query(models.Match).filter(models.Match.user_b_id == user.id).all()

    confirmed_users = []

    for m in matches_a:
        confirmed_users.append(m.user_b)

    for m in matches_b:
        confirmed_users.append(m.user_a)

    return [user_to_out(u) for u in confirmed_users]
