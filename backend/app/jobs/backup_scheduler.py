import os
import subprocess
import time
from pathlib import Path
from datetime import datetime, timedelta
import structlog
from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger
import pytz

logger = structlog.get_logger("backup_scheduler")

# Configuration
LOCK_DIR = Path("/data/locks")
LOCK_FILE = LOCK_DIR / "backup_db.lock"
BACKUP_SCRIPT = "/app/scripts/backup_db.py"
TIMEZONE = "America/Monterrey"
LOCK_TIMEOUT_HOURS = 2

def run_backup_job():
    """
    Executes the backup script with atomic locking logic.
    """
    logger.info("backup_job_attempt")

    # 1. Ensure /data/locks exists (or fallback to local if not in Fly)
    if not Path("/data").exists():
        # Fallback for local development
        local_lock_dir = Path("./locks")
        local_lock_dir.mkdir(parents=True, exist_ok=True)
        lock_file = local_lock_dir / "backup_db.lock"
        script_path = str(Path("./scripts/backup_db.py").resolve())
        logger.warning("backup_skipped_no_data_dir", use_local=str(local_lock_dir))
    else:
        LOCK_DIR.mkdir(parents=True, exist_ok=True)
        lock_file = LOCK_FILE
        script_path = BACKUP_SCRIPT

    # 2. Atomic Lock Check
    if lock_file.exists():
        mtime = datetime.fromtimestamp(lock_file.stat().st_mtime)
        if datetime.now() - mtime < timedelta(hours=LOCK_TIMEOUT_HOURS):
            logger.info("skipped_locked", lock_file=str(lock_file), age_hours=(datetime.now() - mtime).total_seconds() / 3600)
            return
        else:
            logger.warning("stale_lock_found", lock_file=str(lock_file), last_modified=mtime.isoformat())
            lock_file.unlink()

    # 3. Create Lock
    try:
        lock_file.touch()
        logger.info("lock_acquired", lock_file=str(lock_file))
        
        # 4. Execute Backup Script
        logger.info("backup_script_execution_start", script=script_path)
        
        # Ensure we use the same python interpreter
        result = subprocess.run(
            ["python", script_path],
            capture_output=True,
            text=True
        )

        if result.returncode == 0:
            logger.info("backup_script_execution_success", stdout=result.stdout.strip())
        else:
            logger.error("backup_script_execution_failed", 
                         returncode=result.returncode, 
                         stderr=result.stderr.strip(),
                         stdout=result.stdout.strip())
            
    except Exception as e:
        logger.error("backup_job_error", error=str(e))
    finally:
        # 5. Cleanup Lock
        if lock_file.exists():
            lock_file.unlink()
            logger.info("lock_released", lock_file=str(lock_file))

def setup_scheduler(app=None):
    """
    Initializes and starts the BackgroundScheduler.
    """
    scheduler = BackgroundScheduler(timezone=pytz.timezone(TIMEZONE))
    
    # Schedule job at 02:00 AM America/Monterrey
    trigger = CronTrigger(hour=2, minute=0)
    scheduler.add_job(
        run_backup_job,
        trigger=trigger,
        id="daily_db_backup",
        name="Daily Database Backup to R2",
        replace_existing=True
    )
    
    scheduler.start()
    logger.info("scheduler_started", timezone=TIMEZONE, schedule="02:00 daily")

    # Manual trigger via ENV VAR for testing/forced backups
    if os.getenv("RUN_BACKUP_NOW", "false").lower() == "true":
        logger.info("manual_trigger_started_via_env")
        # Run in a separate thread/background to not block startup
        scheduler.add_job(run_backup_job, id="manual_backup_now")

    return scheduler
