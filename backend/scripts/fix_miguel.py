import sqlite3
import os

# Piedras Negras
LAT = 28.7136
LON = -100.5205
TARGET_EMAIL = "miguel.tovar.amaral84@gmail.com"

def fix_miguel():
    print(f"[-] Fixing User {TARGET_EMAIL}...")
    db_path = "/data/celestya.db"
    if not os.path.exists(db_path):
        print(f"DB not found at {db_path}")
        return

    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()

    try:
        # Get user
        user = cursor.execute("SELECT * FROM users WHERE email=?", (TARGET_EMAIL,)).fetchone()
        if not user:
            print("User MIGUEL not found!")
            # Try fuzzy search?
            user = cursor.execute("SELECT * FROM users WHERE email LIKE '%miguel%' LIMIT 1").fetchone()
            if not user:
                 print("No 'miguel' found via fuzzy search either.")
                 return

        print(f"Found User: ID={user['id']} Name={user['name']} Email={user['email']}")
        print(f"Current Loc: {user['lat']}, {user['lon']}")

        # Update
        cursor.execute("UPDATE users SET lat=?, lon=? WHERE id=?", (LAT, LON, user['id']))
        print(f"Updated Location to Piedras Negras ({LAT}, {LON})")
        
        # Ensure gender/show_me
        if not user['gender']:
             cursor.execute("UPDATE users SET gender='male' WHERE id=?", (user['id'],))
             print("Set gender='male'")
        
        if not user['show_me']:
             cursor.execute("UPDATE users SET show_me='female' WHERE id=?", (user['id'],))
             print("Set show_me='female'")

        conn.commit()
        print("[+] Miguel Fixed successfully.")

    except Exception as e:
        print(f"[-] Error: {e}")
    finally:
        conn.close()

if __name__ == "__main__":
    fix_miguel()
