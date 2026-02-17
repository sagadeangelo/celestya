import sqlite3
import os
import sys

# Default to /data/celestya.db if on Fly, else local
DB = os.getenv("DATABASE_URL", "/data/celestya.db").replace("sqlite:///", "")
if DB.startswith("sqlite:/"):
     DB = DB.replace("sqlite:/", "") # Handle variants

print(f"Connecting to DB: {DB} (DEBUG MATCH PAIR)")

try:
    con = sqlite3.connect(DB)
    con.row_factory = sqlite3.Row
except Exception as e:
    print(f"Could not connect to {DB}: {e}")
    sys.exit(1)

cur = con.cursor()

# Find MIGUEL (Current User)
miguel = None
rows = cur.execute("SELECT * FROM users WHERE name LIKE '%Miguel%'").fetchall()
if len(rows) == 0:
    print("User 'Miguel' not found. Please provide exact name or email.")
elif len(rows) > 1:
    print(f"Multiple users found with 'Miguel': {[r['name'] + ' (' + r['email'] + ')' for r in rows]}. Using first one.")
    miguel = rows[0]
else:
    miguel = rows[0]

# Find MARIA DOLORES (Target User)
maria = None
rows_m = cur.execute("SELECT * FROM users WHERE name LIKE '%Maria Dolores%'").fetchall()
if len(rows_m) == 0:
    print("User 'Maria Dolores' not found.")
elif len(rows_m) > 1:
    print(f"Multiple users found with 'Maria Dolores': {[r['name'] + ' (' + r['email'] + ')' for r in rows_m]}. Using first one.")
    maria = rows_m[0]
else:
    maria = rows_m[0]

if not miguel or not maria:
    print("Cannot proceed without both users.")
    sys.exit(1)

print(f"\n--- MIGUEL ({miguel['id']}) ---")
print(f"Gender: {miguel['gender']}, Show Me: {miguel['show_me']}")
print(f"Age Bucket: {miguel['age_bucket']}, Birth: {miguel['birthdate']}")
print(f"Location: {miguel['lat']}, {miguel['lon']}")
print(f"Verified: {miguel['email_verified']}, Photo: {miguel['profile_photo_key']}")

print(f"\n--- MARIA ({maria['id']}) ---")
print(f"Gender: {maria['gender']}, Show Me: {maria['show_me']}")
print(f"Age Bucket: {maria['age_bucket']}, Birth: {maria['birthdate']}")
print(f"Location: {maria['lat']}, {maria['lon']}")
print(f"Verified: {maria['email_verified']}, Photo: {maria['profile_photo_key']}")

# CHECK COMPATIBILITY
print(f"\n--- COMPATIBILITY CHECK ---")
is_gender_ok_1 = (miguel['show_me'] == maria['gender']) or (miguel['show_me'] == 'everyone')
is_gender_ok_2 = (maria['show_me'] == miguel['gender']) or (maria['show_me'] == 'everyone')
print(f"Miguel sees Maria (Gender)? {is_gender_ok_1}")
print(f"Maria sees Miguel (Gender)? {is_gender_ok_2}")

# CHECK EXISTING INTERACTION
print(f"\n--- INTERACTION CHECK ---")
# Did Miguel Like Maria?
like = cur.execute("SELECT * FROM likes WHERE liker_id=? AND liked_id=?", (miguel['id'], maria['id'])).fetchone()
if like:
    print(f"⚠️ MIGUEL ALREADY LIKED MARIA on {like['created_at']}")
else:
    print("Miguel has NOT liked Maria yet.")

# Did Miguel Pass Maria?
pass_ = cur.execute("SELECT * FROM passes WHERE passer_id=? AND passed_id=?", (miguel['id'], maria['id'])).fetchone()
if pass_:
    print(f"⚠️ MIGUEL ALREADY PASSED MARIA on {pass_['created_at']}")
else:
    print("Miguel has NOT passed Maria yet.")

# Did Maria Like Miguel?
like_back = cur.execute("SELECT * FROM likes WHERE liker_id=? AND liked_id=?", (maria['id'], miguel['id'])).fetchone()
if like_back:
    print(f"❤️ MARIA ALREADY LIKED MIGUEL on {like_back['created_at']}")
else:
    print("Maria has NOT liked Miguel yet.")

# CHECK MATCH
match = cur.execute("SELECT * FROM matches WHERE (user1_id=? AND user2_id=?) OR (user1_id=? AND user2_id=?)", (miguel['id'], maria['id'], maria['id'], miguel['id'])).fetchone()
if match:
    print(f"✅ MATCH EXISTS! Created on {match['created_at']}")
else:
    print("No existing match.")

con.close()
