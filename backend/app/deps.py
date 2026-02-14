from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session

from .database import get_db
from . import models
from .security import decode_token

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
        print(f"[AUTH] decode_token HTTPException: {e.detail}")
        token_preview = (token[:12] + "...") if token else "empty"
        print(f"[AUTH] token preview: {token_preview}")
        raise e
    except Exception as e:
        # ✅ Cualquier otra cosa inesperada
        print(f"[AUTH] token invalid (unexpected): {type(e).__name__}: {e}")
        token_preview = (token[:12] + "...") if token else "empty"
        print(f"[AUTH] token preview: {token_preview}")
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

    return user
