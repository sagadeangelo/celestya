import os
from fastapi import APIRouter, Header, HTTPException, status, Depends
from sqlalchemy.orm import Session
from pydantic import BaseModel, EmailStr

from ..database import get_db
from app.emailer import send_email, ResendError, RESEND_API_KEY, RESEND_ENDPOINT

router = APIRouter()

@router.post("/cleanup-pending-users")
def cleanup_pending_users(
    db: Session = Depends(get_db),
    x_debug_token: str | None = Header(default=None, alias="X-Debug-Token"),
):
    """
    Elimina usuarios no verificados que:
    - Ya tienen el código de verificación expirado.
    - O fueron creados hace más de 24 horas.
    Requiere X-Debug-Token.
    """
    debug_token = os.getenv("DEBUG_TOKEN")
    if not debug_token or x_debug_token != debug_token:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Route not found",
        )

    from datetime import datetime, timedelta, timezone
    from .. import models
    from ..security import utcnow

    now = utcnow()
    yesterday = now - timedelta(hours=24)

    # Buscar usuarios no verificados expirados o viejos
    query = db.query(models.User).filter(
        models.User.email_verified == False,
        (
            (models.User.email_verification_expires_at < now) |
            (models.User.created_at < yesterday)
        )
    )

    count = query.delete(synchronize_session=False)
    db.commit()

    return {"ok": True, "deleted_count": count}

class TestEmailRequest(BaseModel):
    email: EmailStr


@router.post("/test-email")
def test_email(
    request: TestEmailRequest,
    x_debug_token: str | None = Header(default=None, alias="X-Debug-Token"),
):
    debug_token = os.getenv("DEBUG_TOKEN")

    # Oculta endpoint si falta token o no coincide
    if not debug_token or x_debug_token != debug_token:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Route not found",
        )

    try:
        result = send_email(
            to_email=str(request.email),
            subject="Celestya Debug",
            html="<b>ok</b>",
        )

        resend_id = None
        if isinstance(result, dict):
            resend_id = result.get("id") or result.get("resend_id")

        return {"ok": True, "resend_id": resend_id}

    except ResendError as e:
        return {"ok": False, "status": e.status_code, "body": e.body}
    except Exception as e:
        return {"ok": False, "error": str(e)}

@router.get("/user-photo")
def get_user_photo_debug(
    email: EmailStr,
    db: Session = Depends(get_db),
    x_debug_token: str | None = Header(default=None, alias="X-Debug-Token"),
):
    debug_token = os.getenv("DEBUG_TOKEN")
    if not debug_token or x_debug_token != debug_token:
        raise HTTPException(status_code=404, detail="Route not found")

    from .. import models
    user = db.query(models.User).filter(models.User.email == email).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    return {
        "email": user.email,
        "profile_photo_key": user.profile_photo_key,
        "gallery_photo_keys": user.gallery_photo_keys or [],
        "photo_url": user.photo_path, # local path if any
        "updated_at": user.updated_at
    }

class SetPhotoKeyRequest(BaseModel):
    email: EmailStr
    profile_photo_key: str

@router.post("/set-photo-key")
def set_photo_key_debug(
    request: SetPhotoKeyRequest,
    db: Session = Depends(get_db),
    x_debug_token: str | None = Header(default=None, alias="X-Debug-Token"),
):
    debug_token = os.getenv("DEBUG_TOKEN")
    if not debug_token or x_debug_token != debug_token:
        raise HTTPException(status_code=404, detail="Route not found")

    from .. import models
    user = db.query(models.User).filter(models.User.email == request.email).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    user.profile_photo_key = request.profile_photo_key
    db.commit()
    return {"ok": True, "profile_photo_key": user.profile_photo_key}
@router.get("/check-email-status")
def check_email_status(
    email_id: str,
    x_debug_token: str | None = Header(default=None, alias="X-Debug-Token"),
):
    """
    Consulta el estado de un correo específico en Resend usando el ID.
    Requiere X-Debug-Token.
    """
    debug_token = os.getenv("DEBUG_TOKEN")
    if not debug_token or x_debug_token != debug_token:
        raise HTTPException(status_code=404, detail="Route not found")

    if not RESEND_API_KEY:
        raise HTTPException(status_code=500, detail="RESEND_API_KEY not configured")

    import urllib.request
    import json
    
    url = f"{RESEND_ENDPOINT}/{email_id}"
    req = urllib.request.Request(
        url,
        headers={
            "Authorization": f"Bearer {RESEND_API_KEY}",
            "Accept": "application/json",
        },
        method="GET"
    )

    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            body = resp.read().decode("utf-8")
            return json.loads(body)
    except Exception as e:
        return {"ok": False, "error": str(e)}
