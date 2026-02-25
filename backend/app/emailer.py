import os
import json
import urllib.request
import urllib.error
import structlog

logger = structlog.get_logger("app.emailer")

class ResendError(Exception):
    def __init__(self, status_code: int, body: str):
        self.status_code = status_code
        self.body = body
        super().__init__(f"Resend Failure {status_code}: {body}")

# ============ CONFIGURATION ============
EMAIL_ENABLED_RAW = os.getenv("EMAIL_ENABLED", "true")
EMAIL_ENABLED = EMAIL_ENABLED_RAW.lower() not in ("false", "0", "no", "off")

# FORZAMOS from logic
ENV = os.getenv("ENV", "production").lower()
VERIFIED_DOMAIN = "lasagadeangelo.com.mx"
DEFAULT_FROM = f"Celestya <no-reply@{VERIFIED_DOMAIN}>"
MAIL_FROM = os.getenv("MAIL_FROM", "").strip() or DEFAULT_FROM

# Validación de seguridad: el dominio debe ser el verificado, pero permitimos onboarding de Resend
if VERIFIED_DOMAIN not in MAIL_FROM and "resend.dev" not in MAIL_FROM:
    logger.error("mail_from_invalid_domain", mail_from=MAIL_FROM, expected_domain=VERIFIED_DOMAIN)
    MAIL_FROM = DEFAULT_FROM

RESEND_API_KEY = os.getenv("RESEND_API_KEY", "").strip()
RESEND_ENDPOINT = "https://api.resend.com/emails"

logger.info("emailer_config", email_enabled=EMAIL_ENABLED, mail_from=MAIL_FROM, key_set=bool(RESEND_API_KEY))


def _send_email_resend(to_email: str, subject: str, html: str):
    if not RESEND_API_KEY:
        logger.error("resend_api_key_missing")
        raise RuntimeError("RESEND_API_KEY no está configurado")

    payload = {
        "from": MAIL_FROM,
        "to": [to_email],
        "subject": subject,
        "html": html,
    }

    logger.info("resend_request", provider="resend", from_email=MAIL_FROM, to_email=to_email, subject=subject)

    data = json.dumps(payload).encode("utf-8")

    headers = {
        "Authorization": f"Bearer {RESEND_API_KEY}",
        "Content-Type": "application/json",
        "Accept": "application/json",
        "User-Agent": "CelestyaBackend/1.0 (+https://lasagadeangelo.com.mx)",
    }

    req = urllib.request.Request(
        RESEND_ENDPOINT,
        data=data,
        method="POST",
        headers=headers,
    )

    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            status_code = resp.getcode()
            body = resp.read().decode("utf-8", errors="ignore")
            res_json = json.loads(body)
            msg_id = res_json.get("id")
            logger.info("resend_response_success", status=status_code, provider="resend", message_id=msg_id)
            return res_json

    except urllib.error.HTTPError as e:
        status_code = e.code
        body = e.read().decode("utf-8", errors="ignore")
        logger.error("resend_response_failure", status=status_code, body=body)
        raise ResendError(status_code, body) from e

    except Exception as e:
        logger.error("resend_unexpected_error", error=str(e))
        raise


def send_email(to_email: str, subject: str, html: str):
    """
    Sends email strictly via Resend. Legacy SMTP fallback removed to ensure 
    delivery consistency and explicit failure reporting.
    """
    if not EMAIL_ENABLED:
        logger.info("email_disabled_skipping", to=to_email)
        return {"sent": False, "skipped": True}

    if not RESEND_API_KEY:
        logger.error("resend_api_key_missing_cannot_send")
        return {"sent": False, "error": "No email provider configured"}

    res = _send_email_resend(to_email, subject, html)
    return {"sent": True, "provider": "resend", "id": res.get("id")}


def send_reset_password_email(to_email: str, token: str, api_base_url: str | None = None):
    """
    Envía correo con el enlace para restablecer contraseña.
    Usa Deep Link: celestya://reset-password?token=...
    """
    if not EMAIL_ENABLED:
        logger.info("email_disabled_skipping_reset", to=to_email)
        return {"sent": False, "skipped": True}

    # Configurar URL base del backend (Trampoline)
    # Si no se pasa, usar ENV o default
    if not api_base_url:
        api_base_url = os.getenv("API_BASE_URL", "https://api.lasagadeangelo.com.mx")
    
    api_base_url = api_base_url.strip().rstrip("/")
    
    # Link HTTPS que redirige al esquema
    reset_link = f"{api_base_url}/auth/reset-password-html?token={token}"
    
    subject = "Restablece tu contraseña - Celestya"
    
    html = f"""
    <div style="font-family: Arial, sans-serif; line-height: 1.6; max-width: 600px; margin: 0 auto;">
      <h2 style="color: #9B5CFF;">Recuperación de contraseña 🔐</h2>
      <p>Hemos recibido una solicitud para restablecer tu contraseña en Celestya.</p>

      <div style="background: #f5f5f5; padding: 20px; border-radius: 8px; margin: 20px 0; text-align: center;">
        <a href="{reset_link}"
           style="display: inline-block; background: #9B5CFF; color: white; padding: 12px 30px;
                  text-decoration: none; border-radius: 6px; font-weight: bold;">
          Restablecer Contraseña
        </a>
      </div>

      <p style="font-size: 14px; color: #666;">
        Si el botón no funciona, intenta abrir este enlace en tu móvil:<br>
        <a href="{reset_link}" style="color: #9B5CFF;">{reset_link}</a>
      </p>

      <p style="font-size: 14px; color: #666;">
        Este enlace es válido por 30 minutos.
      </p>
      <p style="font-size: 14px; color: #666;">
        Si no solicitaste este cambio, puedes ignorar este correo. Tu contraseña seguirá siendo la misma.
      </p>
      <hr style="border: none; border-top: 1px solid #ddd; margin: 30px 0;"/>
      <p style="color:#999; font-size:12px; text-align: center;">Celestya - Tu media naranja te espera</p>
    </div>
    """

    return send_email(to_email, subject, html)

