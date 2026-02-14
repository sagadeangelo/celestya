import os
import secrets
import uuid
from datetime import date as d, timedelta, datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Form, BackgroundTasks
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

PUBLIC_BASE_URL = os.getenv("PUBLIC_BASE_URL", "https://celestya-backend.fly.dev")

# Ajustables por env
VERIFY_CODE_TTL_MIN = int(os.getenv("VERIFY_CODE_TTL_MIN", "15"))  # 15 min
VERIFY_CODE_SUBJECT = os.getenv("VERIFY_CODE_SUBJECT", "Tu código de verificación - Celestya")

# Permite desactivar email en test/alpha si Resend está bloqueando
EMAIL_ENABLED = os.getenv("EMAIL_ENABLED", "true").strip().lower() in ("1", "true", "yes", "y", "on")


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


def _generate_link_token() -> str:
    return str(uuid.uuid4())


def _verification_email_html(code: str, link_token: str) -> str:
    verify_link = f"{PUBLIC_BASE_URL}/auth/verify-link?token={link_token}"
    return f"""
    <div style="font-family: Arial, sans-serif; line-height: 1.6; max-width: 600px; margin: 0 auto;">
      <h2 style="color: #9B5CFF;">¡Bienvenido a Celestya! ✨</h2>
      <p>Gracias por registrarte. Para completar tu cuenta, verifica tu correo electrónico.</p>

      <div style="background: #f5f5f5; padding: 20px; border-radius: 8px; margin: 20px 0;">
        <p style="margin: 0 0 10px 0; font-weight: bold;">Opción 1: Haz clic en el botón</p>
        <a href="{verify_link}"
           style="display: inline-block; background: #9B5CFF; color: white; padding: 12px 30px;
                  text-decoration: none; border-radius: 6px; font-weight: bold;">
          Verificar mi cuenta
        </a>
      </div>

      <div style="background: #f5f5f5; padding: 20px; border-radius: 8px; margin: 20px 0;">
        <p style="margin: 0 0 10px 0; font-weight: bold;">Opción 2: Ingresa este código en la app</p>
        <div style="font-size: 32px; font-weight: 700; letter-spacing: 6px; color: #9B5CFF; text-align: center;">
          {code}
        </div>
      </div>

      <p style="font-size: 14px; color: #666;">
        Este enlace y código expiran en <b>{VERIFY_CODE_TTL_MIN} minutos</b>.
      </p>
      <p style="font-size: 14px; color: #666;">
        Si no solicitaste esta cuenta, ignora este correo.
      </p>
      <hr style="border: none; border-top: 1px solid #ddd; margin: 30px 0;"/>
      <p style="color:#999; font-size:12px; text-align: center;">Celestya - Tu media naranja te espera</p>
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


def _safe_send_verification_email(to_email: str, code: str, link_token: str, subject: str) -> bool:
    """
    Envía el correo de verificación SIN romper el flujo si falla.
    Retorna True si se intentó y salió bien, False si falló o está deshabilitado.
    """
    print(f"[DEBUG AUTH] _safe_send_verification_email triggered for {to_email}")
    try:
        res = send_email(
            to_email=to_email,
            subject=subject,
            html=_verification_email_html(code, link_token),
        )
        print(f"[DEBUG AUTH] send_email result: {res}")
        return True
    except Exception as e:
        # IMPORTANT: Nunca tirar error aquí, solo log.
        print(f"[WARN] Verification email failed for {to_email}: {e}")
        return False


@router.post("/register", response_model=schemas.RegisterResponse)
def register(
    payload: schemas.UserCreate,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
):
    """
    IMPORTANTE:
    - Permite re-registro si el email existe pero NO está verificado.
    - Los correos se envían en segundo plano (BackgroundTasks).
    - Usa respuestas "ciegas" para seguridad (User Enumeration).
    """
    email = payload.email.lower().strip()
    
    # 1. Verificar si el usuario ya existe
    existing_user = db.query(models.User).filter(models.User.email == email).first()
    
    if existing_user:
        # Si ya está verificado, responder con éxito pero no hacer nada (Blind Response)
        if existing_user.email_verified:
            print(f"[AUTH] Intento de registro con email ya verificado: {email}")
            return {"status": "pending_verification", "email": email}
        
        # Si NO está verificado, actualizar datos (Smart Re-registration)
        user = existing_user
        print(f"[AUTH] Re-registro inteligente para: {email}")
    else:
        # Nuevo registro
        user = models.User(email=email, email_verified=False)
        db.add(user)

    # 2. Validaciones comunes
    age = _calc_age(payload.birthdate)
    if age < 18:
        raise HTTPException(status_code=400, detail="Debes tener 18 años o más")

    try:
        pw_hash = hash_password(payload.password)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    # 3. Actualizar/Setear campos de perfil y auth
    user.password_hash = pw_hash
    user.name = payload.name
    user.birthdate = payload.birthdate
    user.age_bucket = _bucket(age)
    user.city = payload.city
    user.stake = payload.stake
    user.lat = payload.lat
    user.lon = payload.lon
    user.bio = payload.bio
    user.wants_adjacent_bucket = payload.wants_adjacent_bucket
    
    # Campos adicionales del perfil
    user.marital_status = payload.marital_status
    user.has_children = payload.has_children
    user.body_type = payload.body_type

    # 4. Regenerar tokens de verificación
    code = _generate_6digit_code()
    link_token = _generate_link_token()

    user.email_verification_token_hash = hash_token(code)
    user.email_verification_expires_at = utcnow() + timedelta(minutes=VERIFY_CODE_TTL_MIN)

    user.email_verification_link_token = link_token
    user.email_verification_link_expires_at = utcnow() + timedelta(minutes=VERIFY_CODE_TTL_MIN)
    user.email_verification_link_used = False

    db.commit()
    db.refresh(user)

    # 5. Enviar email en background
    background_tasks.add_task(
        _safe_send_verification_email,
        user.email,
        code,
        link_token,
        VERIFY_CODE_SUBJECT,
    )

    return {"status": "pending_verification", "email": user.email}


@router.get("/verify-link")
def verify_link(token: str, db: Session = Depends(get_db)):
    """
    Verifica cuenta mediante link UUID.
    Si es móvil, redirige a celestya://verified?email=...
    Si no, muestra HTML de éxito.
    """
    from fastapi.responses import HTMLResponse

    user = db.query(models.User).filter(
        models.User.email_verification_link_token == token
    ).first()

    if not user:
        return HTMLResponse(content="""
            <html><body style="font-family: Arial; text-align: center; padding: 50px;">
                <h2 style="color: #ff4444;">❌ Enlace inválido</h2>
                <p>Este enlace no es válido o ya fue usado.</p>
            </body></html>
        """, status_code=400)

    if user.email_verified:
        return HTMLResponse(content=f"""
            <html><body style="font-family: Arial; text-align: center; padding: 50px;">
                <h2 style="color: #9B5CFF;">✅ Ya verificado</h2>
                <p>Tu cuenta ya está verificada. Abre la app Celestya para continuar.</p>
            </body></html>
        """)

    if user.email_verification_link_used:
        return HTMLResponse(content="""
            <html><body style="font-family: Arial; text-align: center; padding: 50px;">
                <h2 style="color: #ff4444;">❌ Enlace ya usado</h2>
                <p>Este enlace ya fue utilizado.</p>
            </body></html>
        """, status_code=400)

    # Check expiration
    now = _to_utc_aware(utcnow())
    exp = _to_utc_aware(user.email_verification_link_expires_at) if user.email_verification_link_expires_at else None

    if (not exp) or (exp < now):
        return HTMLResponse(content="""
            <html><body style="font-family: Arial; text-align: center; padding: 50px;">
                <h2 style="color: #ff4444;">❌ Enlace expirado</h2>
                <p>Este enlace ha expirado. Solicita un nuevo código desde la app.</p>
            </body></html>
        """, status_code=400)

    # Mark as verified
    user.email_verified = True
    user.email_verification_link_used = True
    user.email_verification_token_hash = None
    user.email_verification_expires_at = None
    db.commit()

    # Success HTML - works without JavaScript
    success_html = f"""
        <!DOCTYPE html>
        <html lang="es">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>Cuenta Verificada - Celestya</title>
            <style>
                body {{
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif;
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    min-height: 100vh;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    margin: 0;
                    padding: 20px;
                }}
                .container {{
                    background: white;
                    border-radius: 16px;
                    padding: 40px;
                    max-width: 500px;
                    text-align: center;
                    box-shadow: 0 20px 60px rgba(0,0,0,0.3);
                }}
                .icon {{
                    font-size: 64px;
                    margin-bottom: 20px;
                }}
                h1 {{
                    color: #9B5CFF;
                    margin: 0 0 10px 0;
                    font-size: 28px;
                }}
                p {{
                    color: #666;
                    line-height: 1.6;
                    margin: 10px 0;
                }}
                .email {{
                    color: #9B5CFF;
                    font-weight: 600;
                }}
                .btn {{
                    display: inline-block;
                    background: #9B5CFF;
                    color: white;
                    padding: 14px 32px;
                    border-radius: 8px;
                    text-decoration: none;
                    font-weight: 600;
                    margin: 20px 0 10px 0;
                    transition: background 0.3s;
                }}
                .btn:hover {{
                    background: #8a4eef;
                }}
                .footer {{
                    margin-top: 30px;
                    font-size: 14px;
                    color: #999;
                }}
            </style>
            <script>
                try {{
                    window.location.href = 'celestya://verified?token={token}&email={user.email}';
                }} catch(e) {{}}
            </script>
        </head>
        <body>
            <div class="container">
                <div class="icon">✅</div>
                <h1>¡Cuenta Verificada!</h1>
                <p>Tu cuenta <span class="email">{user.email}</span> ha sido verificada exitosamente.</p>
                <p><strong>Regresa a la app Celestya e inicia sesión.</strong></p>

                <a href="celestya://verified?token={token}&email={user.email}" class="btn">
                    Abrir Celestya
                </a>
                <p style="font-size: 14px; color: #999; margin-top: 15px;">
                    Si el botón no funciona, abre la app manualmente desde tu teléfono.
                </p>

                <div class="footer">
                    Celestya - Tu media naranja te espera ✨
                </div>
            </div>
        </body>
        </html>
    """

    return HTMLResponse(content=success_html)


@router.get("/verify-status")
def verify_status(email: str, db: Session = Depends(get_db)):
    """
    Endpoint de debug para consultar si un correo ya está verificado.
    """
    user = db.query(models.User).filter(models.User.email == email.lower().strip()).first()
    if not user:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")

    return {
        "email": user.email,
        "email_verified": user.email_verified,
        "has_pending_link": user.email_verification_link_token is not None and not user.email_verification_link_used
    }


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

    now = _to_utc_aware(utcnow())
    exp = _to_utc_aware(user.email_verification_expires_at) if user.email_verification_expires_at else None

    if (not exp) or (exp < now):
        raise HTTPException(status_code=400, detail="Código expirado. Solicita reenvío.")

    if user.email_verification_token_hash != hash_token(code):
        raise HTTPException(status_code=400, detail="Código incorrecto")

    user.email_verified = True
    user.email_verification_token_hash = None
    user.email_verification_expires_at = None
    db.commit()

    return {
        "ok": True,
        "message": "Correo verificado exitosamente.",
        "access_token": create_access_token(user.id)
    }


@router.post("/resend-verification", response_model=schemas.VerifyEmailOut)
def resend_verification(
    payload: schemas.ResendVerificationIn, 
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db)
):
    """
    Reenvía el correo de verificación.
    - Usa BackgroundTasks para evitar timeouts.
    - Usa respuestas "ciegas" para seguridad.
    """
    email = payload.email.lower().strip()

    user = db.query(models.User).filter(models.User.email == email).first()

    # Respuesta “ciega” (no filtra si existe o no)
    if not user:
        return {"ok": True, "message": "Si el correo existe, te enviamos un código."}

    if user.email_verified:
        return {"ok": True, "message": "Este correo ya está verificado."}

    code = _generate_6digit_code()
    link_token = _generate_link_token()

    user.email_verification_token_hash = hash_token(code)
    user.email_verification_expires_at = utcnow() + timedelta(minutes=VERIFY_CODE_TTL_MIN)

    user.email_verification_link_token = link_token
    user.email_verification_link_expires_at = utcnow() + timedelta(minutes=VERIFY_CODE_TTL_MIN)
    user.email_verification_link_used = False

    db.commit()

    # Reenviar en background para evitar timeouts
    background_tasks.add_task(
        _safe_send_verification_email,
        user.email,
        code,
        link_token,
        "Verificación de cuenta - Celestya",
    )

    return {"ok": True, "message": "Si el correo existe, te enviamos los datos de verificación."}


@router.post("/consume-verify-link")
def consume_verify_link(payload: dict, db: Session = Depends(get_db)):
    """
    Consume el token del enlace para verificar y loguear al usuario automáticamente.
    JSON: { "token": "uuid..." }
    Retorna: { "ok": true, "access_token": "...", "email": "..." }
    """
    token = payload.get("token")
    if not token:
        raise HTTPException(status_code=400, detail="Token requerido")

    user = db.query(models.User).filter(
        models.User.email_verification_link_token == token
    ).first()

    if not user:
        raise HTTPException(status_code=400, detail="Token inválido")

    if user.email_verification_link_used:
        raise HTTPException(status_code=400, detail="El enlace ya fue usado")

    # Check expiration
    now = _to_utc_aware(utcnow())
    exp = _to_utc_aware(user.email_verification_link_expires_at) if user.email_verification_link_expires_at else None

    if (not exp) or (exp < now):
        raise HTTPException(status_code=400, detail="El enlace ha expirado")

    # Success: Mark verified & used
    user.email_verified = True
    user.email_verification_link_used = True
    user.email_verification_token_hash = None
    user.email_verification_expires_at = None
    # No borramos el link_token aún para que el GET verify-link siga sirviendo el HTML de éxito si se llama después,
    # aunque con el flag 'used' ya no servirá para login.
    # Opcional: Podríamos limpiarlo si quisiéramos strict one-time.
    
    db.commit()

    return {
        "ok": True,
        "access_token": create_access_token(user.id),
        "email": user.email
    }


@router.post("/login", response_model=schemas.Token)
def login(username: str = Form(...), password: str = Form(...), db: Session = Depends(get_db)):
    email = username.lower().strip()

    user = db.query(models.User).filter(models.User.email == email).first()
    if (not user) or (not verify_password(password, user.password_hash)):
        raise HTTPException(status_code=400, detail="Credenciales inválidas")

    if not user.email_verified:
        raise HTTPException(status_code=403, detail="Verifica tu correo antes de entrar")

    return {"access_token": create_access_token(user.id)}
