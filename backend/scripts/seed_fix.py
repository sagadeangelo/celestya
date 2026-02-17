import sqlite3
import random
import datetime
import os
import sys

# Default to /data/celestya.db if on Fly, else local
DB = os.getenv("DATABASE_URL", "/data/celestya.db").replace("sqlite:///", "")
if DB.startswith("sqlite:/"):
     DB = DB.replace("sqlite:/", "") # Handle variants

print(f"Connecting to DB: {DB} (SEED FIX VERSION)")

N = 10

# choose base coords (Piedras Negras)
BASE_CITY = "Piedras Negras, Coahuila"
BASE_LAT = 28.7136
BASE_LON = -100.5205

def jitter(x, amount=0.15):
    return x + random.uniform(-amount, amount)

def rand_birthdate():
    start = datetime.date(1985, 1, 1).toordinal()
    end = datetime.date(1998, 12, 31).toordinal()
    d = datetime.date.fromordinal(random.randint(start, end))
    return d.isoformat()

try:
    con = sqlite3.connect(DB)
except Exception as e:
    print(f"Could not connect to {DB}: {e}")
    sys.exit(1)

cur = con.cursor()

# find reusable photo key
try:
    row = cur.execute("""
    SELECT profile_photo_key FROM users
    WHERE profile_photo_key IS NOT NULL AND profile_photo_key <> ''
    LIMIT 1
    """).fetchone()
    photo_key = row[0] if row and row[0] else "uploads/test_female_7297.jpg"
except Exception as e:
    print(f"Error checking photo key: {e}")
    photo_key = "uploads/test_female_7297.jpg"

print(f"Using profile_photo_key: {photo_key}")

# detect if table has created_at/updated_at columns
try:
    cols = [r[1] for r in cur.execute("PRAGMA table_info(users)").fetchall()]
    has_created = "created_at" in cols
    has_updated = "updated_at" in cols
except Exception:
    cols = []
    has_created = False
    has_updated = False

now = datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds")

print(f"Seeding {N} users...")
for i in range(1, N + 1):
    email = f"tester_female_{i:02d}@celestya.test"
    name = f"Tester Mujer {i:02d}"
    birth = rand_birthdate()
    # Explicitly using a bucket that we know exists in enums or logic
    age_bucket = "B_26_45"  
    city = BASE_CITY
    lat = jitter(BASE_LAT, 0.20)
    lon = jitter(BASE_LON, 0.20)

    exists = cur.execute("SELECT id FROM users WHERE email=?", (email,)).fetchone()

    if exists:
        q = """
        UPDATE users SET
          name=?,
          gender='female',
          show_me='male',
          birthdate=?,
          age_bucket=?,
          city=?,
          lat=?,
          lon=?,
          email_verified=1,
          profile_photo_key=?,
          password_hash=?,
          wants_adjacent_bucket=0,
          interests='[]',
          gallery_photo_keys='[]',
          email_verification_link_used=0
        """
        # Added dummy hash to update as well, just in case
        params = [name, birth, age_bucket, city, lat, lon, photo_key, "dummy_hash_fixed"]
        if has_updated:
            q += ", updated_at=?"
            params.append(now)
        q += " WHERE email=?"
        params.append(email)
        cur.execute(q, params)
        print(f"Updated {email}")
    else:
        # Build insert dynamically
        # FIXED: Included password_hash AND ALL other non-nullable defaults that raw SQL might miss
        insert_cols = [
            "email", "name", "gender", "show_me", "birthdate", "age_bucket", 
            "city", "lat", "lon", "email_verified", "profile_photo_key", "password_hash",
            "wants_adjacent_bucket", "interests", "gallery_photo_keys", "email_verification_link_used"
        ]
        insert_vals = [
            email, name, "female", "male", birth, age_bucket, 
            city, lat, lon, 1, photo_key, "dummy_hash_fixed",
            0, "[]", "[]", 0
        ]
        
        if has_created:
            insert_cols.append("created_at")
            insert_vals.append(now)
        if has_updated:
            insert_cols.append("updated_at")
            insert_vals.append(now)

        placeholders = ','.join(['?'] * len(insert_cols))
        sql = f"INSERT INTO users ({','.join(insert_cols)}) VALUES ({placeholders})"
        cur.execute(sql, insert_vals)
        print(f"Inserted {email}")

con.commit()

# report
try:
    female_count = cur.execute("SELECT COUNT(*) FROM users WHERE gender='female'").fetchone()[0]
    print("FEMALE COUNT:", female_count)
except Exception:
    print("Could not count females")

con.close()
