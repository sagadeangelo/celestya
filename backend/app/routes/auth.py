import os
import secrets
from datetime import date as d, timedelta, datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Form
from sqlalchemy.orm import Session

from ..database import get_db
from .. import models, schemas
from ..security import (
    hash_password,
    verify_password,
    create_access_token,
    hash_token,
    utcnow,
)
from ..enums import AgeBucket
from app.emailer import send_email  # backend/app/emailer.py

router = APIRouter()

PUBLIC_BASE_URL = os.getenv("PUBLIC_BASE_URL", "http://192.168.1.84:8002")

# Ajustables por env
VERIFY_CODE_TTL_MIN = int(os.getenv("VERIFY_CODE_TTL_MIN", "15"))  # 15 min
VERIFY_CODE_SUBJECT = os.getenv("VERIFY_CODE_SUBJECT", "Tu código de verificación - Celestya")


def _calc_age(birth: d) -> int:
    t = d.today()
    return t.year - birth.year - ((t.month, t.day) < (birth.month, birth.day))


def _bucket(age: int) -> AgeBucket:
    if 18 <= age <= 25:
        return AgeBucket.A_18_25
    if 26 <= age <= 45:
        return AgeBucket.B_26_45
    return AgeBucket.C_45_75_PLUS


def _generate_6digit_code() -> str:
    return f"{secrets.randbelow(1_000_000):06d}"


def _verification_code_email_html(code: str) -> str:
    return f"""
    <div style="font-family: Arial, sans-serif; line-height: 1.4;">
      <h2>Verifica tu correo</h2>
      <p>Tu código de verificación es:</p>
      <div style="font-size: 32px; font-weight: 700; letter-spacing: 6px; margin: 12px 0;">
        {code}
      </div>
      <p>Este código expira en <b>{VERIFY_CODE_TTL_MIN} minutos</b>.</p>
      <p>Si no solicitaste esta cuenta, ignora este correo.</p>
      <hr/>
      <p style="color:#666; font-size:12px;">Celestya</p>
    </div>
    """


def _to_utc_aware(dt: datetime) -> datetime:
    """
    Convierte datetime a UTC-aware SIEMPRE.
    - Si viene naive (sin tzinfo), asumimos que es UTC.
    - Si viene aware, lo convertimos a UTC.
    """
    if dt is None:
        return None
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


@router.post("/register", response_model=schemas.Token)
def register(payload: schemas.UserCreate, db: Session = Depends(get_db)):
    email = payload.email.lower().strip()

    if db.query(models.User).filter(models.User.email == email).first():
        raise HTTPException(status_code=400, detail="Email ya registrado")

    age = _calc_age(payload.birthdate)
    if age < 18:
        raise HTTPException(status_code=400, detail="Debes tener 18 años o más")

    # Hash con manejo de error bcrypt 72 bytes
    try:
        pw_hash = hash_password(payload.password)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    user = models.User(
        email=email,
        password_hash=pw_hash,
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

    # Generar código 6 dígitos, guardar hash y expiración
    code = _generate_6digit_code()
    user.email_verification_token_hash = hash_token(code)
    user.email_verification_expires_at = utcnow() + timedelta(minutes=VERIFY_CODE_TTL_MIN)

    db.add(user)
    db.commit()
    db.refresh(user)

    # Enviar email con código
    print("[REGISTER] sending verification code to:", user.email)
    send_email(
        to_email=user.email,
        subject=VERIFY_CODE_SUBJECT,
        html=_verification_code_email_html(code),
    )

    # Devuelve access_token aunque aún no verifique (login seguirá bloqueado)
    return {"access_token": create_access_token(user.id)}


@router.post("/verify-email", response_model=schemas.VerifyEmailOut)
def verify_email(payload: schemas.VerifyEmailIn, db: Session = Depends(get_db)):
    """
    Espera JSON:
    {
      "email": "correo@dominio.com",
      "code": "123456"
    }
    """
    email = payload.email.lower().strip()
    code = (payload.code or "").strip()

    if len(code) != 6 or (not code.isdigit()):
        raise HTTPException(status_code=400, detail="Código inválido")

    user = db.query(models.User).filter(models.User.email == email).first()
    if not user:
        raise HTTPException(status_code=400, detail="Código inválido")

    if user.email_verified:
        return {"ok": True, "message": "Este correo ya está verificado."}

    # ✅ FIX: comparar tiempos de forma segura (aware vs naive)
    now = _to_utc_aware(utcnow())
    exp = _to_utc_aware(user.email_verification_expires_at) if user.email_verification_expires_at else None

    if (not exp) or (exp < now):
        raise HTTPException(status_code=400, detail="Código expirado. Solicita reenvío.")

    # comparar hash
    if user.email_verification_token_hash != hash_token(code):
        raise HTTPException(status_code=400, detail="Código incorrecto")

    user.email_verified = True
    user.email_verification_token_hash = None
    user.email_verification_expires_at = None
    db.commit()

    return {"ok": True, "message": "Correo verificado. Ya puedes iniciar sesión."}


@router.post("/resend-verification", response_model=schemas.VerifyEmailOut)
def resend_verification(payload: schemas.ResendVerificationIn, db: Session = Depends(get_db)):
    email = payload.email.lower().strip()
    print("[RESEND] request for:", email)

    user = db.query(models.User).filter(models.User.email == email).first()

    # Respuesta “ciega” (no filtra si existe o no)
    if not user:
        print("[RESEND] user not found (blind reply)")
        return {"ok": True, "message": "Si el correo existe, te enviamos un código."}

    print("[RESEND] user found, verified =", user.email_verified)

    if user.email_verified:
        print("[RESEND] already verified (no email sent)")
        return {"ok": True, "message": "Este correo ya está verificado."}

    code = _generate_6digit_code()
    user.email_verification_token_hash = hash_token(code)
    user.email_verification_expires_at = utcnow() + timedelta(minutes=VERIFY_CODE_TTL_MIN)
    db.commit()

    print("[RESEND] sending code to:", user.email)
    send_email(
        to_email=user.email,
        subject="Reenvío de código - Celestya",
        html=_verification_code_email_html(code),
    )

    return {"ok": True, "message": "Si el correo existe, te enviamos un código."}


@router.post("/login", response_model=schemas.Token)
def login(username: str = Form(...), password: str = Form(...), db: Session = Depends(get_db)):
    email = username.lower().strip()

    user = db.query(models.User).filter(models.User.email == email).first()
    if (not user) or (not verify_password(password, user.password_hash)):
        raise HTTPException(status_code=400, detail="Credenciales inválidas")

    if not user.email_verified:
        raise HTTPException(status_code=403, detail="Verifica tu correo antes de entrar")

    return {"access_token": create_access_token(user.id)}
