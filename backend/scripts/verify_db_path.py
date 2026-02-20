import os
import sys

def verify_path():
    print("--- Database Persistence Verification ---")
    
    env = os.getenv("ENV", "unknown")
    db_url = os.getenv("DATABASE_URL", "")
    
    print(f"ENV: {env}")
    print(f"DATABASE_URL: {db_url}")
    
    expected_path = "/data/celestya.db"
    
    if env == "production":
        if "sqlite" in db_url and expected_path in db_url:
            print("✅ PASS: DATABASE_URL points to /data/celestya.db")
        else:
            print(f"❌ FAIL: DATABASE_URL should be sqlite:////data/celestya.db, got {db_url}")
            sys.exit(1)
            
        if os.path.exists("/data"):
             print("✅ PASS: /data volume exists")
        else:
             print("❌ FAIL: /data volume NOT FOUND")
             sys.exit(1)
             
        if os.path.exists(expected_path):
             size = os.path.getsize(expected_path) / (1024*1024)
             print(f"✅ PASS: DB file exists ({size:.2f} MB)")
        else:
             print("⚠️ WARN: DB file not found yet (will be created on startup)")
             
    else:
        print("ℹ️ INFO: Not running in production mode. Checks relaxed.")

if __name__ == "__main__":
    verify_path()
