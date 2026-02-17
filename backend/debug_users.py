from app.database import SessionLocal
from app import models
import sys

def debug_users():
    db = SessionLocal()
    try:
        users = db.query(models.User).all()
        print(f"Total users in DB: {len(users)}")
        print("-" * 60)
        print(f"{'ID':<4} | {'Name':<15} | {'Gender':<10} | {'ShowMe':<10} | {'Email':<25} | {'Photo?':<5}")
        print("-" * 60)
        for u in users:
            has_photo = bool(u.profile_photo_key or u.photo_path)
            print(f"{u.id:<4} | {str(u.name)[:15]:<15} | {str(u.gender):<10} | {str(u.show_me):<10} | {str(u.email)[:25]:<25} | {has_photo}")
    except Exception as e:
        print(f"Error: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    debug_users()
