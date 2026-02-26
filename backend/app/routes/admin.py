import os
import shutil
import structlog
from fastapi import APIRouter, Depends, HTTPException, Header, status
from sqlalchemy import text
from sqlalchemy.orm import Session
from ..database import get_db, DATABASE_URL
from ..security import utcnow
from ..models import UserVerification, User
from ..schemas import AdminVerificationOut, AdminRejectIn
from ..services.r2_client import presigned_get_url
from .auth import get_current_user
from ..review_access import is_reviewer_admin, get_dummy_admin_verifications

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
                stats["db_size_bytes"] = os.path.getsize(db_path)
                stats["db_exists"] = True
                
                # PRAGMAs & Integrity
                try:
                    stats["journal_mode"] = db.execute(text("PRAGMA journal_mode")).scalar()
                    stats["wal_autocheckpoint"] = db.execute(text("PRAGMA wal_autocheckpoint")).scalar()
                    stats["integrity_ok"] = db.execute(text("PRAGMA integrity_check")).scalar()
                except Exception as e:
                    stats["pragma_error"] = str(e)
            else:
                 stats["db_exists"] = False
                 stats["db_size_bytes"] = 0
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

        try:
            stats["refresh_tokens_total"] = db.execute(text("SELECT count(*) FROM refresh_tokens")).scalar()
            stats["refresh_tokens_active"] = db.execute(text(
                "SELECT count(*) FROM refresh_tokens WHERE revoked_at IS NULL AND expires_at > :now"
            ), {"now": utcnow()}).scalar()
            stats["refresh_tokens_revoked"] = db.execute(text(
                "SELECT count(*) FROM refresh_tokens WHERE revoked_at IS NOT NULL"
            )).scalar()
        except Exception as e:
            stats["refresh_tokens_stats_error"] = str(e)
            
    except Exception as e:
        stats["query_error"] = str(e)
        
    # 2.5 Alembic Revisions
    try:
        stats["alembic_current_rev"] = db.execute(text("SELECT version_num FROM alembic_version")).scalar()
    except Exception:
        stats["alembic_current_rev"] = "table_not_found_or_error"
        
    try:
        import alembic.config
        import alembic.script
        alembic_cfg = alembic.config.Config("alembic.ini")
        script = alembic.script.ScriptDirectory.from_config(alembic_cfg)
        stats["alembic_head_rev"] = script.get_current_head()
    except Exception as e:
        stats["alembic_head_rev"] = f"error: {str(e)}"

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


@router.get("/debug_verifications", dependencies=[Depends(verify_admin_secret)])
def debug_verifications(db: Session = Depends(get_db)):
    """
    Endpoint temporal para debugging: lista TODO en UserVerification.
    """
    all_v = db.query(UserVerification).all()
    results = []
    for v in all_v:
        results.append({
            "id": v.id,
            "user_id": v.user_id,
            "status": v.status,
            "image_key": v.image_key,
            "created_at": v.created_at.isoformat() if v.created_at else None,
            "attempt": v.attempt
        })
    return results

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


# ----------------------------
# Admin Identity Verification
# ----------------------------

@router.get("/verifications", dependencies=[Depends(verify_admin_secret)])
def list_verifications(
    status: str = "pending_review",
    limit: int = 50,
    offset: int = 0,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Lista solicitudes de verificación para revisión admin.
    """
    # KILL-SWITCH: Google Play Review Admin Mock
    if is_reviewer_admin(current_user.email):
        return get_dummy_admin_verifications()
    # Si viene como 'pending' (legacy o error frontend), mapear a 'pending_review'
    if status == "pending":
        status = "pending_review"
        
    query = (
        db.query(UserVerification)
        .join(User)
        .filter(UserVerification.status == status)
        .filter(UserVerification.image_key != None) # Solo las que tienen foto
        .order_by(UserVerification.created_at.desc())
    )
    
    results = query.offset(offset).limit(limit).all()
    
    out = []
    for v in results:
        signed_url = None
        if v.image_key:
            signed_url = presigned_get_url(v.image_key, expires_seconds=600)
        
        out.append({
            "id": v.id,
            "userId": v.user_id,
            "userEmail": v.user.email,
            "userName": v.user.name,
            "instruction": v.instruction,
            "status": v.status,
            "attempt": v.attempt,
            "createdAt": v.created_at,
            "imageSignedUrl": signed_url
        })
    
    return out

@router.post("/verifications/{id}/approve", dependencies=[Depends(verify_admin_secret)])
def approve_verification(id: int, db: Session = Depends(get_db)):
    """
    Aprueba una solicitud de verificación.
    """
    v = db.query(UserVerification).filter(UserVerification.id == id).first()
    if not v:
        raise HTTPException(status_code=404, detail="Solicitud no encontrada")
    
    v.status = "approved"
    v.reviewed_at = utcnow()
    v.rejection_reason = None
    
    db.commit()
    logger.info("admin_approve_verification", verification_id=id, user_id=v.user_id)
    return {"ok": True}

@router.post("/verifications/{id}/reject", dependencies=[Depends(verify_admin_secret)])
def reject_verification(id: int, body: AdminRejectIn, db: Session = Depends(get_db)):
    """
    Rechaza una solicitud de verificación con una razón.
    """
    v = db.query(UserVerification).filter(UserVerification.id == id).first()
    if not v:
        raise HTTPException(status_code=404, detail="Solicitud no encontrada")
    
    v.status = "rejected"
    v.rejection_reason = body.reason
    v.reviewed_at = utcnow()
    
    db.commit()
    logger.info("admin_reject_verification", verification_id=id, user_id=v.user_id, reason=body.reason)
    return {"ok": True}
