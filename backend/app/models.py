from sqlalchemy import (
    Column,
    Integer,
    String,
    Date,
    DateTime,
    Enum,
    Boolean,
    Float,
    ForeignKey,
    func,
)
from sqlalchemy.orm import relationship
from sqlalchemy.types import JSON  # ✅ para guardar respuestas como dict/list

from .database import Base
from .enums import AgeBucket


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)

    # Auth
    email = Column(String(255), unique=True, index=True, nullable=False)
    password_hash = Column(String(255), nullable=False)

    # Perfil base
    birthdate = Column(Date, nullable=False)
    age_bucket = Column(Enum(AgeBucket), nullable=False)

    city = Column(String(255), nullable=True)
    stake = Column(String(255), nullable=True)  # “estaca” opcional
    lat = Column(Float, nullable=True)
    lon = Column(Float, nullable=True)

    bio = Column(String, nullable=True)
    wants_adjacent_bucket = Column(Boolean, default=False, nullable=False)

    # Foto (legacy local + R2)
    photo_path = Column(String, nullable=True)  # legacy: ruta local ./media/...
    photo_key = Column(String, nullable=True)   # NUEVO: key en R2, ej: users/123/photo_xxx.png

    # Verificación de email (código/token)
    email_verified = Column(Boolean, default=False, nullable=False)
    email_verification_token_hash = Column(String(255), nullable=True)
    email_verification_expires_at = Column(DateTime(timezone=True), nullable=True)

    # Timestamps útiles
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), onupdate=func.now(), nullable=True)

    # Relación 1 a 1 con compat
    compat = relationship(
        "UserCompat",
        back_populates="user",
        cascade="all, delete-orphan",
        passive_deletes=True,
        uselist=False,
    )


class UserCompat(Base):
    __tablename__ = "user_compat"

    id = Column(Integer, primary_key=True)
    user_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        unique=True,  # ✅ 1 registro por usuario
    )

    # ✅ Guarda JSON, ejemplo:
    # {"q1": 3, "q2": "introvertido", "q3": true, ...}
    answers = Column(JSON, nullable=False, default=dict)

    user = relationship("User", back_populates="compat")
