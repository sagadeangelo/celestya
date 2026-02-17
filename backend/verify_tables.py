from sqlalchemy import create_engine, inspect

# Point to root database
DATABASE_URL = "sqlite:///../celestya.db"
engine = create_engine(DATABASE_URL)

inspector = inspect(engine)
tables = inspector.get_table_names()
print(f"Tables in DB: {tables}")
