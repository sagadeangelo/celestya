from fastapi import APIRouter, Depends, Request, HTTPException
from starlette import status
import os
import math
from datetime import date, datetime
from sqlalchemy.orm import Session
from sqlalchemy import or_
from ..database import get_db
from ..deps import get_current_user
from .. import models
from .users import user_to_out
import logging

logger = logging.getLogger("api")

router = APIRouter()


@router.get("/suggested")
def suggested(
    request: Request,
    max_distance_km: float | None = None,
    min_age: int | None = None,
    max_age: int | None = None,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    # PASO 3A: Gate de descubrimiento (Sincronizado con front)
    has_photo = bool(user.profile_photo_key or user.photo_path)
    has_gender = bool(user.gender and str(user.gender).strip())
    has_name = bool(user.name and user.name.lower() != "null")
    
    is_ready = has_photo and has_gender and has_name
    
    # Logs para depuración
    print(f"[GATE] user={user.id} photo={has_photo} gender={has_gender} name={has_name} READY={is_ready}")
    
    # Requisitos secundarios (no bloquean pero se loguean)
    has_height = user.height_cm is not None and user.height_cm > 0
    has_body = bool(user.body_type and str(user.body_type).strip())
    if not has_height or not has_body:
        print(f"[GATE-WARN] user={user.id} missing height/body but allowed.")

    if not is_ready:
        missing = []
        if not has_photo: missing.append("photo")
        if not has_gender: missing.append("gender")
        if not has_name: missing.append("name")

    # 1) IDs que yo bloqueé
    my_blocks = (
        db.query(models.Block.blocked_id)
        .filter(models.Block.blocker_id == user.id)
        .all()
    )
    blocked_ids = {b[0] for b in my_blocks}

    # 2) IDs que me bloquearon a mí
    blocked_by = (
        db.query(models.Block.blocker_id)
        .filter(models.Block.blocked_id == user.id)
        .all()
    )
    blocker_ids = {b[0] for b in blocked_by}

    # 3) IDs que ya di like
    my_likes = (
        db.query(models.Like.liked_id)
        .filter(models.Like.liker_id == user.id)
        .all()
    )
    liked_ids = {l[0] for l in my_likes}

    # 4) IDs que ya pasé/rechacé
    my_passes = (
        db.query(models.Pass.passed_id)
        .filter(models.Pass.passer_id == user.id)
        .all()
    )
    passed_ids = {p[0] for p in my_passes}

    # 5) Excluir: SOLO YO (para debugging/testing) + bloqueos si se desea
    # PROMPT 2: "Only hard requirements for now: not self... email_verified... has profile photo"
    # We will respect blocked_ids but usually for testing we might want to see them if re-seeded.
    # Let's keep the standard exclusions but log them.
    # exclude_ids = blocked_ids | blocker_ids | liked_ids | passed_ids | {user.id} 
    
    # RELAXED MODE: ignore history to ensure testers appear if re-seeded
    exclude_ids = {user.id} | blocked_ids | blocker_ids

    # 6) Base query
    q = db.query(models.User).filter(~models.User.id.in_(exclude_ids))

    count_start = q.count()
    logger.info(f"[SUGGESTED] Start count (excluding self/blocks): {count_start}")

    # Read toggles from env
    # USER PROMPT: "email_verified == 1" as hard requirement
    REQUIRE_EMAIL_VERIFIED = os.getenv("REQUIRE_EMAIL_VERIFIED", "1") == "1"
    REQUIRE_PROFILE_PHOTO = os.getenv("REQUIRE_PROFILE_PHOTO", "1") == "1"
    ALLOW_NO_PHOTO = os.getenv("ALLOW_NO_PHOTO", "0") == "1"
    ALLOW_INCOMPLETE_PROFILE = os.getenv("ALLOW_INCOMPLETE_PROFILE", "1") == "1"

    # Effective photo filter
    photo_filter_active = REQUIRE_PROFILE_PHOTO and not ALLOW_NO_PHOTO

    # Apply EMAIL check
    if REQUIRE_EMAIL_VERIFIED:
        q = q.filter(models.User.email_verified == True)
    
    count_email = q.count()
    logger.info(f"[SUGGESTED] After email_verified: {count_email}")

    # Apply PHOTO check
    if photo_filter_active:
        q = q.filter((models.User.profile_photo_key != None) | (models.User.photo_path != None))
    
    count_photo = q.count()
    logger.info(f"[SUGGESTED] After active photo check: {count_photo}")

    # 7) Gender & Reciprocity
    # Target: "candidate.gender == user.show_me" (when user.show_me exists)
    if getattr(user, "show_me", None):
        # Strict: match gender exactly
        q = q.filter(models.User.gender == user.show_me)
    
    count_gender = q.count()

    # Reciprocity: candidate.show_me == user.gender (or NULL/empty if allowed, but let's be strict for now)
    if getattr(user, "gender", None):
         q = q.filter(models.User.show_me == user.gender)
    
    count_reciprocity = q.count()
    logger.info(f"[SUGGESTED] After gender/recip: {count_gender} -> {count_reciprocity}")

    # 8) Age & Distance (Optional Params)
    # PROMPT 2: "If missing, do NOT filter. If present, apply safely... do NOT exclude null birthdate"
    today = date.today()

    # MIN AGE
    if min_age is not None:
        try:
            limit_date = today.replace(year=today.year - min_age)
            q = q.filter(or_(models.User.birthdate <= limit_date, models.User.birthdate == None))
        except:
            pass
    
    # MAX AGE
    if max_age is not None:
        try:
            limit_date = today.replace(year=today.year - max_age)
            q = q.filter(or_(models.User.birthdate >= limit_date, models.User.birthdate == None))
        except:
            pass

    # Fetch candidates for Python-side processing (Distance)
    candidates_raw = q.limit(100).all()
    logger.info(f"[SUGGESTED] Fetched for distance check: {len(candidates_raw)}")

    # Distance filter
    # PROMPT 2: "if either side missing lat/lon, do NOT exclude"
    
    def haversine_km(lat1, lon1, lat2, lon2):
        try:
            # all args in degrees
            R = 6371.0
            phi1 = math.radians(lat1)
            phi2 = math.radians(lat2)
            dphi = math.radians(lat2 - lat1)
            dlambda = math.radians(lon2 - lon1)
            a = math.sin(dphi/2.0)**2 + math.cos(phi1)*math.cos(phi2)*math.sin(dlambda/2.0)**2
            c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
            return R * c
        except:
            return 999999.0

    candidates = []
    for cand in candidates_raw:
        # LOGGING FOR DEBUG
        debug_reason = "kept"
        
        if max_distance_km is not None and user.lat is not None and user.lon is not None and cand.lat is not None and cand.lon is not None:
            try:
                dkm = haversine_km(user.lat, user.lon, cand.lat, cand.lon)
                if dkm is not None and dkm > float(max_distance_km):
                    debug_reason = f"distance {dkm}km > {max_distance_km}km"
                    logger.info(f"[DEBUG] Dropping user {cand.id}: {debug_reason}")
                    continue
            except Exception as e:
                logger.error(f"[DEBUG] Distance calc error: {e}")
                pass
                
        # Age extra check: if candidate has birthdate and min/max provided, verify
        if cand.birthdate is not None:
            cand_age = None
            try:
                cand_age = (date.today().year - cand.birthdate.year - ((date.today().month, date.today().day) < (cand.birthdate.month, cand.birthdate.day)))
            except Exception:
                cand_age = None
            
            # NOTE: We relaxed SQL filters earlier, but this python check might still be strict?
            # Let's ensure we respect ALLOW_INCOMPLETE_PROFILE here too if needed, but usually SQL filter handles it.
            # However, if SQL let it through (e.g. because birthdate was NULL), this block won't run (cand.birthdate is None).
            # If birthdate is NOT None, we must respect the age limits if set.
            
            if min_age is not None and cand_age is not None and cand_age < min_age:
                debug_reason = f"age {cand_age} < min {min_age}"
                logger.info(f"[DEBUG] Dropping user {cand.id}: {debug_reason}")
                continue
            if max_age is not None and cand_age is not None and cand_age > max_age:
                debug_reason = f"age {cand_age} > max {max_age}"
                logger.info(f"[DEBUG] Dropping user {cand.id}: {debug_reason}")
                continue
                
        if debug_reason == "kept":
             logger.info(f"[DEBUG] Keeping user {cand.id} ({cand.name})")
             
        candidates.append(cand)

    # Trim to 20
    candidates = candidates[:20]
    final_count = len(candidates)
    
    logger.info(f"[SUGGESTED] Final candidates returned: {final_count}")

    # Montar respuesta y modo debug por header
    resp = {"matches": [user_to_out(c) for c in candidates]}

    # FORCE DEBUG ALWAYS for diagnosis
    # debug_flag = False
    # if request is not None:
    #     try:
    #         debug_flag = str(request.headers.get("X-Debug", "0")) == "1"
    #     except Exception:
    #         debug_flag = False
    debug_flag = True

    # DEBUG: Inspect DB from inside the running process
    # import os (removed to fix UnboundLocalError)
    db_url = os.getenv("DATABASE_URL", "sqlite:///./celestya.db")
    db_abspath = os.path.abspath("celestya.db")
    
    # Dump 5 users to see if they exist
    debug_users = []
    try:
        all_u = db.query(models.User).limit(5).all()
        for u in all_u:
            debug_users.append(f"{u.id}:{u.name}:{u.gender}:{u.show_me}:{u.birthdate}")
    except Exception as e:
        debug_users = [str(e)]

    if debug_flag:
        resp["debug"] = {
            "deployment_check": "VERSION_FORCED_DEBUG_TIMESTAMP_NOW",
            "total_users": total_users_db if 'total_users_db' in locals() else -999,
            "db_path_guess": db_abspath,
            "db_url_env": db_url,
            "db_users_sample": debug_users,
            "user_info": {
                "id": user.id,
                "email": user.email,
                "gender": user.gender,
                "show_me": user.show_me,
                "lat": user.lat,
                "lon": user.lon,
            },
            # ... existing debug fields ...
            "final_count": final_count,
            "toggles": {
                "REQUIRE_EMAIL_VERIFIED": REQUIRE_EMAIL_VERIFIED,
                "REQUIRE_PROFILE_PHOTO": REQUIRE_PROFILE_PHOTO,
                "ALLOW_NO_PHOTO": ALLOW_NO_PHOTO,
                "photo_filter_active": photo_filter_active,
                "ALLOW_INCOMPLETE_PROFILE": ALLOW_INCOMPLETE_PROFILE,
            },
            "requested_filters": {"min_age": min_age, "max_age": max_age, "max_distance_km": max_distance_km},
        }

    # Log step counts for observability
    try:
        total_users_db = db.query(models.User).count()
    except:
        total_users_db = -1

    logger.info(
        "[SUGGESTED-STEPS] total_db=%s start(excl_self)=%s email_ok=%s photo_ok=%s gender_recip_ok=%s final=%s",
        total_users_db,
        count_start,
        count_email,
        count_photo,
        count_reciprocity,
        final_count,
    )

    # If no candidates, guess most likely reason and log
    if final_count == 0:
        probable = "unknown"
        if count_start == 0:
            probable = "no candidates after exclusions (blocked/liked/passed/self)"
        elif count_email == 0:
            probable = "no verified users (check REQUIRE_EMAIL_VERIFIED)"
        elif count_photo == 0:
            probable = "no users with photos (check REQUIRE_PROFILE_PHOTO)"
        elif count_reciprocity == 0:
            probable = "gender reciprocity filtered all candidates"
        logger.info(f"[SUGGESTED] No candidates returned — probable: {probable}")

    return resp


@router.get("/suggested_debug", response_model=None)
def suggested_debug(
    request: Request,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
    min_age: int | None = None,
    max_age: int | None = None,
    max_distance_km: float | None = None,
):
    """
    Debug endpoint that explains why candidates are included/excluded.
    Enabled only when ENABLE_SUGGESTED_DEBUG=1 and header X-Debug-Key matches DEBUG_KEY.
    Returns step_counts, applied_filters, final_candidates_sample and server_info.
    """
    enabled = os.getenv("ENABLE_SUGGESTED_DEBUG", "0") == "1"
    debug_key = os.getenv("DEBUG_KEY", "")
    header_key = None
    if request is not None:
        header_key = request.headers.get("X-Debug-Key")

    if not enabled or not debug_key or header_key != debug_key:
        # Hide endpoint when not allowed
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)

    # Step counts
    total_users = db.query(models.User).count()
    verified = db.query(models.User).filter(models.User.email_verified == True).count()
    with_gender = db.query(models.User).filter(models.User.gender != None).filter(models.User.gender != "").count()
    with_show_me = db.query(models.User).filter(models.User.show_me != None).filter(models.User.show_me != "").count()
    with_photo = db.query(models.User).filter((models.User.profile_photo_key != None) | (models.User.photo_path != None)).count()
    with_latlon = db.query(models.User).filter(models.User.lat != None).filter(models.User.lon != None).count()

    step_counts = {
        "total_users": total_users,
        "verified": verified,
        "with_gender": with_gender,
        "with_show_me": with_show_me,
        "with_photo": with_photo,
        "with_latlon": with_latlon,
    }

    # Re-create filters applied by /suggested
    # Exclusions
    my_blocks = db.query(models.Block.blocked_id).filter(models.Block.blocker_id == user.id).all()
    blocked_ids = {b[0] for b in my_blocks}
    blocked_by = db.query(models.Block.blocker_id).filter(models.Block.blocked_id == user.id).all()
    blocker_ids = {b[0] for b in blocked_by}
    my_likes = db.query(models.Like.liked_id).filter(models.Like.liker_id == user.id).all()
    liked_ids = {l[0] for l in my_likes}
    my_passes = db.query(models.Pass.passed_id).filter(models.Pass.passer_id == user.id).all()
    passed_ids = {p[0] for p in my_passes}
    exclude_ids = blocked_ids | blocker_ids | liked_ids | passed_ids | {user.id}

    applied_filters = []
    applied_filters.append({"exclusions": True, "details": "exclude self, blocked, blocked_by, liked, passed", "exclude_count": len(exclude_ids)})

    # Read toggles
    REQUIRE_EMAIL_VERIFIED = os.getenv("REQUIRE_EMAIL_VERIFIED", "1") == "1"
    REQUIRE_PROFILE_PHOTO = os.getenv("REQUIRE_PROFILE_PHOTO", "1") == "1"
    ALLOW_INCOMPLETE_PROFILE = os.getenv("ALLOW_INCOMPLETE_PROFILE", "1") == "1"

    gender_pref_applied = bool(getattr(user, "gender", None) and getattr(user, "show_me", None))
    applied_filters.append({"gender_preference": gender_pref_applied})

    # Reciprocity mode
    applied_filters.append({"reciprocity_relaxed": ALLOW_INCOMPLETE_PROFILE})

    applied_filters.append({"requires_email_verified": REQUIRE_EMAIL_VERIFIED})
    applied_filters.append({"requires_photo": REQUIRE_PROFILE_PHOTO})

    applied_filters.append({"age_filters": {"min_age": min_age, "max_age": max_age}})
    applied_filters.append({"distance_filter_km": max_distance_km})

    # Final candidates sample (up to 5)
    q = db.query(models.User).filter(~models.User.id.in_(exclude_ids))

    # Apply toggles for debug sample/counts
    if REQUIRE_EMAIL_VERIFIED:
        q = q.filter(models.User.email_verified == True)
    if REQUIRE_PROFILE_PHOTO:
        q = q.filter((models.User.profile_photo_key != None) | (models.User.photo_path != None))

    if gender_pref_applied:
        q = q.filter(models.User.gender == user.show_me)
        if ALLOW_INCOMPLETE_PROFILE:
            q = q.filter(
                or_(
                    models.User.show_me == None,
                    models.User.show_me == "",
                    models.User.show_me == user.gender,
                )
            )
        else:
            q = q.filter(models.User.show_me == user.gender)

    # Age SQL filter counts if provided
    age_sql_q = q
    if min_age is not None:
        try:
            today = date.today()
            min_bd = today.replace(year=today.year - min_age)
            age_sql_q = age_sql_q.filter(models.User.birthdate <= min_bd)
        except Exception:
            pass
    if max_age is not None:
        try:
            today = date.today()
            max_bd = today.replace(year=today.year - max_age)
            age_sql_q = age_sql_q.filter(models.User.birthdate >= max_bd)
        except Exception:
            pass

    sample = q.limit(5).all()
    final_candidates_sample = []
    for u in sample:
        final_candidates_sample.append({
            "id": u.id,
            "email": u.email,
            "gender": u.gender,
            "show_me": u.show_me,
            "age_bucket": getattr(u, "age_bucket", None),
            "city": u.city,
            "has_photo": bool(u.profile_photo_key or u.photo_path),
            "has_latlon": (u.lat is not None and u.lon is not None),
        })

    # Extra counts reflecting toggles
    base_count = db.query(models.User).filter(~models.User.id.in_(exclude_ids)).count()
    count_email_ok = db.query(models.User).filter(~models.User.id.in_(exclude_ids)).filter(models.User.email_verified == True).count()
    count_photo_ok = db.query(models.User).filter(~models.User.id.in_(exclude_ids)).filter((models.User.profile_photo_key != None) | (models.User.photo_path != None)).count()
    count_gender_ok = db.query(models.User).filter(~models.User.id.in_(exclude_ids)).filter(models.User.gender != None).filter(models.User.gender != "").count()
    count_showme_ok = db.query(models.User).filter(~models.User.id.in_(exclude_ids)).filter(models.User.show_me != None).filter(models.User.show_me != "").count()

    # Age SQL count
    try:
        age_sql_count = age_sql_q.count() if (min_age is not None or max_age is not None) else None
    except Exception:
        age_sql_count = None

    # Distance count (only where both lat/lon present)
    distance_ok = None
    if max_distance_km is not None:
        # iterate base users (could be heavy; debug only)
        distance_ok = 0
        users_iter = db.query(models.User).filter(~models.User.id.in_(exclude_ids)).all()
        for uu in users_iter:
            if uu.lat is not None and uu.lon is not None and user.lat is not None and user.lon is not None:
                dkm = None
                try:
                    # reuse haversine code
                    phi1 = math.radians(user.lat)
                    phi2 = math.radians(uu.lat)
                    dphi = math.radians(uu.lat - user.lat)
                    dlambda = math.radians(uu.lon - user.lon)
                    a = math.sin(dphi/2.0)**2 + math.cos(phi1)*math.cos(phi2)*math.sin(dlambda/2.0)**2
                    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
                    dkm = 6371.0 * c
                except Exception:
                    dkm = None
                if dkm is not None and dkm <= float(max_distance_km):
                    distance_ok += 1

    # Server info
    server_info = {"app_version": None}
    try:
        # Try to read FastAPI app version if available
        from ..main import app as _app
        server_info["app_version"] = getattr(_app, "version", None)
    except Exception:
        server_info["app_version"] = None

    try:
        from ..database import DATABASE_URL
        if str(DATABASE_URL).startswith("sqlite"):
            # expose path only (no secrets)
            sqlite_path = str(DATABASE_URL).replace("sqlite:", "")
            server_info["db"] = {"dialect": "sqlite", "path": sqlite_path}
        else:
            server_info["db"] = {"dialect": str(DATABASE_URL).split(":")[0]}
    except Exception:
        server_info["db"] = {"dialect": None}

    return {
        "step_counts": step_counts,
        "applied_filters": applied_filters,
        "final_candidates_sample": final_candidates_sample,
        "counts": {
            "base_count": base_count,
            "count_email_ok": count_email_ok,
            "count_photo_ok": count_photo_ok,
            "count_gender_ok": count_gender_ok,
            "count_showme_ok": count_showme_ok,
            "age_sql_count": age_sql_count,
            "distance_ok_count": distance_ok,
        },
        "server_info": server_info,
    }


