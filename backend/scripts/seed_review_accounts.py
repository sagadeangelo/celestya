import os
import sys

# Adds the backend directory to sys.path so we can import app modules properly
backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, backend_dir)

from sqlalchemy.orm import Session
from app.database import SessionLocal
from app.models import User
from app.enums import AgeBucket
from app.security import hash_password
from app.review_access import REVIEWER_USER_EMAIL, REVIEWER_ADMIN_EMAIL
from datetime import date

REVIEWER_PASSWORD = "CelestyaReview#2026"

def seed_reviewer_accounts():
    db: Session = SessionLocal()
    try:
        password_hash = hash_password(REVIEWER_PASSWORD)

        for email, role in [(REVIEWER_USER_EMAIL, "user"), (REVIEWER_ADMIN_EMAIL, "admin")]:
            user = db.query(User).filter(User.email == email).first()

            if user:
                print(f"[*] Updating existing reviewer account: {email}")
                user.password_hash = password_hash
                user.email_verified = True # Just in case email validation is required
            else:
                print(f"[+] Creating new reviewer account: {email}")
                user = User(
                    email=email,
                    password_hash=password_hash,
                    name=f"Reviewer {role.capitalize()}",
                    birthdate=date(1990, 1, 1), # Dummy birthdate
                    age_bucket=AgeBucket.B_26_45,
                    gender="M", # Male in Celestya notation
                    email_verified=True, 
                )
                db.add(user)

        db.commit()
        print("[SUCCESS] Reviewer accounts seeded successfully. Safe for Google Play Login.")
    except Exception as e:
        print(f"[ERROR] Failed to seed reviewer accounts: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    seed_reviewer_accounts()
