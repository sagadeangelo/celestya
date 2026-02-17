import os
import sys
from sqlalchemy import create_engine, text

# Exact copy of logic from database.py to ensure we see what the app sees
def _get_default_db_url():
    if os.path.exists("/data"):
        return "sqlite:////data/celestya.db"
    return "sqlite:///./celestya.db"

DATABASE_URL = os.getenv("DATABASE_URL", _get_default_db_url()).strip()

print(f"--- DIAGNOSTIC START ---")
print(f"Computed DATABASE_URL: {DATABASE_URL}")

try:
    if "sqlite" in DATABASE_URL:
        path = DATABASE_URL.replace("sqlite:///", "").replace("sqlite:", "").lstrip("/")
        if DATABASE_URL.startswith("sqlite:////"): 
            path = "/" + path
        
        if os.path.exists(path):
            size = os.path.getsize(path)
            print(f"DB File '{path}' FOUND. Size: {size} bytes")
        else:
            print(f"DB File '{path}' NOT FOUND.")
            # If default not found, try to look for any .db file in /data
            if os.path.exists("/data"):
                print("Listing /data:")
                for f in os.listdir("/data"):
                    print(f" - {f}")
except Exception as e:
    print(f"Error checking file sys: {e}")

try:
    engine = create_engine(DATABASE_URL)
    with engine.connect() as conn:
        print("Connected to DB successfully.")
        
        # 1. Count Users
        try:
            count = conn.execute(text("SELECT COUNT(*) FROM users")).scalar()
            print(f"Total Users in DB: {count}")
        except Exception as e:
            print(f"Error counting users: {e}")
            sys.exit(1)

        if count == 0:
            print("DB IS EMPTY. Seeding logic failed or writing to wrong file.")
        else:
            # 2. Check Female Testers
            try:
                females = conn.execute(text("SELECT COUNT(*) FROM users WHERE gender='female'")).scalar()
                print(f"Female Users: {females}")
            except Exception as e:
                 print(f"Error counting females: {e}")

            # 3. Sample Data
            print("\n--- SAMPLE USERS (First 5) ---")
            rows = conn.execute(text("SELECT id, email, gender, show_me, email_verified, profile_photo_key, birthdate FROM users LIMIT 5")).fetchall()
            for r in rows:
                print(r)

            # 4. Check for 'tester' specific users
            print("\n--- TESTER ACCOUNTS ---")
            testers = conn.execute(text("SELECT id, email, gender, show_me, email_verified FROM users WHERE email LIKE 'tester_%'")).fetchall()
            if not testers:
                print("No users with email 'tester_%' found.")
            else:
                for t in testers:
                    print(t)

except Exception as e:
    print(f"CRITICAL DB ERROR: {e}")

print(f"--- DIAGNOSTIC END ---")
