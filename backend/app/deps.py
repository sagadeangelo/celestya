from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session

from .database import get_db
from . import models
from .security import decode_token, utcnow
import datetime
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
            detail={"detail": "Missing token", "code": "INVALID_TOKEN"},
            headers={"WWW-Authenticate": "Bearer"},
        )

    try:
        user_id = decode_token(token.strip())
    except Exception as e:
        error_msg = str(e)
        error_type = type(e).__name__
        
        # ✅ Handle ExpiredSignatureError specifically for clearer frontend response
        if "expired" in error_msg.lower() or error_type == "ExpiredSignatureError":
            logger.warning("auth_token_expired", error=error_msg)
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail={"detail": "token_expired", "code": "ACCESS_EXPIRED"},
                headers={"WWW-Authenticate": "Bearer"},
            )

        # ✅ Cualquier otra cosa inesperada
        logger.error("auth_token_invalid_unexpected", error=error_msg, error_type=error_type, token_preview=(token[:12] + "...") if token else "empty")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"detail": "invalid_token", "code": "INVALID_TOKEN"},
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
        last_seen_aware = last_seen_aware.replace(tzinfo=datetime.timezone.utc)

    if not user.last_seen or (now - last_seen_aware > datetime.timedelta(minutes=2)):
        user.last_seen = now
        db.add(user)
        db.commit()
        db.refresh(user)

    structlog.contextvars.bind_contextvars(user_id=user.id)
    return user
