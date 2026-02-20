import sqlite3
import os
import datetime

# Piedras Negras
LAT = 28.7136
LON = -100.5205

def fix_latest_user():
    print("[-] Fixing Latest User...")
    db_path = "/data/celestya.db"
    if not os.path.exists(db_path):
        print(f"DB not found at {db_path}")
        return

    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()

    try:
        # Get latest user
        user = cursor.execute("SELECT * FROM users ORDER BY id DESC LIMIT 1").fetchone()
        if not user:
            print("No users found!")
            return

        print(f"Found User: ID={user['id']} Name={user['name']} Email={user['email']}")
        print(f"Current Loc: {user['lat']}, {user['lon']}")
        print(f"Current ShowMe: {user['show_me']}")
        print(f"Current Gender: {user['gender']}")

        # Update
        cursor.execute("UPDATE users SET lat=?, lon=? WHERE id=?", (LAT, LON, user['id']))
        print(f"Updated Location to Piedras Negras ({LAT}, {LON})")
        
        # Ensure show_me/gender are set if missing (defaults to straight match?)
        # Only if null
        if not user['gender']:
             cursor.execute("UPDATE users SET gender='male' WHERE id=?", (user['id'],))
             print("Set default gender='male'")
        
        if not user['show_me']:
             cursor.execute("UPDATE users SET show_me='female' WHERE id=?", (user['id'],))
             print("Set default show_me='female'")

        conn.commit()
        print("[+] User Fixed successfully.")

    except Exception as e:
        print(f"[-] Error: {e}")
    finally:
        conn.close()

if __name__ == "__main__":
    fix_latest_user()
