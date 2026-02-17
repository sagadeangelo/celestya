import sqlite3
import os
import sys

# Default to /data/celestya.db if on Fly, else local
DB = os.getenv("DATABASE_URL", "/data/celestya.db").replace("sqlite:///", "")
if DB.startswith("sqlite:/"):
     DB = DB.replace("sqlite:/", "")

print(f"Connecting to DB: {DB}")

try:
    con = sqlite3.connect(DB)
    cur = con.cursor()
    
    print("\n--- SCHEMA: blocks ---")
    try:
        rows = cur.execute("PRAGMA table_info(blocks)").fetchall()
        if not rows:
            print("Table 'blocks' does not exist.")
        else:
            print(f"{'cid':<5} {'name':<20} {'type':<10} {'notnull':<5} {'dflt_value':<10} {'pk':<5}")
            print("-" * 60)
            for r in rows:
                print(f"{r[0]:<5} {r[1]:<20} {r[2]:<10} {r[3]:<5} {str(r[4]):<10} {r[5]:<5}")
    except Exception as e:
        print(f"Error reading schema: {e}")

    print("\n--- SCHEMA: likes (for comparison) ---")
    try:
        rows = cur.execute("PRAGMA table_info(likes)").fetchall()
        for r in rows:
             print(f"{r[0]:<5} {r[1]:<20} {r[2]:<10}")
    except:
        pass

    con.close()

except Exception as e:
    print(f"Connection failed: {e}")
