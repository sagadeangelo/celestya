import sys
from pathlib import Path

# Add backend directory to path so we can import app modules
backend_dir = Path(__file__).resolve().parent
sys.path.append(str(backend_dir))

from app.database import Base, engine
from app import models  # Ensure models are imported so they are registered in Base.metadata

def create_tables():
    print("Creating tables...")
    # This will check for all tables defined in models and create them if they verify don't exist
    # It does NOT update existing tables (no ALTER), but perfect for adding new tables.
    Base.metadata.create_all(bind=engine)
    print("Tables created successfully.")

if __name__ == "__main__":
    create_tables()
