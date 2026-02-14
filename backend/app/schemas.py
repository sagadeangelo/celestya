from __future__ import annotations

from datetime import date, datetime
from typing import Optional, Dict, Any, List

from pydantic import BaseModel, EmailStr, Field, ConfigDict


# ----------------------------
# Auth / Register
# ----------------------------
class UserCreate(BaseModel):
    email: EmailStr
    password: str = Field(min_length=6, max_length=72)
    birthdate: date

    # opcionales (según tu OpenAPI actual)
    city: Optional[str] = None
    stake: Optional[str] = None
    lat: Optional[float] = None
    lon: Optional[float] = None
    bio: Optional[str] = None
    wants_adjacent_bucket: bool = False

    marital_status: Optional[str] = None
    has_children: Optional[bool] = None
    body_type: Optional[str] = None

    # IMPORTANTE: si tu backend ya concatena first/last, aquí puede quedarse como name (opcional)
    name: Optional[str] = None


class RegisterResponse(BaseModel):
    status: str = "pending_verification"
    email: EmailStr


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"


# ----------------------------
# Users
# ----------------------------
class UserUpdate(BaseModel):
    model_config = ConfigDict(populate_by_name=True, extra="ignore")

    city: Optional[str] = None
    stake: Optional[str] = None
    lat: Optional[float] = None
    lon: Optional[float] = None
    bio: Optional[str] = None
    wants_adjacent_bucket: Optional[bool] = None

    marital_status: Optional[str] = None
    has_children: Optional[bool] = None
    body_type: Optional[str] = None

    name: Optional[str] = None
    birthdate: Optional[date] = None
    gender: Optional[str] = None
    
    # Aliases for Flutter camelCase
    height_cm: Optional[int] = Field(None, alias="heightCm")
    education: Optional[str] = None
    occupation: Optional[str] = None
    interests: Optional[List[str]] = None

    mission_served: Optional[str] = Field(None, alias="missionServed")
    mission_years: Optional[str] = Field(None, alias="missionYears")
    favorite_calling: Optional[str] = Field(None, alias="favoriteCalling")
    favorite_scripture: Optional[str] = Field(None, alias="favoriteScripture")

    profile_photo_key: Optional[str] = None
    gallery_photo_keys: Optional[List[str]] = None

    photo_path: Optional[str] = None


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True, populate_by_name=True)

    id: int
    email: EmailStr
    name: Optional[str] = None
    birthdate: Optional[date] = None
    email_verified: bool

    city: Optional[str] = None
    stake: Optional[str] = None
    lat: Optional[float] = None
    lon: Optional[float] = None
    bio: Optional[str] = None

    photo_url: Optional[str] = None
    photo_urls: List[str] = Field(default_factory=list)

    profile_photo_key: Optional[str] = None
    gallery_photo_keys: List[str] = Field(default_factory=list)

    wants_adjacent_bucket: bool = False

    marital_status: Optional[str] = None
    has_children: Optional[bool] = None
    body_type: Optional[str] = None

    gender: Optional[str] = None
    height_cm: Optional[int] = Field(None, alias="heightCm")
    education: Optional[str] = None
    occupation: Optional[str] = None
    interests: List[str] = Field(default_factory=list)

    mission_served: Optional[str] = Field(None, alias="missionServed")
    mission_years: Optional[str] = Field(None, alias="missionYears")
    favorite_calling: Optional[str] = Field(None, alias="favoriteCalling")
    favorite_scripture: Optional[str] = Field(None, alias="favoriteScripture")


class PhotoOut(BaseModel):
    url: str


# ----------------------------
# R2 photo key (Opción B)
# ----------------------------
class PhotoKeyIn(BaseModel):
    profile_photo_key: str


class PhotoKeyOut(BaseModel):
    ok: bool = True
    profile_photo_key: Optional[str] = None


class PhotoUrlOut(BaseModel):
    ok: bool = True
    url: Optional[str] = None
    profile_photo_key: Optional[str] = None
    expires: int = 900


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
    access_token: Optional[str] = None


# ----------------------------
# Quiz / Compat
# ----------------------------
class QuizAnswersIn(BaseModel):
    answers: Dict[str, Any] = Field(default_factory=dict)
    version: Optional[str] = None


class QuizAnswersOut(BaseModel):
    user_id: int
    answers: Dict[str, Any] = Field(default_factory=dict)
    version: Optional[str] = None


# ----------------------------
# Messaging
# ----------------------------
class MessageOut(BaseModel):
    id: int
    sender_id: int
    body: str
    created_at: datetime
    read_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class ChatPeerOut(BaseModel):
    """Resumen del otro usuario en el chat"""
    id: int
    email: str
    city: Optional[str] = None
    stake: Optional[str] = None
    photo_url: Optional[str] = None
    profile_photo_key: Optional[str] = None

    class Config:
        from_attributes = True


class ChatListOut(BaseModel):
    id: int
    peer: ChatPeerOut
    last_message: Optional[MessageOut] = None
    unread_count: int = 0

    class Config:
        from_attributes = True


class MessageCreate(BaseModel):
    body: str = Field(min_length=1, max_length=1000)


class MarkReadIn(BaseModel):
    # Opcional: hasta qué mensaje leer. Si es null, lee todo.
    until_message_id: Optional[int] = None
