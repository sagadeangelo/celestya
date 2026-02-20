import os
import shutil
import structlog
from fastapi import APIRouter, Depends, HTTPException, Header, status
from sqlalchemy import text
from sqlalchemy.orm import Session
from ..database import get_db, DATABASE_URL
from ..security import utcnow

router = APIRouter()
logger = structlog.get_logger("admin")

ADMIN_SECRET = os.getenv("ADMIN_SECRET")

def verify_admin_secret(x_admin_secret: str = Header(None)):
    """
    Protect admin routes.
    If ADMIN_SECRET is not set in env, these routes are effectively disabled (or open if logic allows, but here we deny).
    """
    if not ADMIN_SECRET:
        # If no secret configured in backend, deny access to be safe
        raise HTTPException(status_code=503, detail="Admin secret not configured on server.")
    
    if x_admin_secret != ADMIN_SECRET:
        logger.warning("admin_auth_failed", attempted_secret=x_admin_secret[:3]+"***" if x_admin_secret else "None")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Admin Secret",
        )
    return True

@router.get("/stats", dependencies=[Depends(verify_admin_secret)])
def get_admin_stats(db: Session = Depends(get_db)):
    """
    Retorna estadisticas vitales para verificar persistencia.
    """
    stats = {
        "server_time_utc": utcnow().isoformat(),
        "database_url_configured": DATABASE_URL, # Be careful not to leak passwords if postgres
        "env": os.getenv("ENV", "unknown")
    }

    # 1. DB Path & Size (SQLite specific)
    if "sqlite" in DATABASE_URL:
        try:
            db_path = DATABASE_URL.replace("sqlite:///", "").replace("sqlite:", "")
            if DATABASE_URL.startswith("sqlite:////"):
                db_path = "/" + DATABASE_URL.split("////")[-1]
            
            stats["db_path_resolved"] = db_path
            if os.path.exists(db_path):
                stats["db_size_mb"] = round(os.path.getsize(db_path) / (1024 * 1024), 2)
                stats["db_exists"] = True
            else:
                 stats["db_exists"] = False
                 stats["db_size_mb"] = 0
        except Exception as e:
            stats["db_file_error"] = str(e)
    
    # 2. Row Counts
    try:
        stats["user_count"] = db.execute(text("SELECT count(*) FROM users")).scalar()
        stats["match_count"] = db.execute(text("SELECT count(*) FROM matches")).scalar()
        # Check if chats/messages tables exist
        try:
            stats["chat_count"] = db.execute(text("SELECT count(*) FROM chats")).scalar()
        except:
            stats["chat_count"] = "table_not_found"
            
        try:
            stats["message_count"] = db.execute(text("SELECT count(*) FROM messages")).scalar()
        except:
            stats["message_count"] = "table_not_found"
            
    except Exception as e:
        stats["query_error"] = str(e)

    # 3. Backups check
    backup_dir = os.getenv("BACKUP_DIR", "/data/backups")
    if os.path.exists(backup_dir):
        files = [f for f in os.listdir(backup_dir) if f.endswith(".db")]
        stats["backup_count"] = len(files)
        stats["latest_backups"] = sorted(files, reverse=True)[:3]
    else:
        stats["backup_count"] = 0
        stats["backup_dir_exists"] = False

    return stats


@router.get("/schema", dependencies=[Depends(verify_admin_secret)])
def verify_schema(db: Session = Depends(get_db)):
    """
    Verifica que columnas críticas existan (sanity check de migración).
    """
    # Lista de columnas críticas a verificar (table, column)
    critical_checks = [
        ("users", "last_seen"),
        ("users", "email_verified"),
        ("users", "email_verification_token_hash"),
        ("users", "gallery_photo_keys"), # JSON col check
    ]
    
    results = {
        "ok": True,
        "missing": [],
        "present": []
    }
    
    for table, col in critical_checks:
        try:
            # SQLite way to check columns
            # PRAGMA table_info(table_name) -> returns list of (cid, name, type, notnull, dflt_value, pk)
            query = text(f"PRAGMA table_info({table})")
            columns = [row[1] for row in db.execute(query).fetchall()]
            
            if not columns:
                results["missing"].append(f"Table {table} not found or empty schema")
                results["ok"] = False
            elif col not in columns:
                results["missing"].append(f"{table}.{col}")
                results["ok"] = False
            else:
                results["present"].append(f"{table}.{col}")
                
        except Exception as e:
            results["error"] = str(e)
            results["ok"] = False
            
    return results
