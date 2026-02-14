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
    UniqueConstraint,
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
    name = Column(String(255), nullable=True)
    birthdate = Column(Date, nullable=False)
    age_bucket = Column(Enum(AgeBucket), nullable=False)

    city = Column(String(255), nullable=True)
    stake = Column(String(255), nullable=True)  # “estaca” opcional
    lat = Column(Float, nullable=True)
    lon = Column(Float, nullable=True)

    bio = Column(String, nullable=True)
    wants_adjacent_bucket = Column(Boolean, default=False, nullable=False)

    # Nuevo: Perfil expandido
    marital_status = Column(String(50), nullable=True)
    has_children = Column(Boolean, nullable=True)
    body_type = Column(String(50), nullable=True)

    height_cm = Column(Integer, nullable=True)
    education = Column(String(255), nullable=True)
    occupation = Column(String(255), nullable=True)
    interests = Column(JSON, nullable=False, default=list) # ✅ Lista de intereses

    mission_served = Column(String(255), nullable=True)
    mission_years = Column(String(50), nullable=True)
    favorite_calling = Column(String(255), nullable=True)
    favorite_scripture = Column(String(255), nullable=True)

    # ✅ NUEVO: Preferencias básicas para filtrar feed (mujer ve hombres / hombre ve mujeres)
    # Valores esperados: 'male' | 'female' (puedes expandir a futuro)
    gender = Column(String, nullable=True)   # Sexo del usuario
    show_me = Column(String, nullable=True)  # A quién quiere ver

    # Foto (legacy local + R2)
    photo_path = Column(String, nullable=True)  # legacy: ruta local ./media/...
    profile_photo_key = Column(String, nullable=True)   # R2: key principal
    gallery_photo_keys = Column(JSON, nullable=False, default=list) # ✅ Lista de keys extras

    # Verificación de email (código/token)
    email_verified = Column(Boolean, default=False, nullable=False)
    email_verification_token_hash = Column(String(255), nullable=True)  # 6-digit code hash
    email_verification_expires_at = Column(DateTime(timezone=True), nullable=True)

    # Link verification (UUID token)
    email_verification_link_token = Column(String(255), nullable=True, index=True)  # UUID for link
    email_verification_link_expires_at = Column(DateTime(timezone=True), nullable=True)
    email_verification_link_used = Column(Boolean, default=False, nullable=False)  # One-time use

    # Timestamps útiles
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    # ✅ recomendado: que tenga default al crear y update automático
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)

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


class Match(Base):
    """
    Representa un 'match' confirmado entre user_a y user_b.
    Convención: user_a_id < user_b_id para evitar duplicados,
    o simplemente unique constraint en (user_a, user_b).
    """
    __tablename__ = "matches"

    id = Column(Integer, primary_key=True, index=True)
    user_a_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    user_b_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    # Relaciones
    user_a = relationship("User", foreign_keys=[user_a_id])
    user_b = relationship("User", foreign_keys=[user_b_id])

    # Constraint para asegurar unicidad del par (a, b)
    __table_args__ = (
        UniqueConstraint('user_a_id', 'user_b_id', name='uq_match_ab'),
    )


class Conversation(Base):
    """
    Sala de chat entre dos usuarios.
    Solo debe existir si hay match (validar en lógica).
    """
    __tablename__ = "conversations"

    id = Column(Integer, primary_key=True, index=True)

    # Miembros del chat
    user_a_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    user_b_id = Column(Integer, ForeignKey("users.id"), nullable=False)

    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)

    # Relaciones
    user_a = relationship("User", foreign_keys=[user_a_id])
    user_b = relationship("User", foreign_keys=[user_b_id])

    # Relación con mensajes
    messages = relationship("Message", back_populates="conversation", cascade="all, delete-orphan")

    __table_args__ = (
        UniqueConstraint('user_a_id', 'user_b_id', name='uq_conversation_ab'),
    )


class Message(Base):
    __tablename__ = "messages"

    id = Column(Integer, primary_key=True, index=True)
    conversation_id = Column(Integer, ForeignKey("conversations.id"), nullable=False, index=True)
    sender_id = Column(Integer, ForeignKey("users.id"), nullable=False)

    body = Column(String(1000), nullable=False)  # Max 1000 chars

    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    read_at = Column(DateTime(timezone=True), nullable=True)  # Si está null, no leído

    conversation = relationship("Conversation", back_populates="messages")
    sender = relationship("User", foreign_keys=[sender_id])


class Report(Base):
    __tablename__ = "reports"

    id = Column(Integer, primary_key=True, index=True)
    reporter_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    reported_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    reason = Column(String(255), nullable=False)
    details = Column(String, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    reporter = relationship("User", foreign_keys=[reporter_id])
    reported = relationship("User", foreign_keys=[reported_id])


class Block(Base):
    __tablename__ = "blocks"

    id = Column(Integer, primary_key=True, index=True)
    blocker_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    blocked_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    blocker = relationship("User", foreign_keys=[blocker_id])
    blocked = relationship("User", foreign_keys=[blocked_id])

    __table_args__ = (
        UniqueConstraint('blocker_id', 'blocked_id', name='uq_block_active'),
    )
