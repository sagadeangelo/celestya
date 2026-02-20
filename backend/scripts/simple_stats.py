import sqlite3
import os

DB_PATH = "/data/celestya.db"

def run():
    if not os.path.exists(DB_PATH):
        print("NO_DB")
        return

    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    try:
        total = cursor.execute("SELECT count(*) FROM users").fetchone()[0]
        females = cursor.execute("SELECT count(*) FROM users WHERE gender='female'").fetchone()[0]
        males = cursor.execute("SELECT count(*) FROM users WHERE gender='male'").fetchone()[0]
        
        males = cursor.execute("SELECT count(*) FROM users WHERE gender='male'").fetchone()[0]
        
        females_with_photo = cursor.execute("SELECT count(*) FROM users WHERE gender='female' AND (profile_photo_key IS NOT NULL OR photo_path IS NOT NULL)").fetchone()[0]
        
        print(f"FEMALES_SHOW_ME:")
        rows = cursor.execute("SELECT show_me, count(*) FROM users WHERE gender='female' GROUP BY show_me").fetchall()
        for r in rows:
            print(f"  {r[0]}: {r[1]}")

        # Latest User
        user = cursor.execute("SELECT id, gender, show_me, lat, lon FROM users WHERE email=?", ("miguel.tovar.amaral84@gmail.com",)).fetchone()

        print(f"TOTAL: {total}")
        print(f"FEMALES: {females}")
        print(f"MALES: {males}")
        print(f"FEM_PHOTO: {females_with_photo}")
        if user:
             print(f"ME_ID: {user[0]}")
             print(f"ME_GEN: {user[1]}")
             print(f"ME_SHOW: {user[2]}")
             print(f"ME_LOC: {user[3]},{user[4]}")
        
    except Exception as e:
        print(f"ERROR: {e}")
    finally:
        conn.close()

if __name__ == "__main__":
    run()
