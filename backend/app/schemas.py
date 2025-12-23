from pydantic import BaseModel, EmailStr, Field
from datetime import date
from typing import Optional

class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"

class UserCreate(BaseModel):
    email: EmailStr
    password: str = Field(min_length=6)
    birthdate: date
    city: Optional[str] = None
    stake: Optional[str] = None
    lat: Optional[float] = None
    lon: Optional[float] = None
    bio: Optional[str] = None
    wants_adjacent_bucket: bool = False

class UserOut(BaseModel):
    id: int
    email: EmailStr
    city: Optional[str]
    stake: Optional[str]
    lat: Optional[float]
    lon: Optional[float]
    bio: Optional[str]
    photo_url: Optional[str] = None

    class Config:
        from_attributes = True

class PhotoOut(BaseModel):
    url: str
