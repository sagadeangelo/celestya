import logging
import uuid
from fastapi import UploadFile, File, APIRouter, HTTPException, Depends
from app.services.r2_client import upload_fileobj, presigned_get_url
from app.deps import get_current_user
from app.models import User

logger = logging.getLogger("api")
router = APIRouter()

@router.post("/upload")
async def upload(
    file: UploadFile = File(...),
    user: User = Depends(get_current_user)
):
    if not (file.content_type or "").startswith("image/"):
        raise HTTPException(status_code=400, detail="Solo imágenes por ahora")

    ext = (file.filename or "").split(".")[-1].lower()
    if ext not in ("png", "jpg", "jpeg", "webp"):
        ext = "png"

    key = f"uploads/user_{user.id}_{uuid.uuid4().hex}.{ext}"

    try:
        logger.info(f"Iniciando subida a R2: {key}")
        upload_fileobj(file.file, key=key, content_type=file.content_type)
        logger.info(f"Subida a R2 completada: {key}")
    except Exception as e:
        logger.error(f"Error crítico al subir a R2: {str(e)}")
        # Si falla R2, probablemente falten credenciales en .env
        raise HTTPException(
            status_code=500, 
            detail=f"Error al subir a almacenamiento remoto: {str(e)}. Verifica configuración R2."
        )

    return {
        "ok": True,
        "key": key,
        "url": presigned_get_url(key),
    }
