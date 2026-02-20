from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session

from .database import get_db
from . import models
from .security import decode_token, utcnow
from datetime import timedelta, timezone
# ...
import structlog

logger = structlog.get_logger("api")


# ✅ OJO: tokenUrl debe apuntar EXACTO a tu endpoint OAuth2 (form)
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")


def get_current_user(
    db: Session = Depends(get_db),
    token: str = Depends(oauth2_scheme),
) -> models.User:
    # ✅ Token viene SIN "Bearer " (fastapi lo extrae), aquí debe venir solo el JWT
    if not token or not token.strip():
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    try:
        user_id = decode_token(token.strip())
    except HTTPException as e:
        # ✅ Respeta el mensaje real del decoder (Invalid token / expired / missing sub etc)
        logger.warning("auth_token_decode_http_error", detail=e.detail, token_preview=(token[:12] + "...") if token else "empty")
        raise e
    except Exception as e:
        # ✅ Cualquier otra cosa inesperada
        logger.error("auth_token_invalid_unexpected", error=str(e), error_type=type(e).__name__, token_preview=(token[:12] + "...") if token else "empty")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    user = db.get(models.User, user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # ✅ Online Status: Update last_seen if > 2 minutes
    now = utcnow()
    
    last_seen_aware = user.last_seen
    if last_seen_aware and last_seen_aware.tzinfo is None:
        last_seen_aware = last_seen_aware.replace(tzinfo=timezone.utc)

    if not user.last_seen or (now - last_seen_aware > timedelta(minutes=2)):
        user.last_seen = now
        db.add(user)
        db.commit()
        db.refresh(user)

        db.refresh(user)

    structlog.contextvars.bind_contextvars(user_id=user.id)
    return user
