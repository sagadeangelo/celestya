import os
import smtplib
from email.mime.text import MIMEText

SMTP_HOST = os.getenv("SMTP_HOST", "")
SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
SMTP_USER = os.getenv("SMTP_USER", "")
SMTP_PASS = os.getenv("SMTP_PASS", "")
SMTP_USE_TLS = os.getenv("SMTP_USE_TLS", "true").lower() == "true"
MAIL_FROM = os.getenv("MAIL_FROM", SMTP_USER or "no-reply@localhost")


def send_email(to_email: str, subject: str, html: str):
    if not SMTP_HOST:
        # Para desarrollo: si no hay SMTP configurado, no truena.
        # Solo imprime el link en consola.
        print("⚠️ SMTP no configurado. No se envió correo.")
        print("To:", to_email)
        print("Subject:", subject)
        print("HTML:", html)
        return

    msg = MIMEText(html, "html", "utf-8")
    msg["Subject"] = subject
    msg["From"] = MAIL_FROM
    msg["To"] = to_email

    with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as server:
        if SMTP_USE_TLS:
            server.starttls()
        if SMTP_USER:
            server.login(SMTP_USER, SMTP_PASS)
        server.sendmail(MAIL_FROM, [to_email], msg.as_string())


def verification_email_html(verify_url: str) -> str:
    return f"""
    <div style="font-family:Arial,sans-serif;line-height:1.4">
      <h2>Verifica tu correo en Celestya</h2>
      <p>Da clic en el botón para verificar tu correo:</p>
      <p>
        <a href="{verify_url}" style="background:#3D8CD1;color:white;padding:10px 16px;text-decoration:none;border-radius:8px">
          Verificar correo
        </a>
      </p>
      <p>Si no fuiste tú, ignora este correo.</p>
    </div>
    """
