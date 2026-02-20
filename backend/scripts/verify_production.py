import requests
import sqlite3
import os
import sys

BASE_URL = "http://localhost:8000"

def check_alembic_status():
    print("[-] Checking Alembic Status in DB...")
    if os.path.exists("celestya.db"):
        conn = sqlite3.connect("celestya.db")
        cursor = conn.cursor()
        try:
            cursor.execute("SELECT version_num FROM alembic_version")
            row = cursor.fetchone()
            if row:
                print(f"[+] Alembic Version Found: {row[0]}")
            else:
                print("[-] alembic_version table exists but empty.")
        except sqlite3.OperationalError:
            print("[-] 'alembic_version' table NOT found. (If tables exist, you may need 'alembic stamp head')")
        finally:
            conn.close()
    else:
        print("[-] celestya.db not found.")

def test_rate_limit():
    print("\n[-] Testing Rate Limit (Redis/InMemory)...")
    # Hit /auth/login repeatedly
    url = f"{BASE_URL}/auth/login"
    payload = {"username": "spam_user", "password": "password"}
    
    print("    Sending 10 requests quickly...")
    blocked = False
    for i in range(10):
        try:
            r = requests.post(url, data=payload)
            if r.status_code == 429:
                print(f"[+] Hit Rate Limit at request #{i+1} (429 Too Many Requests)")
                blocked = True
                break
        except Exception as e:
            print(f"    Error: {e}")
    
    if not blocked:
        print("[-] Did NOT hit rate limit (Limit might be higher than 10/min? Checked code: 5/min)")

def check_refresh_tokens():
    print("\n[-] Checking Refresh Token Hashing...")
    if os.path.exists("celestya.db"):
        conn = sqlite3.connect("celestya.db")
        cursor = conn.cursor()
        try:
            cursor.execute("SELECT token_hash, created_at FROM refresh_tokens ORDER BY created_at DESC LIMIT 1")
            row = cursor.fetchone()
            if row:
                token_hash = row[0]
                print(f"[+] Found Refresh Token in DB.")
                if token_hash.startswith("$2") or len(token_hash) > 50: # bcrypt usually starts with $2
                     print(f"[+] Token appears hashed: {token_hash[:15]}...")
                else:
                     print(f"[-] Token might NOT be hashed: {token_hash}")
            else:
                print("[-] No refresh tokens found in DB to verify.")
        except Exception as e:
            print(f"[-] Error querying refresh_tokens: {e}")
        finally:
            conn.close()

def check_users():
    print("\n[-] Checking Users...")
    if os.path.exists("celestya.db"):
        conn = sqlite3.connect("celestya.db")
        cursor = conn.cursor()
        try:
            print("    Last 5 Users:")
            cursor.execute("SELECT id, name, email, age_bucket, city, lat, lon FROM users ORDER BY id DESC LIMIT 5")
            rows = cursor.fetchall()
            for r in rows:
                print(f"    {r}")
            
            print("    Total Users:")
            count = cursor.execute("SELECT count(*) FROM users").fetchone()[0]
            print(f"    {count}")
        except Exception as e:
             print(f"[-] Error querying users: {e}")
        finally:
             conn.close()

if __name__ == "__main__":
    check_users()
    # check_alembic_status()
    # test_rate_limit()
    # check_refresh_tokens()
