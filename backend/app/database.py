import os
import logging
from sqlalchemy import create_engine, text
from sqlalchemy.orm import declarative_base, sessionmaker

def _get_default_db_url():
    # En Fly.io, usamos /data/celestya.db si existe
    if os.path.exists("/data"):
        return "sqlite:////data/celestya.db"
    return "sqlite:///./celestya.db"

DATABASE_URL = os.getenv("DATABASE_URL", _get_default_db_url()).strip()

connect_args = {}
if DATABASE_URL.startswith("sqlite"):
    connect_args = {"check_same_thread": False}

engine = create_engine(
    DATABASE_URL,
    connect_args=connect_args,
    future=True,
)

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

    logger = logging.getLogger("api")
    
    # Mapeo de tipos para el ALTER TABLE según el dialecto
    required_columns = [
        # Auth / Verificación
        ("email_verification_link_token", {"sqlite": "TEXT", "postgresql": "TEXT"}),
        ("email_verification_link_expires_at", {"sqlite": "DATETIME", "postgresql": "TIMESTAMP WITH TIME ZONE"}),
        ("email_verification_link_used", {"sqlite": "BOOLEAN DEFAULT 0", "postgresql": "BOOLEAN DEFAULT FALSE"}),
        ("email_verified", {"sqlite": "BOOLEAN DEFAULT 0", "postgresql": "BOOLEAN DEFAULT FALSE"}),
        ("email_verification_token_hash", {"sqlite": "TEXT", "postgresql": "TEXT"}),
        ("email_verification_expires_at", {"sqlite": "DATETIME", "postgresql": "TIMESTAMP WITH TIME ZONE"}),
        
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
                print(f"[DB] La tabla 'users' no existe todavía en {dialect}.")
                return

            print(f"[DB] ({dialect}) Comprobando columnas en 'users'...")
            added_any = False
            for col_name, types in required_columns:
                if col_name not in existing_columns:
                    col_type = types.get(dialect, types.get("sqlite"))
                    try:
                        conn.execute(text(f"ALTER TABLE users ADD COLUMN {col_name} {col_type}"))
                        print(f"[DB] Columna '{col_name}' añadida con éxito.")
                        logger.info(f"Columna '{col_name}' añadida a tabla 'users' ({dialect}).")
                        added_any = True
                    except Exception as e:
                        print(f"[DB] Error al añadir {col_name}: {e}")
            
            if not added_any:
                print(f"[DB] Todas las columnas ya existen en {dialect}.")
            
            print(f"[DB] Migración finalizada para {dialect}.")
    except Exception as e:
        print(f"[DB] Error crítico en migración: {e}")
        logger.error(f"Error crítico en ensure_user_columns: {e}")
