import os
import json
import urllib.request
import urllib.error
import logging

logger = logging.getLogger("app.emailer")

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

# Validación de seguridad: el dominio debe ser el verificado
if VERIFIED_DOMAIN not in MAIL_FROM:
    logger.error(f"MAIL_FROM '{MAIL_FROM}' no pertenece al dominio verificado {VERIFIED_DOMAIN}. Usando default.")
    print(f"[ERROR EMAILER] Dominio inválido en MAIL_FROM: {MAIL_FROM}. Usando default.")
    MAIL_FROM = DEFAULT_FROM

RESEND_API_KEY = os.getenv("RESEND_API_KEY", "").strip()
RESEND_ENDPOINT = "https://api.resend.com/emails"

logger.info(f"Email configuration: EMAIL_ENABLED={EMAIL_ENABLED}, MAIL_FROM='{MAIL_FROM}', KEY_SET={bool(RESEND_API_KEY)}")
print(f"[DEBUG EMAILER] Init: EMAIL_ENABLED={EMAIL_ENABLED}, MAIL_FROM='{MAIL_FROM}', KEY_SET={bool(RESEND_API_KEY)}")


def _send_email_resend(to_email: str, subject: str, html: str):
    if not RESEND_API_KEY:
        logger.error("RESEND_API_KEY no está configurado")
        raise RuntimeError("RESEND_API_KEY no está configurado")

    payload = {
        "from": MAIL_FROM,
        "to": [to_email],
        "subject": subject,
        "html": html,
    }

    logger.info(f"Resend Request: provider=resend, from='{MAIL_FROM}', to='{to_email}', subject='{subject}'")

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
            logger.info(f"Resend Response Success: status={status_code}, provider=resend, message_id={msg_id}")
            return res_json

    except urllib.error.HTTPError as e:
        status_code = e.code
        body = e.read().decode("utf-8", errors="ignore")
        logger.error(f"Resend Response Failure: status={status_code}, body={body}")
        raise ResendError(status_code, body) from e

    except Exception as e:
        logger.error(f"Unexpected error in _send_email_resend: {str(e)}")
        raise


def send_email(to_email: str, subject: str, html: str):
    """
    Sends email strictly via Resend. Legacy SMTP fallback removed to ensure 
    delivery consistency and explicit failure reporting.
    """
    print(f"[DEBUG EMAILER] Entering send_email to={to_email}, enabled={EMAIL_ENABLED}")
    if not EMAIL_ENABLED:
        logger.info(f"EMAIL_ENABLED=false; skip sending to={to_email}")
        print(f"[DEBUG EMAILER] Skipped because EMAIL_ENABLED=false")
        return {"sent": False, "skipped": True}

    if not RESEND_API_KEY:
        logger.error("No RESEND_API_KEY configured. Cannot send email.")
        print(f"[DEBUG EMAILER] Error: RESEND_API_KEY missing")
        return {"sent": False, "error": "No email provider configured"}

    print(f"[DEBUG EMAILER] Calling _send_email_resend...")
    res = _send_email_resend(to_email, subject, html)
    print(f"[DEBUG EMAILER] _send_email_resend success, id={res.get('id')}")
    return {"sent": True, "provider": "resend", "id": res.get("id")}

