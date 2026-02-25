import os
import sys
import time
import shutil
import sqlite3
import hashlib
from datetime import datetime, timezone
import json
import structlog

# Set up logging to match project
try:
    structlog.configure(
        processors=[
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.processors.JSONRenderer()
        ],
        logger_factory=structlog.PrintLoggerFactory(),
    )
    logger = structlog.get_logger("backup")
except Exception:
    import logging
    logger = logging.getLogger("backup")

try:
    import boto3
    BOTO3_AVAILABLE = True
except ImportError:
    BOTO3_AVAILABLE = False

DB_PATH = os.getenv("DB_PATH", "/data/celestya.db")
BACKUP_DIR = os.getenv("BACKUP_DIR", "/data/backups")
RETENTION_DAYS = int(os.getenv("BACKUP_RETENTION_DAYS", "7"))

# R2 ENV VARS (Using Boto3 Standard Env Vars, or fallbacks if defined as in previous script)
R2_ENDPOINT = os.getenv("R2_ENDPOINT", os.getenv("R2_ENDPOINT_URL"))
R2_ACCESS_KEY_ID = os.getenv("R2_ACCESS_KEY_ID")
R2_SECRET_ACCESS_KEY = os.getenv("R2_SECRET_ACCESS_KEY")
R2_BUCKET = os.getenv("R2_BUCKET", os.getenv("R2_BUCKET_NAME"))
R2_PREFIX = os.getenv("R2_PREFIX", "db_backups/")

def _sha256sum(filename):
    h = hashlib.sha256()
    b = bytearray(128 * 1024)
    mv = memoryview(b)
    with open(filename, 'rb', buffering=0) as f:
        while n := f.readinto(mv):
            h.update(mv[:n])
    return h.hexdigest()

def execute_wal_checkpoint(db_path):
    logger.info("backup_wal_checkpoint_start", db_path=db_path)
    conn = None
    try:
        # Require timeout and immediately set Pragmas
        conn = sqlite3.connect(db_path, timeout=5.0)
        conn.execute("PRAGMA busy_timeout=5000;")
        conn.execute("PRAGMA foreign_keys=ON;")
        
        # Attepmt FULL checkpoint (retrying on busy)
        max_retries = 3
        for attempt in range(max_retries):
            try:
                cursor = conn.execute("PRAGMA wal_checkpoint(FULL);")
                row = cursor.fetchone()
                # Format: (busy, log, checkpointed)
                if row and row[0] == 1:
                    logger.warning("backup_wal_FULL_busy", attempt=attempt+1, result=row)
                    time.sleep(2)
                    continue
                else:
                    logger.info("backup_wal_FULL_success", result=row)
                    break
            except sqlite3.OperationalError as e:
                if "database is locked" in str(e).lower() or "busy" in str(e).lower():
                    logger.warning("backup_wal_FULL_locked", attempt=attempt+1, error=str(e))
                    time.sleep(2)
                else:
                    raise e
        
        # TRUNCATE checkpoint
        try:
            cursor = conn.execute("PRAGMA wal_checkpoint(TRUNCATE);")
            logger.info("backup_wal_TRUNCATE", result=cursor.fetchone())
        except Exception as e:
            logger.error("backup_wal_TRUNCATE_error", error=str(e))

    except Exception as e:
        logger.error("backup_wal_error", error=str(e))
    finally:
        if conn:
            conn.close()

def upload_to_r2(filepath, final_filename):
    if not BOTO3_AVAILABLE:
        logger.info("backup_r2_skip", reason="boto3_missing")
        return False, None
    
    if not all([R2_ENDPOINT, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_BUCKET]):
        logger.info("backup_r2_skip", reason="missing_credentials")
        return False, None

    r2_key = f"{R2_PREFIX.rstrip('/')}/{final_filename}"
    logger.info("backup_r2_upload_start", bucket=R2_BUCKET, key=r2_key, endpoint=R2_ENDPOINT)
    
    start_time = time.time()
    try:
        s3 = boto3.client('s3',
            endpoint_url=R2_ENDPOINT,
            aws_access_key_id=R2_ACCESS_KEY_ID,
            aws_secret_access_key=R2_SECRET_ACCESS_KEY,
            region_name="auto"
        )
        s3.upload_file(filepath, R2_BUCKET, r2_key)
        
        duration = time.time() - start_time
        logger.info("backup_r2_upload_success", duration_s=f"{duration:.2f}")
        return True, r2_key
    except Exception as e:
        logger.error("backup_r2_upload_failed", error=str(e))
        return False, None

def cleanup_old_backups():
    logger.info("backup_cleanup_start", retention_days=RETENTION_DAYS, dir=BACKUP_DIR)
    now = time.time()
    retention_seconds = RETENTION_DAYS * 86400
    cleaned = 0
    try:
        for filename in os.listdir(BACKUP_DIR):
            if filename.startswith("celestya_") or filename.startswith("celestya-"):
                if not filename.endswith(".db"):
                    continue
                file_path = os.path.join(BACKUP_DIR, filename)
                try:
                    mtime = os.path.getmtime(file_path)
                    if (now - mtime) > retention_seconds:
                        os.remove(file_path)
                        logger.info("backup_deleted", file=filename)
                        cleaned += 1
                except OSError:
                    pass
        logger.info("backup_cleanup_complete", cleaned=cleaned)
    except Exception as e:
         logger.error("backup_cleanup_failed", error=str(e))

def run_backup():
    logger.info("backup_job_start")
    
    real_db_path = DB_PATH
    if not os.path.exists(real_db_path):
        # Fallback for testing if local ./celestya.db exists
        if os.path.exists("celestya.db"):
             real_db_path = "celestya.db"
             logger.warning("backup_source_switch", reason="default_not_found", new_source=real_db_path)
        else:
            logger.critical("backup_db_missing", path=DB_PATH)
            sys.exit(2)
        
    os.makedirs(BACKUP_DIR, exist_ok=True)
    
    # 1. Checkpoint WAL
    execute_wal_checkpoint(real_db_path)
    
    # 2. Atomic Copy
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
    final_filename = f"celestya_{timestamp}.db"
    tmp_path = os.path.join(BACKUP_DIR, f"{final_filename}.tmp")
    final_path = os.path.join(BACKUP_DIR, final_filename)
    
    logger.info("backup_copy_start", temp=tmp_path)
    try:
        shutil.copy2(real_db_path, tmp_path)
        os.rename(tmp_path, final_path)
        logger.info("backup_copy_success")
    except Exception as e:
         logger.critical("backup_copy_failed", error=str(e))
         sys.exit(1)
         
    size_bytes = os.path.getsize(final_path)
    sha256_hash = _sha256sum(final_path)
    
    logger.info("backup_success", 
        file=final_filename, 
        size_bytes=size_bytes, 
        size_mb=f"{size_bytes / 1024 / 1024:.2f}",
        sha256=sha256_hash
    )
    
    # 3. Cleanup old local backups
    cleanup_old_backups()
    
    # 4. Upload to R2 (Optional)
    uploaded, r2_key = upload_to_r2(final_path, final_filename)
    
    # Output final stats as JSON at the very end string format
    output = {
        "db_path": real_db_path,
        "backup_path": final_path,
        "bytes": size_bytes,
        "sha256": sha256_hash,
        "timestamp": timestamp,
        "uploaded_r2": uploaded,
        "r2_key": r2_key
    }
    
    print("\n[RESULT_JSON]")
    print(json.dumps(output, indent=2))
    print("[RESULT_END]")
    sys.exit(0)

if __name__ == "__main__":
    run_backup()
