import os
import sys
from datetime import datetime
import glob
import structlog
from sqlalchemy import create_engine, text, event
from sqlalchemy.orm import declarative_base, sessionmaker

logger = structlog.get_logger("db")

# 1. Configuración de Entorno
# ---------------------------------------------------------
ENV = os.getenv("ENV", "development").lower()
IS_PROD = ENV == "production"

def _get_db_url():
    """
    Define la URL de la BD. 
    En PROD, DEBE ser /data/celestya.db (Persistent Volume).
    """
    if IS_PROD:
        # Check if we are explicitly given a Postgres URL
        url_env = os.getenv("DATABASE_URL", "").strip()
        if url_env.startswith("postgres://") or url_env.startswith("postgresql://"):
            return url_env

        # FAIL-FAST: Si no existe /data, abortar startup.
        if not os.path.exists("/data"):
            msg = "[CRITICAL] /data volume NOT FOUND in production. Aborting to prevent ephemeral DB creation."
            print(msg, file=sys.stderr)
            raise RuntimeError(msg)
        
        # FAIL-FAST Sentinel: Verificar que el volumen es persistente
        sentinel_path = "/data/.celestya_volume_sentinel"
        try:
            if not os.path.exists(sentinel_path):
                with open(sentinel_path, "w") as f:
                    f.write(f"Volume attached on {datetime.utcnow().isoformat()}")
                print(f"[INFO] Created volume sentinel file: {sentinel_path}", file=sys.stderr)
        except Exception as e:
            msg = f"[CRITICAL] Could not write to /data volume ({e}). Aborting."
            print(msg, file=sys.stderr)
            raise RuntimeError(msg)
        
        # FAIL-FAST: Evitar bases de datos en /app (evita silently writing to ephemeral storage)
        # Check carefully without traversing everything
        app_dbs = glob.glob("/app/**/*.db", recursive=True)
        if app_dbs:
            msg = f"[CRITICAL] Ephemeral database files detected in /app: {app_dbs}. Aborting."
            print(msg, file=sys.stderr)
            raise RuntimeError(msg)
        
        db_path = "/data/celestya.db"
        
        # Verificar permisos de escritura (opcional pero recomendado)
        if not os.access("/data", os.W_OK):
             msg = "[CRITICAL] /data volume is NOT WRITABLE. Aborting."
             print(msg, file=sys.stderr)
             raise RuntimeError(msg)

        return f"sqlite:///{db_path}"
    
    # DEV / LOCAL
    url_env = os.getenv("DATABASE_URL", "").strip()
    if url_env.startswith("postgres"):
        return url_env

    # Si existe /data (ej. simulando prod localmente), lo usamos
    if os.path.exists("/data"):
        return "sqlite:////data/celestya.db"
        
    return "sqlite:///./celestya.db"

DATABASE_URL = _get_db_url()

# En PROD, prohibir override peligroso si apunta a local (SOLO SI NO ES POSTGRES)
if IS_PROD and "sqlite:///" in DATABASE_URL and "/data/" not in DATABASE_URL:
     msg = f"[SECURITY] DATABASE_URL={DATABASE_URL} invalid for PROD. Must use /data volume or Postgres."
     raise RuntimeError(msg)

# 2. Logging de Arranque
# ---------------------------------------------------------
logger.info("startup_db_config", 
            database_url=DATABASE_URL, 
            env=ENV,
            machine_id=os.getenv("FLY_MACHINE_ID", "local")
)

if "sqlite" in DATABASE_URL:
    try:
        path = DATABASE_URL.replace("sqlite:///", "").replace("sqlite:", "")
        # Fix absolute paths
        if DATABASE_URL.startswith("sqlite:////"): 
            path = "/" + DATABASE_URL.split("////")[-1]

        if os.path.exists(path):
            size_mb = os.path.getsize(path) / (1024 * 1024)
            logger.info("db_boot_found", path=path, size_mb=f"{size_mb:.2f} MB", exists=True)
        else:
            logger.info("db_boot_new", path=path, exists=False)
            
    except Exception as e:
        logger.error("db_boot_check_error", error=str(e))

# 3. Engine & Optimizaciones SQLite
# ---------------------------------------------------------
connect_args = {}
if "sqlite" in DATABASE_URL:
    connect_args = {
        "check_same_thread": False,
        "timeout": 30  # Default 5s es muy poco para concurrencia
    }

engine = create_engine(
    DATABASE_URL,
    connect_args=connect_args,
    future=True,
)

# Activar WAL mode para mejor concurrencia y optimizaciones robustas
if "sqlite" in DATABASE_URL:
    @event.listens_for(engine, "connect")
    def set_sqlite_pragma(dbapi_connection, connection_record):
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA journal_mode=WAL")
        cursor.execute("PRAGMA synchronous=NORMAL")
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.execute("PRAGMA busy_timeout=5000")
        cursor.execute("PRAGMA wal_autocheckpoint=1000")
        cursor.execute("PRAGMA temp_store=MEMORY")
        cursor.execute("PRAGMA cache_size=-20000")
        cursor.close()

    # Verificar de inmediato que aplican
    try:
        with engine.connect() as conn:
            fk = conn.execute(text("PRAGMA foreign_keys")).scalar()
            jm = conn.execute(text("PRAGMA journal_mode")).scalar()
            logger.info("db_pragmas_verified", foreign_keys=fk, journal_mode=jm)
    except Exception as e:
        logger.error("db_pragmas_verify_error", error=str(e))

SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False, future=True)
Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# Removed `ensure_user_columns(db_engine)` function as Alembic handles migrations.
