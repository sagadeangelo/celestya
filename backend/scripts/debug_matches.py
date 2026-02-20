import sys
import os
import math
from datetime import date
from sqlalchemy import create_engine, or_, exists, and_
from sqlalchemy.orm import sessionmaker

# Add parent directory to path to import app
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app import models
from app.database import DATABASE_URL

def haversine_km(lat1, lon1, lat2, lon2):
    try:
        if lat1 is None or lon1 is None or lat2 is None or lon2 is None:
            return None
        R = 6371.0
        phi1 = math.radians(lat1)
        phi2 = math.radians(lat2)
        dphi = math.radians(lat2 - lat1)
        dlambda = math.radians(lon2 - lon1)
        a = math.sin(dphi/2.0)**2 + math.cos(phi1)*math.cos(phi2)*math.sin(dlambda/2.0)**2
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
        return R * c
    except:
        return None

def debug_suggested(email_filter=None):
    engine = create_engine(DATABASE_URL)
    SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    db = SessionLocal()

    # 1. Get Target User
    if email_filter:
        user = db.query(models.User).filter(models.User.email.ilike(f"%{email_filter}%")).first()
    else:
        user = db.query(models.User).first()

    if not user:
        print(f"User not found (filter: {email_filter})")
        return

    print(f"\nDEBUGGING MATCHES FOR: {user.email} (ID: {user.id})")
    print(f"   Gender: {user.gender}, ShowMe: {user.show_me}")
    print(f"   Location: {user.lat}, {user.lon}")
    print(f"   Email Verified: {user.email_verified}")

    # 2. Check Exclusions
    print("\n--- 1. EXCLUSIONS (DB State) ---")
    likes_given = db.query(models.Like).filter(models.Like.liker_id == user.id).count()
    passes_given = db.query(models.Pass).filter(models.Pass.passer_id == user.id).count()
    matches = db.query(models.Match).filter(or_(models.Match.user_a_id == user.id, models.Match.user_b_id == user.id)).count()
    
    print(f"   Likes Given: {likes_given}")
    print(f"   Passes Given: {passes_given}")
    print(f"   Confirmed Matches: {matches}")

    # 3. Step-by-Step Query Construction
    print("\n--- 2. FILTERING PIPELINE ---")
    
    # Base: All users except self
    q = db.query(models.User).filter(models.User.id != user.id)
    count_total = q.count()
    print(f"   Total other users in DB: {count_total}")

    # Exclude Blocked/Liked/Passed
    blocked_by_me = exists().where(and_(models.Block.blocker_id == user.id, models.Block.blocked_id == models.User.id))
    blocked_me = exists().where(and_(models.Block.blocker_id == models.User.id, models.Block.blocked_id == user.id))
    already_liked = exists().where(and_(models.Like.liker_id == user.id, models.Like.liked_id == models.User.id))
    already_passed = exists().where(and_(models.Pass.passer_id == user.id, models.Pass.passed_id == models.User.id))

    q_clean = q.filter(~blocked_by_me, ~blocked_me, ~already_liked, ~already_passed)
    count_clean = q_clean.count()
    print(f"   After excluding Liked/Passed/Blocked: {count_clean}")
    
    if count_clean == 0:
        print("   STOP: Everyone is liked/passed/blocked!")
        return

    # Email Verified
    REQUIRE_EMAIL_VERIFIED = os.getenv("REQUIRE_EMAIL_VERIFIED", "0") == "1"
    q_email = q_clean
    if REQUIRE_EMAIL_VERIFIED:
        q_email = q_clean.filter(models.User.email_verified == True)
    count_email = q_email.count()
    print(f"   After Email Verified (Required={REQUIRE_EMAIL_VERIFIED}): {count_email}")

    # Profile Photo
    REQUIRE_PROFILE_PHOTO = os.getenv("REQUIRE_PROFILE_PHOTO", "0") == "1"
    q_photo = q_email
    if REQUIRE_PROFILE_PHOTO:
        q_photo = q_email.filter(or_(models.User.profile_photo_key != None, models.User.photo_path != None))
    count_photo = q_photo.count()
    print(f"   After Photo Check (Required={REQUIRE_PROFILE_PHOTO}): {count_photo}")

    q_gender = q_photo
    if user.show_me and user.show_me != "everyone":
        q_gender = q_gender.filter(models.User.gender == user.show_me)
    count_gender = q_gender.count()
    print(f"   After Gender Filter (Looking for {user.show_me}): {count_gender}")

    q_recip = q_gender
    if user.gender:
        q_recip = q_recip.filter(or_(models.User.show_me == user.gender, models.User.show_me == None))
    count_recip = q_recip.count()
    print(f"   After Reciprocity (They must look for {user.gender}): {count_recip}")

    # 4. Final Candidates Analysis
    candidates = q_recip.limit(10).all()
    print(f"\n--- 3. SAMPLE CANDIDATES ({len(candidates)}) ---")
    for cand in candidates:
        dist = haversine_km(user.lat, user.lon, cand.lat, cand.lon)
        dist_str = f"{dist:.1f}km" if dist is not None else "Unknown dist"
        print(f"   - {cand.name} ({cand.email}) | {cand.gender} -> seeks {cand.show_me} | {dist_str}")

if __name__ == "__main__":
    email = sys.argv[1] if len(sys.argv) > 1 else None
    debug_suggested(email)
