import os
import secrets
import hashlib
from datetime import datetime, timedelta, timezone

from passlib.context import CryptContext
from jose import jwt


SECRET_KEY = os.getenv("SECRET_KEY", "change-this-please")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "2880"))
ALGO = "HS256"

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


# ----------------------------
# Password hashing (bcrypt)
# ----------------------------
def hash_password(raw: str) -> str:
    raw = (raw or "").strip()

    # bcrypt límite: 72 bytes
    if len(raw.encode("utf-8")) > 72:
        raise ValueError("La contraseña no puede exceder 72 bytes (límite bcrypt).")

    return pwd_context.hash(raw)


def verify_password(raw: str, hashed: str) -> bool:
    return pwd_context.verify((raw or ""), hashed)


# ----------------------------
# JWT helpers
# ----------------------------
def utcnow() -> datetime:
    # ✅ SIEMPRE aware en UTC
    return datetime.now(timezone.utc)


def create_access_token(sub: int) -> str:
    exp = utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)

    # jose puede aceptar datetime o timestamp; dejamos timestamp int
    to_encode = {
        "sub": int(sub),
        "exp": int(exp.timestamp()),
    }
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGO)


def decode_token(token: str) -> int:
    payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGO])
    return int(payload["sub"])


# ----------------------------
# Email verification helpers
# ----------------------------
def make_token() -> str:
    # token largo, seguro para enviar por URL (si usas links)
    return secrets.token_urlsafe(32)


def hash_token(token: str) -> str:
    # guardas el hash, no el token plano
    return hashlib.sha256(token.encode("utf-8")).hexdigest()
