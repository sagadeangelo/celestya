from sqlalchemy import Column, Integer, String, Date, Enum, Boolean, Float, ForeignKey
from sqlalchemy.orm import relationship
from .database import Base
from .enums import AgeBucket

class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)

    email = Column(String, unique=True, index=True, nullable=False)
    password_hash = Column(String, nullable=False)

    birthdate = Column(Date, nullable=False)
    age_bucket = Column(Enum(AgeBucket), nullable=False)

    city = Column(String, nullable=True)
    stake = Column(String, nullable=True)  # campo “estaca” opcional
    lat = Column(Float, nullable=True)
    lon = Column(Float, nullable=True)

    bio = Column(String, nullable=True)
    wants_adjacent_bucket = Column(Boolean, default=False)

    photo_path = Column(String, nullable=True)

class UserCompat(Base):
    __tablename__ = "user_compat"
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)

    # respuestas serializadas "qId:val|qId:val"
    answers = Column(String, nullable=False)
