import os
import sys
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

# Activar WAL mode para mejor concurrencia
if "sqlite" in DATABASE_URL:
    @event.listens_for(engine, "connect")
    def set_sqlite_pragma(dbapi_connection, connection_record):
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA journal_mode=WAL")
        cursor.execute("PRAGMA synchronous=NORMAL")
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.close()

SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False, future=True)
Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def ensure_user_columns(db_engine):
    """
    Migración manual segura para SQLite y Postgres.
    Detecta columnas faltantes y las agrega con ALTER TABLE.
    """
    dialect = db_engine.dialect.name
    if dialect not in ["sqlite", "postgresql"]:
        return

    # Usar logger del módulo
    
    # Mapeo de tipos para el ALTER TABLE según el dialecto
    required_columns = [
        # Auth / Verificación
        ("email_verification_link_token", {"sqlite": "TEXT", "postgresql": "TEXT"}),
        ("email_verification_link_expires_at", {"sqlite": "DATETIME", "postgresql": "TIMESTAMP WITH TIME ZONE"}),
        ("email_verification_link_used", {"sqlite": "BOOLEAN DEFAULT 0", "postgresql": "BOOLEAN DEFAULT FALSE"}),
        ("email_verified", {"sqlite": "BOOLEAN DEFAULT 0", "postgresql": "BOOLEAN DEFAULT FALSE"}),
        ("email_verification_token_hash", {"sqlite": "TEXT", "postgresql": "TEXT"}),
        ("email_verification_expires_at", {"sqlite": "DATETIME", "postgresql": "TIMESTAMP WITH TIME ZONE"}),
        ("password_reset_token_hash", {"sqlite": "TEXT", "postgresql": "TEXT"}),
        ("password_reset_expires_at", {"sqlite": "DATETIME", "postgresql": "TIMESTAMP WITH TIME ZONE"}),
        
        # Perfil base
        ("name", {"sqlite": "TEXT", "postgresql": "TEXT"}),
        ("birthdate", {"sqlite": "DATE", "postgresql": "DATE"}),
        ("age_bucket", {"sqlite": "TEXT NOT NULL DEFAULT '18-25'", "postgresql": "TEXT NOT NULL DEFAULT '18-25'"}),
        ("gender", {"sqlite": "TEXT", "postgresql": "TEXT"}),
        ("show_me", {"sqlite": "TEXT", "postgresql": "TEXT"}),
        ("city", {"sqlite": "TEXT", "postgresql": "TEXT"}),
        ("stake", {"sqlite": "TEXT", "postgresql": "TEXT"}),
        ("lat", {"sqlite": "FLOAT", "postgresql": "DOUBLE PRECISION"}),
        ("lon", {"sqlite": "FLOAT", "postgresql": "DOUBLE PRECISION"}),
        ("bio", {"sqlite": "TEXT", "postgresql": "TEXT"}),
        ("height_cm", {"sqlite": "INTEGER", "postgresql": "INTEGER"}),
        ("education", {"sqlite": "TEXT", "postgresql": "TEXT"}),
        ("occupation", {"sqlite": "TEXT", "postgresql": "TEXT"}),
        
        # Perfil expandido
        ("marital_status", {"sqlite": "TEXT", "postgresql": "TEXT"}),
        ("has_children", {"sqlite": "BOOLEAN", "postgresql": "BOOLEAN"}),
        ("body_type", {"sqlite": "TEXT", "postgresql": "TEXT"}),
        ("mission_served", {"sqlite": "TEXT", "postgresql": "TEXT"}),
        ("mission_years", {"sqlite": "TEXT", "postgresql": "TEXT"}),
        ("favorite_calling", {"sqlite": "TEXT", "postgresql": "TEXT"}),
        ("favorite_scripture", {"sqlite": "TEXT", "postgresql": "TEXT"}),
        ("wants_adjacent_bucket", {"sqlite": "BOOLEAN DEFAULT 0", "postgresql": "BOOLEAN DEFAULT FALSE"}),
        
        # Fotos (JSON columns)
        ("photo_path", {"sqlite": "TEXT", "postgresql": "TEXT"}),
        ("profile_photo_key", {"sqlite": "TEXT", "postgresql": "TEXT"}),
        ("gallery_photo_keys", {"sqlite": "TEXT NOT NULL DEFAULT '[]'", "postgresql": "JSONB NOT NULL DEFAULT '[]'::jsonb"}),
        ("interests", {"sqlite": "TEXT NOT NULL DEFAULT '[]'", "postgresql": "JSONB NOT NULL DEFAULT '[]'::jsonb"}),
        ("gender", {"sqlite": "TEXT", "postgresql": "TEXT"}),
        ("name", {"sqlite": "TEXT", "postgresql": "TEXT"}),
        
        # Timestamps
        ("created_at", {"sqlite": "DATETIME", "postgresql": "TIMESTAMP WITH TIME ZONE"}),
        ("updated_at", {"sqlite": "DATETIME", "postgresql": "TIMESTAMP WITH TIME ZONE"}),
        ("last_seen", {"sqlite": "DATETIME", "postgresql": "TIMESTAMP WITH TIME ZONE"}),
    ]

    try:
        with db_engine.begin() as conn:
            # Detectar columnas existentes de forma agnóstica al dialecto
            if dialect == "sqlite":
                cursor = conn.execute(text("PRAGMA table_info(users)"))
                existing_columns = {row[1] for row in cursor.fetchall()}
            else: # postgresql
                query = text("SELECT column_name FROM information_schema.columns WHERE table_name = 'users'")
                cursor = conn.execute(query)
                existing_columns = {row[0] for row in cursor.fetchall()}
            
            if not existing_columns:
                logger.info("db_migration_skipped_table_missing", table="users", dialect=dialect)
                return

            logger.info("db_migration_check", table="users", dialect=dialect)
            added_any = False
            for col_name, types in required_columns:
                    if dialect == "sqlite":
                        try:
                            # SQLite doesn't support IF NOT EXISTS in ALTER TABLE reliably across versions
                            # We already checked existing_columns, so we can try to add it.
                            stmt = text(f"ALTER TABLE users ADD COLUMN {col_name} {types['sqlite']}")
                            conn.execute(stmt)
                            logger.info("db_migration_column_added", column=col_name, dialect=dialect)
                            added_any = True
                        except Exception as e:
                            # Ignore duplicate column errors if race condition
                            if "duplicate column" not in str(e).lower():
                                logger.error("db_migration_column_error", column=col_name, error=str(e))
                    else:
                        # Postgres
                        col_type = types.get("postgresql", "TEXT")
                        try:
                            stmt = text(f"ALTER TABLE users ADD COLUMN IF NOT EXISTS {col_name} {col_type}")
                            conn.execute(stmt)
                            logger.info("db_migration_column_added", column=col_name, dialect=dialect)
                            added_any = True
                        except Exception as e:
                            logger.error("db_migration_column_error", column=col_name, error=str(e))
            
            if not added_any:
                logger.info("db_migration_no_changes_needed", dialect=dialect)
            
            logger.info("db_migration_finished", dialect=dialect)
    except Exception as e:
        logger.critical("db_migration_critical_error", error=str(e))
