from fastapi import APIRouter, Query
from app.services.r2_client import presigned_get_url

router = APIRouter(prefix="/media", tags=["media"])

@router.get("/url")
def get_media_url(key: str = Query(...), expires: int = 900):
    # expires en segundos (ej: 900 = 15 min)
    url = presigned_get_url(key=key, expires_seconds=expires)
    return {"url": url, "expires": expires}

@router.get("/urls/batch")
def get_media_urls_batch(keys: list[str] = Query(...), expires: int = 900):
    items = []
    for key in keys:
        if key:
            url = presigned_get_url(key=key, expires_seconds=expires)
            items.append({"key": key, "url": url})
    return {"ok": True, "items": items, "expires": expires}
