import logging
import uuid
from fastapi import UploadFile, File, APIRouter, HTTPException, Depends
from app.services.r2_client import upload_fileobj, presigned_get_url
from app.deps import get_current_user
from app.models import User

logger = logging.getLogger("api")
router = APIRouter()

from app.database import get_db
from sqlalchemy.orm import Session

@router.post("/upload")
async def upload(
    file: UploadFile = File(...),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Detectar si es audio por Content-Type o extensión
    content_type = file.content_type or ""
    is_audio = content_type.startswith("audio/") or \
               (file.filename or "").lower().endswith((".m4a", ".mp3", ".aac", ".mp4", ".wav", ".webm"))
    
    # Validar tipos permitidos según Prompt 2
    if is_audio:
        allowed_audio = ("audio/mpeg", "audio/mp4", "audio/aac", "audio/x-m4a", "audio/webm")
        # Si no tiene content_type claro, nos basamos en extensión para asignarlo luego
        if content_type and content_type not in allowed_audio and not content_type.startswith("audio/"):
             raise HTTPException(status_code=400, detail=f"Tipo de audio no soportado: {content_type}")
    elif not content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Solo imágenes o audios de presentación")

    ext = (file.filename or "").split(".")[-1].lower()
    
    if is_audio:
        # Convención fija para voice_intro según Prompt 2
        if ext not in ("m4a", "mp3", "aac", "mp4", "wav", "webm"):
            ext = "m4a"
        key = f"users/{user.id}/voice_intro.{ext}"
        logger.info(f"voice_intro upload received: user_id={user.id}, content_type={content_type}, ext={ext}")
    else:
        # Imágenes siguen el flujo aleatorio actual
        if ext not in ("png", "jpg", "jpeg", "webp"):
            ext = "png"
        key = f"uploads/user_{user.id}_{uuid.uuid4().hex}.{ext}"

    try:
        # Asegurarnos de que el content_type sea correcto para audio si falta o es genérico
        if is_audio and (not content_type or content_type == "application/octet-stream"):
            content_type = f"audio/{ext}" if ext != "m4a" else "audio/x-m4a"

        upload_fileobj(file.file, key=key, content_type=content_type)
        logger.info(f"Subida a R2 completada: {key}")

        # Persistencia automática para audios (BACKEND-ONLY logic)
        if is_audio:
            user.voice_intro_key = key
            db.add(user)
            db.commit()
            logger.info(f"voice_intro persisted for user_id={user.id} (key={key})")

    except Exception as e:
        logger.error(f"Error crítico en upload: {str(e)}")
        db.rollback()
        raise HTTPException(
            status_code=500, 
            detail=f"Error al procesar subida: {str(e)}"
        )

    # URL presigned con expiración razonable (3600s = 60 min)
    res_url = presigned_get_url(key, expires_seconds=3600)
    
    response = {
        "ok": True,
        "url": res_url,
    }
    
    if is_audio:
        response["voice_intro_exists"] = True
        response["voice_intro_url"] = res_url
    else:
        response["key"] = key

    return response
