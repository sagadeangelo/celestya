from pydantic import BaseModel, EmailStr, Field
from datetime import date
from typing import Optional, Dict, Any


# ----------------------------
# Auth / Tokens
# ----------------------------

class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"


class UserCreate(BaseModel):
    email: EmailStr
    # bcrypt límite: 72 bytes
    password: str = Field(min_length=6, max_length=72)
    birthdate: date

    city: Optional[str] = None
    stake: Optional[str] = None
    lat: Optional[float] = None
    lon: Optional[float] = None
    bio: Optional[str] = None
    wants_adjacent_bucket: bool = False


# ----------------------------
# Users
# ----------------------------

class UserOut(BaseModel):
    id: int
    email: EmailStr
    email_verified: bool  # ✅ importante para el cliente

    city: Optional[str] = None
    stake: Optional[str] = None
    lat: Optional[float] = None
    lon: Optional[float] = None
    bio: Optional[str] = None

    photo_url: Optional[str] = None
    photo_key: Optional[str] = None  # ✅ si usas R2

    wants_adjacent_bucket: bool = False  # opcional útil para el cliente

    class Config:
        from_attributes = True


class PhotoOut(BaseModel):
    url: str


# ----------------------------
# Email Verification (6-digit code)
# ----------------------------

class ResendVerificationIn(BaseModel):
    email: EmailStr


class VerifyEmailIn(BaseModel):
    email: EmailStr
    code: str = Field(min_length=6, max_length=6)


class VerifyEmailOut(BaseModel):
    ok: bool = True
    message: str


# ----------------------------
# Quiz / Compat (13 preguntas)
# ----------------------------

class QuizAnswersIn(BaseModel):
    """
    answers puede ser:
    {
      "q1": 3,
      "q2": "algo",
      "q3": true,
      ...
    }
    """
    answers: Dict[str, Any] = Field(default_factory=dict)


class QuizAnswersOut(BaseModel):
    ok: bool = True
    message: str = "Guardado"
    answers: Dict[str, Any] = Field(default_factory=dict)
