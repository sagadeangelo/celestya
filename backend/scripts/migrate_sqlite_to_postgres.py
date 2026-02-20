import os
import sys
import structlog
from sqlalchemy import create_engine, inspect, MetaData, Table, select
from sqlalchemy.orm import sessionmaker
import argparse
import json

# Configure Logging
structlog.configure(
    processors=[structlog.processors.TimeStamper(fmt="iso"), structlog.processors.JSONRenderer()],
    logger_factory=structlog.PrintLoggerFactory(),
)
logger = structlog.get_logger("migrator")

def migrate(sqlite_path, postgres_url):
    logger.info("migration_start", sqlite=sqlite_path, postgres=postgres_url)
    
    # 1. Connect to SQLite (Source)
    if not os.path.exists(sqlite_path):
        logger.error("source_not_found", path=sqlite_path)
        sys.exit(1)
        
    sqlite_engine = create_engine(f"sqlite:///{sqlite_path}")
    source_metadata = MetaData()
    source_metadata.reflect(bind=sqlite_engine)
    
    # 2. Connect to Postgres (Dest)
    pg_engine = create_engine(postgres_url)
    dest_metadata = MetaData()
    dest_metadata.reflect(bind=pg_engine)
    
    # 3. Define Migration Order (Dependencies first)
    # Users first, then things that reference users
    TABLE_ORDER = [
        "users",
        "matches",
        "chats",
        "messages",
        "blocks",
        "reports",
        # Add others if needed
    ]
    
    with pg_engine.connect() as pg_conn:
        for table_name in TABLE_ORDER:
            if table_name not in source_metadata.tables:
                logger.warning("table_skipped_not_in_source", table=table_name)
                continue
                
            if table_name not in dest_metadata.tables:
                logger.warning("table_skipped_not_in_dest", table=table_name)
                continue

            logger.info("migrating_table", table=table_name)
            
            source_table = source_metadata.tables[table_name]
            dest_table = dest_metadata.tables[table_name]
            
            # Read from Source
            with sqlite_engine.connect() as sqlite_conn:
                rows = sqlite_conn.execute(select(source_table)).fetchall()
                
            if not rows:
                logger.info("table_empty", table=table_name)
                continue
                
            # Prepare Batch Insert
            data_to_insert = []
            for row in rows:
                row_dict = dict(row._mapping)
                
                # DATA TRANSFORMATION
                # -------------------
                # 1. Boolean normalization (SQLite 0/1 -> Postgres True/False handles automatically usually, but check)
                # 2. JSON fields (Text in SQLite -> JSONB in PG)
                #    If you use SQLAlchemy types correctly in models, drivers handle this.
                #    But raw reflection might treat them as generic.
                
                # Example: If 'interests' is stored as string '["a"]' in SQLite, PG JSONB driver might expect dict/list
                for key, val in row_dict.items():
                    if key in ["interests", "gallery_photo_keys", "photo_urls"] and isinstance(val, str):
                        try:
                            # Try parsing JSON if valid
                            if val.strip().startswith("[") or val.strip().startswith("{"):
                                row_dict[key] = json.loads(val)
                        except:
                            pass # Leave as string if fail
                            
                data_to_insert.append(row_dict)
                
            # Insert into Dest
            try:
                # Use chunks for large tables
                CHUNK_SIZE = 1000
                for i in range(0, len(data_to_insert), CHUNK_SIZE):
                    chunk = data_to_insert[i:i+CHUNK_SIZE]
                    pg_conn.execute(
                        dest_table.insert(),
                        chunk
                    )
                    pg_conn.commit()
                    
                # Reset Sequence for serial/autoincrement if implicit (Postgres uses sequences)
                # Since we inserted IDs, we must update the sequence to max(id)
                # (Skipping automatic sequence reset logic here, assume manual or UUIDs)
                
                logger.info("table_migrated", table=table_name, rows=len(data_to_insert))
                
            except Exception as e:
                logger.error("table_migration_failed", table=table_name, error=str(e))
                # Optional: Continue or Exit?
                # sys.exit(1) 

    logger.info("migration_complete")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--sqlite", required=True, help="Path to source SQLite .db")
    parser.add_argument("--postgres", required=True, help="Postgres Connection URL")
    args = parser.parse_args()
    
    migrate(args.sqlite, args.postgres)
