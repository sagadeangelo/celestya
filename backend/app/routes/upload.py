import uuid
from fastapi import UploadFile, File, APIRouter, HTTPException
from app.services.r2_client import upload_fileobj, presigned_get_url  # ajusta el import a tu ruta real

router = APIRouter()

@router.post("/upload")
async def upload(file: UploadFile = File(...)):
    if not (file.content_type or "").startswith("image/"):
        raise HTTPException(status_code=400, detail="Solo imágenes por ahora")

    ext = (file.filename or "").split(".")[-1].lower()
    if ext not in ("png", "jpg", "jpeg", "webp"):
        ext = "png"

    key = f"uploads/{uuid.uuid4().hex}.{ext}"

    upload_fileobj(file.file, key=key, content_type=file.content_type)

    return {
        "ok": True,
        "key": key,
        "url": presigned_get_url(key),
    }
