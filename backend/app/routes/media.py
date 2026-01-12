from fastapi import APIRouter, Query
from app.services.r2_client import presigned_get_url

router = APIRouter(prefix="/media", tags=["media"])

@router.get("/url")
def get_media_url(key: str = Query(...), expires: int = 900):
    # expires en segundos (ej: 900 = 15 min)
    url = presigned_get_url(key=key, expires_seconds=expires)
    return {"url": url, "expires": expires}
