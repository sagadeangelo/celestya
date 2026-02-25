import os
import secrets
import uuid
from datetime import date as d, timedelta, datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Form, BackgroundTasks, Request
from fastapi.responses import HTMLResponse
from sqlalchemy.orm import Session

from ..database import get_db
from ..deps import get_current_user
from .. import models, schemas
from ..limiter import limiter, LIMIT_AUTH
from ..security import (
    hash_password,
    verify_password,
    create_access_token,
    create_refresh_token,
    hash_token,
    decode_token,
    make_token,
    ACCESS_TOKEN_TTL_MINUTES,
    REFRESH_TOKEN_TTL_DAYS,
    utcnow,
)
from ..enums import AgeBucket
from app.emailer import send_email, send_reset_password_email  # backend/app/emailer.py
import structlog

logger = structlog.get_logger("api")

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


def _prune_refresh_tokens(db: Session, user_id: int):
    """
    ✅ Prompt 6: Seguridad mínima
    - Limita refresh tokens activos por user a 10 (por created_at desc).
    - Borra tokens expirados y revocados antiguos (> 30 días).
    """
    try:
        now = utcnow()
        # 1. Borrar tokens expirados o revocados hace más de 30 días
        thirty_days_ago = now - timedelta(days=30)
        db.query(models.RefreshToken).filter(
            models.RefreshToken.user_id == user_id,
            (
                (models.RefreshToken.expires_at < thirty_days_ago) |
                (models.RefreshToken.revoked_at < thirty_days_ago)
            )
        ).delete(synchronize_session=False)

        # 2. Limitar a los 10 más recientes activos
        active_tokens = (
            db.query(models.RefreshToken.id)
            .filter(
                models.RefreshToken.user_id == user_id,
                models.RefreshToken.revoked_at == None,
                models.RefreshToken.expires_at > now
            )
            .order_by(models.RefreshToken.created_at.desc())
            .all()
        )

        if len(active_tokens) > 10:
            ids_to_keep = [t.id for t in active_tokens[:10]]
            db.query(models.RefreshToken).filter(
                models.RefreshToken.user_id == user_id,
                models.RefreshToken.revoked_at == None,
                models.RefreshToken.expires_at > now,
                ~models.RefreshToken.id.in_(ids_to_keep)
            ).update({models.RefreshToken.revoked_at: now}, synchronize_session=False)
        
        db.commit()
    except Exception as e:
        logger.error("auth_prune_error", error=str(e), user_id=user_id)
        db.rollback()


def _safe_send_verification_email(to_email: str, code: str, link_token: str, subject: str) -> bool:
    """
    Envía el correo de verificación SIN romper el flujo si falla.
    Retorna True si se intentó y salió bien, False si falló o está deshabilitado.
    """
    logger.info("auth_verification_trigger", email=to_email)
    try:
        res = send_email(
            to_email=to_email,
            subject=subject,
            html=_verification_email_html(code, link_token),
        )
        logger.info("auth_verification_sent", result=str(res))
        return True
    except Exception as e:
        # IMPORTANT: Nunca tirar error aquí, solo log.
        logger.warning("auth_verification_failed", email=to_email, error=str(e))
        return False