@router.get("/confirmed")
def get_confirmed_matches(db: Session = Depends(get_db), user: models.User = Depends(get_current_user)):
    """
    Returns list of users with whom the current user has a confirmed match (mutual likelihood/match).
    In this system, a 'Match' row exists in 'matches' table.
    """
    matches_a = db.query(models.Match).filter(models.Match.user_a_id == user.id).all()
    matches_b = db.query(models.Match).filter(models.Match.user_b_id == user.id).all()

    confirmed_users = []

    for m in matches_a:
        confirmed_users.append(m.user_b)

    for m in matches_b:
        confirmed_users.append(m.user_a)

    return [user_to_out(u) for u in confirmed_users]


@router.post("/like/{user_id}")
def like_user(
    user_id: int,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user)
):
    """
    Like a user. If mutual, create a Match.
    """
    from fastapi import HTTPException
    
    if user_id == user.id:
        raise HTTPException(status_code=400, detail="Cannot like yourself")
    
    # Check if target user exists
    target = db.query(models.User).filter(models.User.id == user_id).first()
    if not target:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Check if already liked
    existing = db.query(models.Like).filter(
        models.Like.liker_id == user.id,
        models.Like.liked_id == user_id
    ).first()
    
    if existing:
        return {"ok": True, "matched": False, "message": "Already liked"}
    
    # Create like
    like = models.Like(liker_id=user.id, liked_id=user_id)
    db.add(like)
    
    # Check for mutual like
    mutual = db.query(models.Like).filter(
        models.Like.liker_id == user_id,
        models.Like.liked_id == user.id
    ).first()
    
    matched = False
    if mutual:
        # Create match (ensure user_a_id < user_b_id to avoid duplicates)
        a, b = sorted([user.id, user_id])
        
        # Check if match already exists
        existing_match = db.query(models.Match).filter(
            models.Match.user_a_id == a,
            models.Match.user_b_id == b
        ).first()
        
        if not existing_match:
            match = models.Match(user_a_id=a, user_b_id=b)
            db.add(match)
            matched = True
            print(f"[MATCH] Created match between {user.id} and {user_id}")
    
    db.commit()
    return {"ok": True, "matched": matched}


@router.post("/pass/{user_id}")
def pass_user(
    user_id: int,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user)
):
    """
    Pass/reject a user. They won't appear in suggested matches again.
    """
    from fastapi import HTTPException
    
    if user_id == user.id:
        raise HTTPException(status_code=400, detail="Cannot pass yourself")
    
    # Check if already passed
    existing = db.query(models.Pass).filter(
        models.Pass.passer_id == user.id,
        models.Pass.passed_id == user_id
    ).first()
    
    if existing:
        return {"ok": True, "message": "Already passed"}
    
    # Create pass
    pass_record = models.Pass(passer_id=user.id, passed_id=user_id)
    db.add(pass_record)
    db.commit()
    
    return {"ok": True}
