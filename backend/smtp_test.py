import smtplib

SMTP_HOST = "smtp.zoho.com"
SMTP_PORT = 587
SMTP_USER = "celestya@lasagadeangelo.com.mx"
SMTP_PASS = "TU_APP_PASSWORD"

s = smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=20)
s.ehlo()
s.starttls()
s.ehlo()
s.login(SMTP_USER, SMTP_PASS)
print("LOGIN OK")
s.quit()
