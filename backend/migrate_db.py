import sqlite3
import os

# Fly.io persistent volume is usually at /data
db_path = "/data/celestya.db"
if not os.path.exists(db_path):
    # Fallback to local path if not in production folder
    db_path = "./celestya.db"

print(f"Connecting to database at {db_path}...")
conn = sqlite3.connect(db_path)
cursor = conn.cursor()

try:
    print("Adding email_verification_link_token column...")
    cursor.execute("ALTER TABLE users ADD COLUMN email_verification_link_token TEXT")
except sqlite3.OperationalError:
    print("Column email_verification_link_token already exists.")

try:
    print("Adding email_verification_link_expires_at column...")
    cursor.execute("ALTER TABLE users ADD COLUMN email_verification_link_expires_at DATETIME")
except sqlite3.OperationalError:
    print("Column email_verification_link_expires_at already exists.")

try:
    print("Adding email_verification_link_used column...")
    cursor.execute("ALTER TABLE users ADD COLUMN email_verification_link_used BOOLEAN DEFAULT 0")
except sqlite3.OperationalError:
    print("Column email_verification_link_used already exists.")

conn.commit()
conn.close()
print("Migration completed successfully!")
