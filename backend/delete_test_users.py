from app.database import SessionLocal
from app.models import User

def delete_unverified(email: str):
    db = SessionLocal()
    try:
        count = (
            db.query(User)
            .filter(User.email == email, User.email_verified == False)  # noqa: E712
            .delete(synchronize_session=False)
        )
        db.commit()
        print(f"Eliminados {count} usuarios NO verificados con email={email}")
    finally:
        db.close()

def delete_like(pattern: str):
    db = SessionLocal()
    try:
        count = (
            db.query(User)
            .filter(User.email.like(pattern))
            .delete(synchronize_session=False)
        )
        db.commit()
        print(f"Eliminados {count} usuarios con patrón {pattern}")
    finally:
        db.close()

if __name__ == "__main__":
    delete_unverified("miguel.tovar.amaral@gmail.com")
    delete_like("%+test%")
