import sys
import os

# Add parent directory to path to import app modules
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import create_engine, inspect
from app.database import DATABASE_URL

def verify_schema():
    print(f"Connecting to database: {DATABASE_URL}")
    engine = create_engine(DATABASE_URL)
    inspector = inspect(engine)
    
    columns = inspector.get_columns('users')
    column_names = [c['name'] for c in columns]
    
    required_columns = ['password_reset_token_hash', 'password_reset_expires_at']
    missing_columns = [col for col in required_columns if col not in column_names]
    
    if missing_columns:
        print(f"❌ Missing columns in 'users' table: {missing_columns}")
        sys.exit(1)
    else:
        print("✅ Schema verification successful: All required columns exist.")

if __name__ == "__main__":
    verify_schema()
