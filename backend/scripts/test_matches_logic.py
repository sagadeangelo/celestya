import sys
import os
import logging

# Ensure we can import app
sys.path.append("/app")

from sqlalchemy.orm import Session
from app.database import SessionLocal, engine
from app import models
from app.routes import matches
from app.deps import get_current_user
from datetime import date

# Setup logging to see Matches logic
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("api")
logger.setLevel(logging.INFO)

def run_test():
    print("--- TESTING MATCHES LOGIC DIRECTLY ---")
    db = SessionLocal()
    
    # 1. Get or Create a Test User (Male seeking Female)
    email = "debug_male_verifier@test.com"
    user = db.query(models.User).filter(models.User.email == email).first()
    
    if not user:
        print(f"Creating test user: {email}")
        user = models.User(
            email=email,
            password_hash="dummy",
            name="Debug Male",
            gender="male",
            show_me="female",
            birthdate=date(1990, 1, 1),
            age_bucket="B_26_45",
            email_verified=True,
            profile_photo_key="dummy_key",
            lat=28.7136, # Piedras Negras
            lon=-100.5205,
             # Required non-nulls
            wants_adjacent_bucket=0,
            interests=[],
            gallery_photo_keys=[],
            email_verification_link_used=0
        )
        db.add(user)
        db.commit()
        db.refresh(user)
    else:
        print(f"Using existing user: {user.email} (ID: {user.id})")
        # Ensure correct settings
        user.gender = "male"
        user.show_me = "female"
        user.lat = 28.7136
        user.lon = -100.5205
        db.commit()

    print(f"User Profile: Gender={user.gender}, ShowMe={user.show_me}, Lat={user.lat}, Lon={user.lon}")

    # 2. Call suggested()
    print("\nCalling matches.suggested()...")
    try:
        # Mock request? suggested() takes request, max_distance_km, etc.
        # request is used for headers (X-Debug). We can pass None or mock.
        # But wait, suggested() logic uses `request` for debug flag check.
        # In my recent edit I forced debug_flag=True, so None is fine.
        
        # We need to manually set env vars if they aren't already
        # os.environ["ALLOW_INCOMPLETE_PROFILE"] = "1" 
        # (They should be set in the container environment)

        resp = matches.suggested(
            request=None,
            max_distance_km=None, # Global
            min_age=18,
            max_age=99,
            db=db,
            user=user
        )
        
        candidates = resp.get("matches", [])
        debug_info = resp.get("debug", {})
        
        print(f"\nRESULT: Found {len(candidates)} candidates.")
        
        if len(candidates) > 0:
            print("First 3 candidates:")
            for c in candidates[:3]:
                print(f" - {c.name} ({c.gender}) ID: {c.id}")
        else:
            print("NO CANDIDATES FOUND.")
            print("Debug Info Summary:")
            print(f"  Final Count: {debug_info.get('final_count')}")
            print(f"  Step Counts: {debug_info.get('db_users_sample')}") 
            # Note: db_users_sample is a list of strings, not a dict of counts.
            # I should inspect log output for the counts.
            
    except Exception as e:
        print(f"CRASH in suggested(): {e}")
        import traceback
        traceback.print_exc()

    db.close()
    print("--- TEST MATCHES END ---")

if __name__ == "__main__":
    run_test()
