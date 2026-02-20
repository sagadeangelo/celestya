import os
import shutil
import sqlite3
import time
import datetime
import structlog
import boto3
from pathlib import Path
import sys

# Configure logging
structlog.configure(
    processors=[
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.JSONRenderer()
    ],
    logger_factory=structlog.PrintLoggerFactory(),
)
logger = structlog.get_logger("backup")

# Configuration
DB_PATH = os.getenv("DB_PATH", "/data/celestya.db")
BACKUP_DIR = os.getenv("BACKUP_DIR", "/data/backups")
RETENTION_DAYS = int(os.getenv("BACKUP_RETENTION_DAYS", "7"))

# R2 Configuration
R2_ACCOUNT_ID = os.getenv("R2_ACCOUNT_ID")
R2_ACCESS_KEY_ID = os.getenv("R2_ACCESS_KEY_ID")
R2_SECRET_ACCESS_KEY = os.getenv("R2_SECRET_ACCESS_KEY")
R2_BUCKET_NAME = os.getenv("R2_BUCKET_NAME")
# R2 Endpoint usually: https://<account_id>.r2.cloudflarestorage.com
# Boto3 expects endpoint_url
R2_ENDPOINT = os.getenv("R2_ENDPOINT_URL") 

def create_backup():
    """
    Safely backup SQLite DB using the Online Backup API.
    """
    # If using /data/celestya.db but running locally where /data doesn't exist, allow override
    real_db_path = DB_PATH
    if not os.path.exists(real_db_path):
        # Fallback for testing if local ./celestya.db exists
        if os.path.exists("celestya.db"):
             real_db_path = "celestya.db"
             logger.info("backup_source_switch", reason="default_not_found", new_source=real_db_path)
        else:
            logger.error("db_not_found", path=DB_PATH)
            return False

    Path(BACKUP_DIR).mkdir(parents=True, exist_ok=True)

    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_filename = f"celestya_{timestamp}.db"
    backup_path = os.path.join(BACKUP_DIR, backup_filename)

    start_time = time.time()
    try:
        # Connect to existing DB
        # Use simple connection to trigger checkpoint if needed, but the backup API handles it well
        src = sqlite3.connect(real_db_path)
        dst = sqlite3.connect(backup_path)
        
        # Use SQLite Backup API
        with dst:
            src.backup(dst, pages=1) # 1 page per step (slow but non-blocking)
        
        dst.close()
        src.close()
        
        size_mb = os.path.getsize(backup_path) / (1024 * 1024)
        duration = time.time() - start_time
        
        logger.info("backup_success", 
                    file=backup_filename, 
                    size_mb=f"{size_mb:.2f}", 
                    duration_s=f"{duration:.2f}",
                    source=real_db_path)
        
        return backup_path
        
    except Exception as e:
        logger.error("backup_failed", error=str(e))
        if os.path.exists(backup_path):
            os.remove(backup_path)
        return None

def rotate_backups():
    """
    Delete backups older than RETENTION_DAYS
    """
    try:
        now = time.time()
        retention_seconds = RETENTION_DAYS * 86400
        
        deleted_count = 0
        if not os.path.exists(BACKUP_DIR):
            return

        for f in os.listdir(BACKUP_DIR):
            f_path = os.path.join(BACKUP_DIR, f)
            if not f.endswith(".db"):
                continue
            
            try:
                stat = os.stat(f_path)
                if stat.st_mtime < (now - retention_seconds):
                    os.remove(f_path)
                    deleted_count += 1
                    logger.info("backup_rotated", file=f)
            except OSError:
                pass
                
        if deleted_count > 0:
            logger.info("rotation_complete", deleted=deleted_count)
            
    except Exception as e:
        logger.error("rotation_error", error=str(e))

def upload_to_r2(backup_path):
    """
    Upload to Cloudflare R2
    """
    if not (R2_ACCESS_KEY_ID and R2_SECRET_ACCESS_KEY and R2_BUCKET_NAME and R2_ENDPOINT):
        logger.info("r2_upload_skipped", reason="missing_credentials")
        return

    try:
        s3 = boto3.client(
            's3',
            endpoint_url=R2_ENDPOINT,
            aws_access_key_id=R2_ACCESS_KEY_ID,
            aws_secret_access_key=R2_SECRET_ACCESS_KEY,
            region_name="auto" 
        )
        
        filename = os.path.basename(backup_path)
        key = f"db_backups/{filename}"
        
        logger.info("r2_upload_start", key=key)
        start_time = time.time()
        
        s3.upload_file(backup_path, R2_BUCKET_NAME, key)
        
        duration = time.time() - start_time
        logger.info("r2_upload_success", key=key, duration_s=f"{duration:.2f}")
        
    except Exception as e:
        logger.error("r2_upload_failed", error=str(e))

if __name__ == "__main__":
    logger.info("backup_job_start")
    
    backup_file = create_backup()
    
    if backup_file:
        rotate_backups()
        upload_to_r2(backup_file)
    else:
        sys.exit(1)
