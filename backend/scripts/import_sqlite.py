import os
import sqlite3
import shutil
import sys
import argparse
import structlog

# Configure logging
structlog.configure(
    processors=[
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.JSONRenderer()
    ],
    logger_factory=structlog.PrintLoggerFactory(),
)
logger = structlog.get_logger("import_sqlite")

DEST_DB_PATH = os.getenv("DB_PATH", "celestya.db")

def verify_integrity(db_path):
    """Runs PRAGMA integrity_check on the database."""
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute("PRAGMA integrity_check;")
        result = cursor.fetchone()
        conn.close()
        
        if result and result[0] == "ok":
            return True, "ok"
        else:
            return False, str(result)
    except Exception as e:
        return False, str(e)

def import_from_db(source_path):
    """Import by copying .db file and verifying."""
    logger.info("importing_binary", source=source_path, dest=DEST_DB_PATH)
    
    if os.path.exists(DEST_DB_PATH):
        logger.warning("overwrite_warning", dest=DEST_DB_PATH)
        # Backup existing just in case
        shutil.copy(DEST_DB_PATH, DEST_DB_PATH + ".bak")
        
    try:
        shutil.copy(source_path, DEST_DB_PATH)
        
        is_valid, msg = verify_integrity(DEST_DB_PATH)
        if is_valid:
            logger.info("import_success", integrity="ok")
            print(f"✅ Import successful to {DEST_DB_PATH}")
        else:
            logger.error("import_integrity_failed", detail=msg)
            print(f"❌ Import failed integrity check: {msg}")
            sys.exit(1)
            
    except Exception as e:
        logger.error("import_failed", error=str(e))
        sys.exit(1)

def import_from_sql(source_path):
    """Import by executing .sql script."""
    logger.info("importing_sql", source=source_path, dest=DEST_DB_PATH)
    
    if os.path.exists(DEST_DB_PATH):
        logger.warning("overwrite_warning_sql", dest=DEST_DB_PATH)
        os.remove(DEST_DB_PATH) # SQL dump creates from scratch usually
        
    try:
        conn = sqlite3.connect(DEST_DB_PATH)
        with open(source_path, 'r', encoding='utf-8') as f:
            sql_script = f.read()
            conn.executescript(sql_script)
        conn.close()
        
        is_valid, msg = verify_integrity(DEST_DB_PATH)
        if is_valid:
            logger.info("import_sql_success", integrity="ok")
            print(f"✅ SQL Import successful to {DEST_DB_PATH}")
        else:
            logger.error("import_integrity_failed", detail=msg)
            print(f"❌ SQL Import failed integrity check: {msg}")
            sys.exit(1)
            
    except Exception as e:
        logger.error("import_sql_failed", error=str(e))
        sys.exit(1)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Import SQLite Database")
    parser.add_argument("file", help="Path to .db or .sql file to import")
    parser.add_argument("--dest", help="Destination DB path", default=DEST_DB_PATH)
    
    args = parser.parse_args()
    
    input_file = args.file
    DEST_DB_PATH = args.dest
    
    if not os.path.exists(input_file):
        print(f"Error: File {input_file} not found")
        sys.exit(1)
        
    if input_file.endswith(".sql"):
        import_from_sql(input_file)
    else:
        # Assume binary .db or .sqlite
        import_from_db(input_file)