@router.post("/register", response_model=schemas.RegisterResponse)
@limiter.limit(LIMIT_AUTH)
def register(
    request: Request,
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
        # Si ya está verificado, arrojar error 409 Conflict con mensaje claro
        if existing_user.email_verified:
            logger.info("auth_register_duplicate_verified", email=email)
            raise HTTPException(
                status_code=409, 
                detail="Este correo ya se ha registrado anteriormente."
            )
        
        # Si NO está verificado, actualizar datos (Smart Re-registration)
        user = existing_user
        logger.info("auth_reregister_smart", email=email)
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


@router.post("/verify-email", response_model=schemas.Token)
@limiter.limit(LIMIT_AUTH)
def verify_email(
    request: Request,
    payload: schemas.VerifyEmailIn,
    db: Session = Depends(get_db)
):
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
        # If already verified, just issue new tokens
        access_token = create_access_token(sub=user.id)
        refresh_token = create_refresh_token()
        
        db_refresh = models.RefreshToken(
            user_id=user.id,
            token_hash=hash_token(refresh_token),
            expires_at=utcnow() + timedelta(days=REFRESH_TOKEN_TTL_DAYS)
        )
        db.add(db_refresh)
        db.commit()

        return {
            "access_token": access_token, 
            "token_type": "bearer",
            "refresh_token": refresh_token
        }

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

    access_token = create_access_token(sub=user.id)
    refresh_token = create_refresh_token()
    
    # Track device/agent info
    user_agent = request.headers.get("User-Agent")
    
    # Save Refresh Token
    db_refresh = models.RefreshToken(
        user_id=user.id,
        token_hash=hash_token(refresh_token),
        expires_at=utcnow() + timedelta(days=REFRESH_TOKEN_TTL_DAYS),
        user_agent=user_agent,
        last_used_at=utcnow()
    )
    db.add(db_refresh)
    db.commit()

    return {
        "access_token": access_token, 
        "token_type": "bearer",
        "refresh_token": refresh_token,
        "expires_in": ACCESS_TOKEN_TTL_MINUTES * 60
    }


@router.post("/refresh", response_model=schemas.Token)
@limiter.limit(LIMIT_AUTH)
def refresh_token(
    request: Request,
    payload: schemas.RefreshTokenIn,
    db: Session = Depends(get_db)
):
    token_hash = hash_token(payload.refresh_token)
    db_refresh = (
        db.query(models.RefreshToken)
        .filter(models.RefreshToken.token_hash == token_hash)
        .first()
    )

    if not db_refresh:
        raise HTTPException(
            status_code=401, 
            detail={"detail": "invalid_refresh", "code": "INVALID_REFRESH"}
        )

    # 1. Validaciones de Revocación y Reuso (Prompt 3)
    if db_refresh.revoked_at:
        if db_refresh.replaced_by_token_hash:
             logger.warning("auth_refresh_reused_detected", 
                            token_prefix=payload.refresh_token[:8], 
                            user_id=db_refresh.user_id)
             raise HTTPException(
                status_code=401, 
                detail={"detail": "refresh_reused", "code": "REFRESH_REUSED"}
             )

        raise HTTPException(
            status_code=401, 
            detail={"detail": "refresh_revoked", "code": "REFRESH_REVOKED"}
        )
    
    # 2. Validación de Expiración
    now = utcnow()
    exp = _to_utc_aware(db_refresh.expires_at)
    if now > exp:
        raise HTTPException(
            status_code=401, 
            detail={"detail": "refresh_expired", "code": "REFRESH_EXPIRED"}
        )

    # 3. Rotación en Transacción (Prompt 3)
    try:
        # Re-fetch en transacción si fuera necesario, pero aquí usamos db_refresh directamente
        # Marcar viejo como revocado
        db_refresh.revoked_at = now
        db_refresh.last_used_at = now
        
        # Generar nuevo con reintento si hay colisión de hash (extremadamente raro)
        new_refresh_token = None
        new_hash = None
        for _ in range(3):
            try:
                new_refresh_token = create_refresh_token()
                new_hash = hash_token(new_refresh_token)
                
                new_db_refresh = models.RefreshToken(
                    user_id=db_refresh.user_id,
                    token_hash=new_hash,
                    expires_at=now + timedelta(days=REFRESH_TOKEN_TTL_DAYS),
                    device_id=payload.device_id or db_refresh.device_id,
                    user_agent=request.headers.get("User-Agent") or db_refresh.user_agent,
                    last_used_at=now,
                    created_at=now
                )
                db.add(new_db_refresh)
                db.flush() # Verificar uniqueness
                
                # Link rotation
                db_refresh.replaced_by_token_hash = new_hash
                break
            except Exception:
                db.rollback()
                continue
        else:
            raise HTTPException(status_code=500, detail="Could not generate unique token")

        new_access_token = create_access_token(sub=db_refresh.user_id)
        db.commit()

        # 4. Prune opcional (Background o inline)
        _prune_refresh_tokens(db, db_refresh.user_id)

    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        logger.error("auth_refresh_transaction_failed", error=str(e))
        raise HTTPException(status_code=500, detail="Transaction failed")

    return {
        "access_token": new_access_token,
        "refresh_token": new_refresh_token,
        "token_type": "bearer",
        "expires_in": ACCESS_TOKEN_TTL_MINUTES * 60
    }


@router.post("/logout")
@limiter.limit(LIMIT_AUTH)
def logout(
    request: Request,
    payload: schemas.RefreshTokenIn,
    db: Session = Depends(get_db)
):
    """
    ✅ Prompt 4: Logout / revoke (Idempotente)
    """
    token_hash = hash_token(payload.refresh_token)
    db_refresh = (
        db.query(models.RefreshToken)
        .filter(models.RefreshToken.token_hash == token_hash)
        .first()
    )
    
    if db_refresh:
        db_refresh.revoked_at = utcnow()
        db.commit()
        logger.info("auth_logout_revoked", user_id=db_refresh.user_id)
    
    return {"ok": True}


@router.post("/logout-all", status_code=204)
@limiter.limit(LIMIT_AUTH)
def logout_all(
    request: Request,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """
    Revoca TODOS los refresh tokens del usuario.
    """
    db.query(models.RefreshToken).filter(
        models.RefreshToken.user_id == current_user.id
    ).update({"revoked_at": utcnow()}, synchronize_session=False)
    
    db.commit()
    return None


@router.post("/resend-verification", response_model=schemas.VerifyEmailOut)
@limiter.limit(LIMIT_AUTH)
def resend_verification(
    request: Request,
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
    logger.info("auth_resend_verification_start", email=email)

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

    logger.info("auth_resend_verification_success", email=user.email)
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
@limiter.limit(LIMIT_AUTH)
async def login(
    request: Request,
    db: Session = Depends(get_db)
):
    """
    Soporta login vía JSON (BaseModel) o Form (OAuth2 legacy).
    Esto soluciona el error 422 si el cliente envía un formato inesperado.
    """
    username = None
    password = None
    device_id = None

    # 1. Intentar capturar JSON
    try:
        body = await request.json()
        logger.info("auth_login_json", keys=list(body.keys()) if body else None)
        username = body.get("username")
        password = body.get("password")
        device_id = body.get("device_id")
    except:
        # 2. Fallback a Form data
        try:
            form_data = await request.form()
            logger.info("auth_login_form", keys=list(form_data.keys()) if form_data else None)
            username = form_data.get("username")
            password = form_data.get("password")
            device_id = form_data.get("device_id")
        except:
            logger.warning("auth_login_no_body")
            pass

    if not username or not password:
        logger.warning("auth_login_missing_fields", has_username=bool(username))
        raise HTTPException(
            status_code=422, 
            detail="Se requiere username y password. Asegúrate de enviar un JSON válido."
        )

    email = username.lower().strip()
    user = db.query(models.User).filter(models.User.email == email).first()
    
    if (not user) or (not verify_password(password, user.password_hash)):
        raise HTTPException(status_code=400, detail="Credenciales inválidas")

    if not user.email_verified:
        raise HTTPException(status_code=403, detail="Verifica tu correo antes de entrar")

    access_token = create_access_token(user.id)
    refresh_token = create_refresh_token()
    
    # Track device/agent info
    device_id = device_id or request.headers.get("X-Device-Id")
    user_agent = request.headers.get("User-Agent")
    
    now = utcnow()

    # Save Refresh Token
    db_refresh = models.RefreshToken(
        user_id=user.id,
        token_hash=hash_token(refresh_token),
        created_at=now,
        expires_at=now + timedelta(days=REFRESH_TOKEN_TTL_DAYS),
        device_id=device_id,
        user_agent=user_agent,
        last_used_at=now
    )
    db.add(db_refresh)
    db.commit()

    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "expires_in": ACCESS_TOKEN_TTL_MINUTES * 60
    }


@router.post("/forgot-password")
@limiter.limit("3/hour")  # Strong rate limit
def forgot_password(
    request: Request,
    payload: schemas.ForgotPasswordIn,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db)
):
    """
    Solicita un enlace para restablecer la contraseña.
    Respuesta genérica 200 para evitar enumeración de usuarios.
    """
    email = payload.email.lower().strip()
    
    # Log intento (sin revelar si existe o no en la respuesta HTTP)
    logger.info("auth_forgot_password_request", email=email)

    user = db.query(models.User).filter(models.User.email == email).first()
    
    try:
        if user:
            # Generar token
            token = _generate_link_token() # Reutilizamos UUID generator
            token_hash = hash_token(token)
            
            # Guardar en DB
            user.password_reset_token_hash = token_hash
            # 30 minutos de validez
            user.password_reset_expires_at = utcnow() + timedelta(minutes=30)
            db.commit()
            
            # Log token prefix para debug (nunca completo)
            logger.info("auth_forgot_password_token_generated", email=email, token_prefix=token[:6])

            # Enviar email en background
            # Usamos la URL actual para asegurar que el link funcione (evita error 1033 si el default está mal)
            current_base_url = str(request.base_url)
            print(f"[AUTH] Sending reset email to {user.email} using host {current_base_url}")
            background_tasks.add_task(send_reset_password_email, user.email, token, current_base_url)
        else:
            print(f"[AUTH] Forgot password: Email {email} not found")
            raise HTTPException(
                status_code=404, 
                detail="Este correo no está registrado en Celestya."
            )

        return {"message": "Recibirás instrucciones para restablecer tu contraseña en tu correo."}
    except Exception as e:
        import traceback
        error_msg = traceback.format_exc()
        print(f"[AUTH-ERROR] Forgot Password Failed: {e}")
        print(error_msg)
        raise HTTPException(status_code=500, detail=f"Internal Error: {e}")


@router.post("/reset-password")
@limiter.limit(LIMIT_AUTH)
def reset_password(
    request: Request,
    payload: schemas.ResetPasswordIn,
    db: Session = Depends(get_db)
):
    """
    Restablece la contraseña usando el token recibido por email.
    """
    token = payload.token
    new_password = payload.new_password
    
    # Buscar usuario por este token (tenemos que hashear para comparar, 
    # pero como el hash es determinista si usamos hash_token, podemos buscar... 
    # ESPERA: hash_token usa sha256. 
    # No podemos buscar por hash directamente si no tenemos el salt o si el hash es simple.
    # hash_token implementation: return hashlib.sha256(token.encode()).hexdigest()
    # Entonces SÍ es determinista y podemos buscar por él.
    
    hashed_token = hash_token(token)
    
    user = db.query(models.User).filter(
        models.User.password_reset_token_hash == hashed_token
    ).first()
    
    if not user:
        # Para seguridad, podemos retornar error genérico o específico.
        # En reset password, si el token es inválido, es mejor decirlo para que el usuario pida otro.
        raise HTTPException(status_code=400, detail="Enlace inválido o expirado.")
        
    # Verificar expiración
    now = _to_utc_aware(utcnow())
    exp = _to_utc_aware(user.password_reset_expires_at) if user.password_reset_expires_at else None
    
    if (not exp) or (exp < now):
        raise HTTPException(status_code=400, detail="El enlace ha expirado. Solicita uno nuevo.")
        
    # Actualizar password
    try:
        user.password_hash = hash_password(new_password)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
        
    # Limpiar tokens
    user.password_reset_token_hash = None
    user.password_reset_expires_at = None
    
    # Opcional: Invalidar sesiones existentes (revocar refresh tokens)
    # db.query(models.RefreshToken).filter(models.RefreshToken.user_id == user.id).delete()
    
    db.commit()
    
    logger.info("auth_password_reset_success", user_id=user.id)
    
    return {"message": "Contraseña actualizada correctamente. Inicia sesión."}


@router.get("/reset-password-html", response_class=HTMLResponse)
def reset_password_html(token: str):
    """
    Landing page that automatically redirects to the app's custom scheme.
    This allows 'https' links in emails which are more reliable than custom schemes.
    """
    # Scheme for the Flutter app
    app_scheme_url = f"celestya://reset-password?token={token}"
    
    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>Restablecer Contraseña</title>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
            body {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; 
                    text-align: center; padding: 20px; background-color: #f0f2f5; color: #1c1e21; }}
            .container {{ max-width: 400px; margin: 40px auto; background: white; padding: 30px; 
                          border-radius: 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.1); }}
            h2 {{ color: #1c1e21; margin-bottom: 10px; }}
            p {{ color: #606770; margin-bottom: 30px; line-height: 1.5; }}
            .btn {{ display: inline-block; background-color: #9B5CFF; color: white; padding: 14px 28px; 
                    text-decoration: none; border-radius: 8px; font-weight: 600; font-size: 16px;
                    transition: background-color 0.2s; }}
            .btn:hover {{ background-color: #7B42D6; }}
            .footer {{ margin-top: 30px; font-size: 12px; color: #8d949e; }}
        </style>
    </head>
    <body>
        <div class="container">
            <h2>Abrir Celestya</h2>
            <p>Pulsa el botón para continuar con el restablecimiento de tu contraseña en la app.</p>
            
            <a href="{app_scheme_url}" class="btn">Abrir App</a>
            
            <div class="footer">
                <p>Si no sucede nada automáticamente, asegúrate de tener la app instalada.</p>
            </div>
        </div>
        <script>
            // Attempt to redirect automatically
            setTimeout(function() {{
                window.location.href = "{app_scheme_url}";
            }}, 100);
        </script>
    </body>
    </html>
    """
    return HTMLResponse(content=html_content)
