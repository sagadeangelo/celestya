
import sys
import os
import sqlite3
import math
from datetime import date

# CONFIG
# Adjust these matches logic in matches.py
REQUIRE_EMAIL_VERIFIED = True # Default logic
REQUIRE_PROFILE_PHOTO = True
ALLOW_NO_PHOTO = False

DB_PATH = "/data/celestya.db"
TARGET_EMAIL = "miguel.tovar.amaral84@gmail.com" # Adjust if needed

def get_age(birthdate_str):
    if not birthdate_str: return None
    try:
        bdate = date.fromisoformat(birthdate_str)
        today = date.today()
        return today.year - bdate.year - ((today.month, today.day) < (bdate.month, bdate.day))
    except:
        return None

def main():
    if not os.path.exists(DB_PATH):
        print(f"DB not found at {DB_PATH}")
        return

    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    c = conn.cursor()

    # 1. Get Current User (MIGUEL)
    print(f"--- Debugging Feed for {TARGET_EMAIL} ---")
    user = c.execute("SELECT * FROM users WHERE email=?", (TARGET_EMAIL,)).fetchone()
    if not user:
        print("User not found!")
        return

    print(f"User ID: {user['id']}")
    print(f"Gender: {user['gender']}")
    print(f"Show Me: {user['show_me']}")
    print(f"Lat/Lon: {user['lat']}, {user['lon']}")
    print(f"Email Verified: {user['email_verified']}")
    
    # 2. Count Total Users
    total = c.execute("SELECT count(*) FROM users WHERE id != ?", (user['id'],)).fetchone()[0]
    print(f"\nTotal other users in DB: {total}")

    # 3. Analyze Exclusions
    print("\n--- Analyzing Candidates ---")
    
    candidates = c.execute("SELECT * FROM users WHERE id != ?", (user['id'],)).fetchall()
    
    reasons = {}
    
    for cand in candidates:
        reason = "OK"
        
        # A. Email
        if REQUIRE_EMAIL_VERIFIED and not cand['email_verified']:
            reason = "Email Not Verified"
        
        # B. Photo
        elif REQUIRE_PROFILE_PHOTO and not ALLOW_NO_PHOTO and not (cand['profile_photo_key'] or cand['photo_path']):
            reason = "No Photo"
            
        # C. Gender (Strict matchmaking)
        elif user['show_me'] and cand['gender'] != user['show_me']:
            reason = f"Gender Mismatch (User wants {user['show_me']}, Cand is {cand['gender']})"
            
        # D. Reciprocity
        elif user['gender'] and cand['show_me'] != user['gender']:
            reason = f"Reciprocity Mismatch (Cand wants {cand['show_me']}, User is {user['gender']})"
        
        # E. Age (Check standard range 18-100 just to see)
        # (Not strictly filtering here unless we passed params, but let's check basic validity)
        
        # Summary
        if reason not in reasons: reasons[reason] = 0
        reasons[reason] += 1
        
        if reason == "OK":
            print(f"[MATCH] ID={cand['id']} Name={cand['name']} Gender={cand['gender']} Age={get_age(cand['birthdate'])}")

    print("\n--- Exclusion Summary ---")
    for r, count in reasons.items():
        print(f"{r}: {count}")

if __name__ == "__main__":
    main()
