import os
import json
import urllib.request
import urllib.error
from email.mime.text import MIMEText
import smtplib

# ============ RESEND ============
RESEND_API_KEY = os.getenv("RESEND_API_KEY", "").strip()
RESEND_FROM = os.getenv("RESEND_FROM", "").strip()  # "Nombre <correo@dominio>"
RESEND_ENDPOINT = "https://api.resend.com/emails"

# ============ SMTP (fallback opcional) ============
SMTP_HOST = os.getenv("SMTP_HOST", "").strip()
SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
SMTP_USER = os.getenv("SMTP_USER", "").strip()
SMTP_PASS = os.getenv("SMTP_PASS", "").strip()
SMTP_USE_TLS = os.getenv("SMTP_USE_TLS", "true").lower() == "true"
MAIL_FROM = os.getenv("MAIL_FROM", "").strip() or SMTP_USER or "no-reply@localhost"


def _send_email_resend(to_email: str, subject: str, html: str):
    if not RESEND_API_KEY:
        raise RuntimeError("RESEND_API_KEY no está configurado")

    if not RESEND_FROM:
        raise RuntimeError("RESEND_FROM no está configurado (ej: Celestya <celestya@tu-dominio.com>)")

    payload = {
        "from": RESEND_FROM,
        "to": [to_email],
        "subject": subject,
        "html": html,
    }

    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        RESEND_ENDPOINT,
        data=data,
        method="POST",
        headers={
            "Authorization": f"Bearer {RESEND_API_KEY}",
            "Content-Type": "application/json",
        },
    )

    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            body = resp.read().decode("utf-8", errors="ignore")
            # útil para debug
            print("[RESEND] status:", resp.status, "resp:", body[:300])
            return body
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="ignore")
        raise RuntimeError(f"Resend HTTPError {e.code}: {body}") from e


def _send_email_smtp(to_email: str, subject: str, html: str):
    if not SMTP_HOST:
        raise RuntimeError("SMTP_HOST no está configurado")

    msg = MIMEText(html, "html", "utf-8")
    msg["Subject"] = subject
    msg["From"] = MAIL_FROM
    msg["To"] = to_email

    with smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=20) as server:
        if SMTP_USE_TLS:
            server.starttls()
        if SMTP_USER:
            server.login(SMTP_USER, SMTP_PASS)
        server.sendmail(MAIL_FROM, [to_email], msg.as_string())


def send_email(to_email: str, subject: str, html: str):
    """
    Prioridad:
    1) Resend si hay RESEND_API_KEY
    2) SMTP si hay SMTP_HOST
    3) Dev: imprimir y no truena
    """
    # 1) Resend
    if RESEND_API_KEY:
        return _send_email_resend(to_email, subject, html)

    # 2) SMTP fallback
    if SMTP_HOST:
        return _send_email_smtp(to_email, subject, html)

    # 3) Dev mode
    print("⚠️ Email no enviado (no hay RESEND_API_KEY ni SMTP_HOST).")
    print("To:", to_email)
    print("Subject:", subject)
    print("HTML:", html[:500])
    return None
