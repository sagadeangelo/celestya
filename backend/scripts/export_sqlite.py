import os
import sqlite3
import shutil
import hashlib
import datetime
import structlog
import sys
from pathlib import Path

# Configure logging
structlog.configure(
    processors=[
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.JSONRenderer()
    ],
    logger_factory=structlog.PrintLoggerFactory(),
)
logger = structlog.get_logger("export_sqlite")

# Config
DB_PATH = os.getenv("DB_PATH", "/data/celestya.db")
EXPORT_DIR = os.getenv("EXPORT_DIR", "/data/exports")

def calculate_sha256(filepath):
    """Calculates SHA256 hash of a file."""
    sha256_hash = hashlib.sha256()
    with open(filepath, "rb") as f:
        # Read and update hash string value in blocks of 4K
        for byte_block in iter(lambda: f.read(4096), b""):
            sha256_hash.update(byte_block)
    return sha256_hash.hexdigest()

def export_db():
    if not os.path.exists(DB_PATH):
        # Fallback for local testing
        if os.path.exists("celestya.db"):
            real_db_path = "celestya.db"
            logger.info("using_local_db_fallback", path=real_db_path)
        else:
            logger.error("db_not_found", path=DB_PATH)
            sys.exit(1)
    else:
        real_db_path = DB_PATH
        
    Path(EXPORT_DIR).mkdir(parents=True, exist_ok=True)
    
    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    export_base = f"celestya_export_{timestamp}"
    
    logger.info("export_started", source=real_db_path)

    # 1. WAL Checkpoint (Flush to main file)
    try:
        conn = sqlite3.connect(real_db_path)
        conn.execute("PRAGMA wal_checkpoint(FULL);")
        conn.close()
        logger.info("wal_checkpoint_complete")
    except Exception as e:
        logger.error("wal_checkpoint_failed", error=str(e))
        # Continue anyway, backup API usually handles this
        
    # 2. Binary Copy
    binary_filename = f"{export_base}.db"
    binary_path = os.path.join(EXPORT_DIR, binary_filename)
    
    try:
        src = sqlite3.connect(real_db_path)
        dst = sqlite3.connect(binary_path)
        with dst:
            src.backup(dst)
        dst.close()
        src.close()
        
        binary_hash = calculate_sha256(binary_path)
        logger.info("binary_export_success", path=binary_path, sha256=binary_hash)
    except Exception as e:
        logger.error("binary_export_failed", error=str(e))
        sys.exit(1)

    # 3. SQL Dump
    sql_filename = f"{export_base}.sql"
    sql_path = os.path.join(EXPORT_DIR, sql_filename)
    
    try:
        conn = sqlite3.connect(binary_path) # Dump from the stable copy
        with open(sql_path, 'w', encoding='utf-8') as f:
            for line in conn.iterdump():
                f.write('%s\n' % line)
        conn.close()
        
        sql_hash = calculate_sha256(sql_path)
        logger.info("sql_dump_success", path=sql_path, sha256=sql_hash)
        
    except Exception as e:
        logger.error("sql_dump_failed", error=str(e))
        
    print(f"\n✅ EXPORT COMPLETE")
    print(f"Binary: {binary_path} (SHA256: {binary_hash})")
    print(f"SQL:    {sql_path} (SHA256: {sql_hash})")

if __name__ == "__main__":
    export_db()
