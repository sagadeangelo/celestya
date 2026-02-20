import sqlite3
import os

DB_PATH = "/data/celestya.db"

def diagnose():
    print("[-] Diagnosing DB...")
    if not os.path.exists(DB_PATH):
        print(f"DB not found at {DB_PATH}")
        return

    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    try:
        # 1. Total User Count
        total = cursor.execute("SELECT count(*) FROM users").fetchone()[0]
        print(f"Total Users: {total}")

        # 2. Gender Breakdown
        print("\n--- Gender Breakdown ---")
        rows = cursor.execute("SELECT gender, count(*) FROM users GROUP BY gender").fetchall()
        for r in rows:
            print(f"{r[0]}: {r[1]}")

        # 3. Photo Status
        print("\n--- Photo Status ---")
        has_photo = cursor.execute("SELECT count(*) FROM users WHERE profile_photo_key IS NOT NULL OR photo_path IS NOT NULL").fetchone()[0]
        print(f"With Photo (key or path): {has_photo}")
        print(f"Without Photo: {total - has_photo}")

        # 4. Email Verified Status
        print("\n--- Email Verification ---")
        verified = cursor.execute("SELECT count(*) FROM users WHERE email_verified=1").fetchone()[0]
        print(f"Verified: {verified}")
        print(f"Unverified: {total - verified}")
        
        # 5. List Female Users (Sample)
        # print("\n--- Sample Females ---")
        # females = cursor.execute("SELECT id, name, email, profile_photo_key FROM users WHERE gender='female' LIMIT 5").fetchall()
        # for f in females:
        #    print(f)

    except Exception as e:
        print(f"[-] Error: {e}")
    finally:
        conn.close()

if __name__ == "__main__":
    diagnose()
