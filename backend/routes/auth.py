import os
from datetime import date as d, timedelta
from fastapi import APIRouter, Depends, HTTPException, Form
from sqlalchemy.orm import Session

from ..database import get_db
from .. import models, schemas
from ..security import (
    hash_password,
    verify_password,
    create_access_token,
    make_token,
    hash_token,
    utcnow,
)
from ..enums import AgeBucket
from ..app.emailer import send_email, verification_email_html  # ✅ correcto: backend/app/emailer.py

router = APIRouter()

PUBLIC_BASE_URL = os.getenv("PUBLIC_BASE_URL", "https://celestya-api.lasagadeangelo.com.mx")


def _calc_age(birth: d) -> int:
    t = d.today()
    return t.year - birth.year - ((t.month, t.day) < (birth.month, birth.day))


def _bucket(age: int) -> AgeBucket:
    if 18 <= age <= 25:
        return AgeBucket.A_18_25
    if 26 <= age <= 45:
        return AgeBucket.B_26_45
    return AgeBucket.C_45_75_PLUS


@router.post("/register", response_model=schemas.Token)
def register(payload: schemas.UserCreate, db: Session = Depends(get_db)):
    if db.query(models.User).filter(models.User.email == payload.email).first():
        raise HTTPException(status_code=400, detail="Email ya registrado")

    age = _calc_age(payload.birthdate)
    if age < 18:
        raise HTTPException(status_code=400, detail="Debes tener 18 años o más")

    user = models.User(
        email=payload.email.lower(),
        password_hash=hash_password(payload.password),
        birthdate=payload.birthdate,
        age_bucket=_bucket(age),
        city=payload.city,
        stake=payload.stake,
        lat=payload.lat,
        lon=payload.lon,
        bio=payload.bio,
        wants_adjacent_bucket=payload.wants_adjacent_bucket,
        email_verified=False,
    )

    token = make_token()
    user.email_verification_token_hash = hash_token(token)
    user.email_verification_expires_at = utcnow() + timedelta(hours=24)

    db.add(user)
    db.commit()
    db.refresh(user)

    verify_url = f"{PUBLIC_BASE_URL}/verify-email?token={token}"
    send_email(
        to_email=user.email,
        subject="Verifica tu correo - Celestya",
        html=verification_email_html(verify_url),
    )

    return {"access_token": create_access_token(user.id)}


@router.get("/verify-email", response_model=schemas.VerifyEmailOut)
def verify_email(token: str, db: Session = Depends(get_db)):
    token_h = hash_token(token)

    user = (
        db.query(models.User)
        .filter(models.User.email_verification_token_hash == token_h)
        .first()
    )
    if not user:
        raise HTTPException(status_code=400, detail="Token inválido")

    if (not user.email_verification_expires_at) or (user.email_verification_expires_at < utcnow()):
        raise HTTPException(status_code=400, detail="Token expirado")

    user.email_verified = True
    user.email_verification_token_hash = None
    user.email_verification_expires_at = None
    db.commit()

    return {"ok": True, "message": "Correo verificado. Ya puedes iniciar sesión."}


@router.post("/resend-verification", response_model=schemas.VerifyEmailOut)
def resend_verification(payload: schemas.ResendVerificationIn, db: Session = Depends(get_db)):
    email = payload.email.lower()

    user = db.query(models.User).filter(models.User.email == email).first()

    if not user:
        return {"ok": True, "message": "Si el correo existe, te enviamos un enlace."}

    if user.email_verified:
        return {"ok": True, "message": "Este correo ya está verificado."}

    token = make_token()
    user.email_verification_token_hash = hash_token(token)
    user.email_verification_expires_at = utcnow() + timedelta(hours=24)
    db.commit()

    verify_url = f"{PUBLIC_BASE_URL}/verify-email?token={token}"
    send_email(
        to_email=user.email,
        subject="Reenvío de verificación - Celestya",
        html=verification_email_html(verify_url),
    )

    return {"ok": True, "message": "Si el correo existe, te enviamos un enlace."}


@router.post("/login", response_model=schemas.Token)
def login(username: str = Form(...), password: str = Form(...), db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.email == username.lower()).first()
    if not user or not verify_password(password, user.password_hash):
        raise HTTPException(status_code=400, detail="Credenciales inválidas")

    if not user.email_verified:
        raise HTTPException(status_code=403, detail="Verifica tu correo antes de entrar")

    return {"access_token": create_access_token(user.id)}  # ✅ comentario correcto
