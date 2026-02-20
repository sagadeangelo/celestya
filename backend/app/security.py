import os
import secrets
import hashlib
from datetime import datetime, timedelta, timezone

from passlib.context import CryptContext
from jose import jwt, JWTError


# ============================
# ✅ JWT CONFIG (UNIFICADO)
# ============================
JWT_SECRET = os.getenv("JWT_SECRET") or os.getenv("SECRET_KEY") or ""
JWT_ALGORITHM = os.getenv("JWT_ALGORITHM", "HS256")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "60"))  # Reduced to 60m
REFRESH_TOKEN_EXPIRE_DAYS = int(os.getenv("REFRESH_TOKEN_EXPIRE_DAYS", "30"))  # 30 days

if not JWT_SECRET:
    raise RuntimeError("JWT secret missing: set JWT_SECRET (or SECRET_KEY) in environment.")

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


# ----------------------------
# Password hashing (bcrypt)
# ----------------------------
def hash_password(raw: str) -> str:
    raw = (raw or "").strip()
    if len(raw.encode("utf-8")) > 72:
        raise ValueError("La contraseña no puede exceder 72 bytes (límite bcrypt).")
    return pwd_context.hash(raw)


def verify_password(raw: str, hashed: str) -> bool:
    return pwd_context.verify((raw or ""), hashed)


# ----------------------------
# JWT helpers
# ----------------------------
def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def create_access_token(sub: int) -> str:
    """
    ✅ IMPORTANTE: `sub` DEBE ser string para python-jose.
    """
    exp = utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode = {
        "sub": str(int(sub)),            # ✅ string
        "exp": int(exp.timestamp()),
    }
    return jwt.encode(to_encode, JWT_SECRET, algorithm=JWT_ALGORITHM)


def decode_token(token: str) -> int:
    """
    Devuelve user_id como int.
    """
    payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
    sub = payload.get("sub")
    if sub is None:
        raise JWTError("Missing 'sub' in token")
    return int(sub)


# ----------------------------
# Email verification helpers
# ----------------------------
def make_token() -> str:
    return secrets.token_urlsafe(32)


def hash_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def create_refresh_token() -> str:
    """
    Generates a secure random string for refresh token.
    Does NOT return a JWT.
    """
    return secrets.token_urlsafe(64)
