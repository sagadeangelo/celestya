import sqlite3
import os
import sys

# Default to /data/celestya.db if on Fly, else local
DB = os.getenv("DATABASE_URL", "/data/celestya.db").replace("sqlite:///", "")
if DB.startswith("sqlite:/"):
     DB = DB.replace("sqlite:/", "")

print(f"Connecting to DB: {DB} (SCHEMA FIX)")

try:
    con = sqlite3.connect(DB)
    cur = con.cursor()
    
    print("\n1. Dropping incorrect 'blocks' table...")
    try:
        cur.execute("DROP TABLE IF EXISTS blocks")
        print("   -> Dropped.")
    except Exception as e:
        print(f"   -> Error dropping table: {e}")

    print("\n2. Recreating 'blocks' table with CORRECT schema (matching models.py)...")
    # Schema from models.py:
    # id = Column(Integer, primary_key=True, index=True)
    # blocker_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    # blocked_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    # created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    
    create_sql = """
    CREATE TABLE blocks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        blocker_id INTEGER NOT NULL,
        blocked_id INTEGER NOT NULL,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(blocker_id) REFERENCES users(id),
        FOREIGN KEY(blocked_id) REFERENCES users(id),
        CONSTRAINT uq_block_active UNIQUE (blocker_id, blocked_id)
    );
    """
    
    try:
        cur.execute(create_sql)
        print("   -> Table 'blocks' created successfully.")
    except Exception as e:
        print(f"   -> Error creating table: {e}")
        sys.exit(1)

    # Validate
    print("\n3. Verifying new schema...")
    rows = cur.execute("PRAGMA table_info(blocks)").fetchall()
    for r in rows:
        print(f"   Column: {r[1]} ({r[2]})")

    con.commit()
    con.close()
    print("\nSUCCESS: Schema mismatch resolved.")

except Exception as e:
    print(f"Connection failed: {e}")
