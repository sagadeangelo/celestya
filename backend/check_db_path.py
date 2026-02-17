from app.database import DATABASE_URL
import os

print(f"DATABASE_URL: {DATABASE_URL}")
if str(DATABASE_URL).startswith("sqlite"):
    path = str(DATABASE_URL).replace("sqlite:///", "")
    print(f"Checking path: {path}")
    print(f"Exists: {os.path.exists(path)}")
    print(f"Absolute path: {os.path.abspath(path)}")
