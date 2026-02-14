import sys
import os

# Ensure we can import from app
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.database import SessionLocal
from app.models import User
from app.utils import clean_name

def clean_database_names():
    db = SessionLocal()
    try:
        users = db.query(User).all()
        print(f"Checking {len(users)} users for name cleanup...")
        
        updated_count = 0
        for user in users:
            original_name = user.name
            cleaned = clean_name(original_name)
            
            if original_name != cleaned:
                print(f"Cleaning user {user.id}: '{original_name}' -> '{cleaned}'")
                user.name = cleaned
                updated_count += 1
        
        if updated_count > 0:
            db.commit()
            print(f"Successfully updated {updated_count} users.")
        else:
            print("No users needed cleanup.")
            
    except Exception as e:
        print(f"Error cleaning database: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    clean_database_names()
