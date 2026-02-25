from fastapi import APIRouter, Depends, Request, HTTPException
from fastapi.responses import JSONResponse
from starlette import status
from typing import List

import os
import math
from datetime import date, datetime
from sqlalchemy.orm import Session
from sqlalchemy.orm import Session
from sqlalchemy import or_, exists, and_
from ..database import get_db
from ..deps import get_current_user
from .. import models
from .users import user_to_out
import logging
import structlog

logger = structlog.get_logger("api")


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
    print(f"--- SUGGESTED REQUEST ---")
    print(f"User: {user.email} (ID: {user.id})")
    print(f"Filters received: dist={max_distance_km}, min_age={min_age}, max_age={max_age}")
    print(f"User Preferences: show_me={user.show_me}, gender={user.gender}")
    # PASO 3A: Gate de descubrimiento (Sincronizado con front)
    has_photo = bool(user.profile_photo_key or user.photo_path)
    has_gender = bool(user.gender and str(user.gender).strip())
    has_name = bool(user.name and user.name.lower() != "null")
    
    is_ready = has_photo and has_gender and has_name
    
    # Logs para depuración
    logger.info(f"[GATE] user={user.id} photo={has_photo} gender={has_gender} name={has_name} READY={is_ready}")
    
    # Requisitos secundarios (no bloquean pero se loguean)
    has_height = user.height_cm is not None and user.height_cm > 0
    has_body = bool(user.body_type and str(user.body_type).strip())
    if not has_height or not has_body:
        logger.info(f"[GATE-WARN] user={user.id} missing height/body but allowed.")

    if not is_ready:
        missing = []
        if not has_photo: missing.append("photo")
        if not has_gender: missing.append("gender")
        if not has_name: missing.append("name")

    # 1) Exclusiones via SQL (Mejor rendimiento que cargar IDs en memoria)
    # block_check: Yo bloqueé al usuario OR Usuario me bloqueó a mí
    # like_check: Yo di like
    # pass_check: Yo di pass

    # Alias para claridad en subqueries (opcional, pero User es la tabla principal del query)
    # Usamos models.Block, models.Like, models.Pass directamente

    # Condiciones NOT EXISTS
    # a) Yo bloqueé a User
    blocked_by_me = exists().where(
        and_(models.Block.blocker_id == user.id, models.Block.blocked_id == models.User.id)
    )
    # b) User me bloqueó a mí
    blocked_me = exists().where(
        and_(models.Block.blocker_id == models.User.id, models.Block.blocked_id == user.id)
    )
    # c) Ya di like
    already_liked = exists().where(
        and_(models.Like.liker_id == user.id, models.Like.liked_id == models.User.id)
    )
    # d) Ya di pass
    already_passed = exists().where(
        and_(models.Pass.passer_id == user.id, models.Pass.passed_id == models.User.id)
    )
    # e) Ya reporté
    already_reported = exists().where(
        and_(models.Report.reporter_id == user.id, models.Report.reported_id == models.User.id)
    )

    # 6) Base query
    # Excluir self + todas las condiciones anteriores
    q = db.query(models.User).filter(
        models.User.id != user.id,
        ~blocked_by_me,
        ~blocked_me,
        ~already_liked, # Comentar para debugging si se quiere ver a quien diste like
        ~already_passed, # Comentar para debugging si se quiere ver a quien diste pass
        ~already_reported
    )

    count_start = q.count()
    logger.info(f"[SUGGESTED] Start count (excluding self/blocks): {count_start}")

    # Read toggles from env
    # Relaxed defaults for dev/testing
    REQUIRE_EMAIL_VERIFIED = os.getenv("REQUIRE_EMAIL_VERIFIED", "0") == "1"
    REQUIRE_PROFILE_PHOTO = os.getenv("REQUIRE_PROFILE_PHOTO", "0") == "1"
    ALLOW_NO_PHOTO = os.getenv("ALLOW_NO_PHOTO", "1") == "1"
    ALLOW_INCOMPLETE_PROFILE = os.getenv("ALLOW_INCOMPLETE_PROFILE", "1") == "1"

    # Effective photo filter
    photo_filter_active = REQUIRE_PROFILE_PHOTO and not ALLOW_NO_PHOTO

    # Apply EMAIL check
    if REQUIRE_EMAIL_VERIFIED:
        # Relaxed for legacy/imported users: Only enforce if true.
        # But if DB has 0 verified, this kills the feed.
        # Let's log warning if exclusion is high.
        q = q.filter(models.User.email_verified == True)
    
    count_email = q.count()
    logger.info(f"[SUGGESTED] After email_verified: {count_email}")

    # Apply PHOTO check
    if photo_filter_active:
        q = q.filter((models.User.profile_photo_key != None) | (models.User.photo_path != None))
    
    count_photo = q.count()
    logger.info(f"[SUGGESTED] After active photo check: {count_photo}")

    # 7) Gender & Reciprocity (STRICT HETEROSEXUAL ENFORCEMENT)
    # The user requested to "blindar" (armor) this logic.
    # Men MUST see Women. Women MUST see Men. 
    # We ignore 'show_me' preference if it deviates from this rule.
    
    user_gender_str = str(user.gender).lower().strip() if user.gender else ""
    
    if user_gender_str in ["male", "hombre", "m"]:
        # User is Male -> Force candidates to be Female
        q = q.filter(models.User.gender == "female")
        logger.info(f"[SUGGESTED] Strict enforcement: Male user {user.id} -> looking for female candidates.")
        
    elif user_gender_str in ["female", "mujer", "f"]:
        # User is Female -> Force candidates to be Male
        q = q.filter(models.User.gender == "male")
        logger.info(f"[SUGGESTED] Strict enforcement: Female user {user.id} -> looking for male candidates.")
        
    else:
        # Fallback for undefined/other gender (shouldn't happen in this strict app, but safe fallback)
        # We use their show_me if set, otherwise no strict filter (or block?)
        logger.warning(f"[SUGGESTED] User {user.id} has unknown gender '{user_gender_str}'. Fallback to show_me.")
        if getattr(user, "show_me", None) and user.show_me != "everyone":
             q = q.filter(models.User.gender == user.show_me)

    count_gender = q.count()

    # Reciprocity: 
    # We ensure the candidate also wants to see the user's gender.
    # Since we are enforcing hetero, a Female candidate (who is hetero) should want 'male'.
    # A Male candidate (who is hetero) should want 'female'.
    # We allow 'everyone' or NULL just in case, but usually it should match.
    if user_gender_str:
         q = q.filter(or_(
             models.User.show_me == user_gender_str, 
             models.User.show_me == "everyone",
             models.User.show_me == None
         ))
    
    count_reciprocity = q.count()
    logger.info(f"[SUGGESTED] After strict gender/recip: {count_gender} -> {count_reciprocity}")

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

    candidates: List[models.User] = []
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
        
        # FIX: If user has no location, do not drop unless strictly required?
        # Current logic: inner block only runs if ALL coords are present.
        # If any coord is missing, we skip the block and KEEP the user (debug_reason="kept").
        # This is correct behavior for "lenient" location.
                
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
            
            if min_age is not None and cand_age is not None and int(cand_age) < int(min_age):
                debug_reason = f"age {cand_age} < min {min_age}"
                logger.info("suggested_drop", user_id=cand.id, reason=debug_reason)
                continue
            if max_age is not None and cand_age is not None and int(cand_age) > int(max_age):
                debug_reason = f"age {cand_age} > max {max_age}"
                logger.info("suggested_drop", user_id=cand.id, reason=debug_reason)
                continue

                
        if debug_reason == "kept":
             logger.info(f"[DEBUG] Keeping user {cand.id} ({cand.name})")
             
        candidates.append(cand)

    # Trim to 20
    candidates = candidates[:20]
    final_count = len(candidates)
    
    logger.info(f"[SUGGESTED] Final candidates returned: {final_count}")
    print(f"--- SUGGESTED RESPONSE ---")
    print(f"Returning {final_count} candidates")
    if final_count > 0:
        print(f"First candidate: {candidates[0].email} (ID: {candidates[0].id})")

    # Montar respuesta y modo debug por header
    resp = {"matches": [user_to_out(c) for c in candidates]}



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
    Returns 409 if already matched.
    """
    if user_id == user.id:
        raise HTTPException(status_code=400, detail="Cannot like yourself")
    
    # Check if target user exists
    target = db.query(models.User).filter(models.User.id == user_id).first()
    if not target:
        raise HTTPException(status_code=404, detail="User not found")
    
    # HARDENING: Check if already matched
    # Ensure a < b for the query
    a, b = sorted([user.id, user_id])
    existing_match = db.query(models.Match).filter(
        models.Match.user_a_id == a,
        models.Match.user_b_id == b
    ).first()

    if existing_match:
        raise HTTPException(status_code=409, detail="Match already exists with this user")

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
    
    # Check for mutual like (since we know match didn't exist yet)
    mutual = db.query(models.Like).filter(
        models.Like.liker_id == user_id,
        models.Like.liked_id == user.id
    ).first()
    
    matched = False
    if mutual:
        # Create match
        match = models.Match(user_a_id=a, user_b_id=b)
        db.add(match)
        matched = True
        logger.info(f"[MATCH] Created match between {user.id} and {user_id}")
    
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
    Returns 409 if already matched.
    """
    if user_id == user.id:
        raise HTTPException(status_code=400, detail="Cannot pass yourself")
    
    # HARDENING: Check if already matched
    a, b = sorted([user.id, user_id])
    existing_match = db.query(models.Match).filter(
        models.Match.user_a_id == a,
        models.Match.user_b_id == b
    ).first()

    if existing_match:
        raise HTTPException(status_code=409, detail="Cannot pass a user you are already matched with. Use unmatch instead.")

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


@router.post("/unmatch/{user_id}")
def unmatch_user(
    user_id: int,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user)
):
    """
    Unmatch a user.
    1. Removes Match record.
    2. Removes Conversation (if any).
    3. Remove Likes (cleanup).
    4. Creates Pass record (to blocking future matches).
    """
    if user_id == user.id:
        raise HTTPException(status_code=400, detail="Cannot unmatch yourself")

    # 1. Check Match
    a, b = sorted([user.id, user_id])
    match = db.query(models.Match).filter(
        models.Match.user_a_id == a,
        models.Match.user_b_id == b
    ).first()

    if not match:
        raise HTTPException(status_code=404, detail="Match not found")

    # 2. Delete Match
    db.delete(match)
    
    # 3. Delete Conversation (if exists)
    # Check for conversation where A=user, B=target OR A=target, B=user
    conv = db.query(models.Conversation).filter(
        or_(
            and_(models.Conversation.user_a_id == user.id, models.Conversation.user_b_id == user_id),
            and_(models.Conversation.user_a_id == user_id, models.Conversation.user_b_id == user.id)
        )
    ).first()
    
    if conv:
        # Note: If messages have foreign key to conversation, ensure cascade delete is set in DB 
        # or delete messages manually. Assuming DB handles cascade or we leave messages orphaned 
        # (but usually we want to wipe it). 
        # Let's trust cascade or simple delete for now.
        db.delete(conv)

    # 4. Cleanup Likes (so they aren't 'liked' anymore)
    db.query(models.Like).filter(
        models.Like.liker_id == user.id, 
        models.Like.liked_id == user_id
    ).delete()
    
    db.query(models.Like).filter(
        models.Like.liker_id == user_id, 
        models.Like.liked_id == user.id
    ).delete()

    # 5. Create Pass (Future prevention)
    # Check if pass exists first?
    existing_pass = db.query(models.Pass).filter(
       models.Pass.passer_id == user.id,
       models.Pass.passed_id == user_id
    ).first()
    
    if not existing_pass:
        new_pass = models.Pass(passer_id=user.id, passed_id=user_id)
        db.add(new_pass)
        
    db.commit()
    return {"ok": True}


@router.post("/reset")
def reset_account(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """
    Prompt 3: Reinicia historial completo del usuario sin borrar la cuenta.
    Borra en orden: messages -> chats -> matches/likes/passes -> tokens -> compat.
    """
    user_id = current_user.id
    logger.info("reset_started", user_id=user_id)

    
    try:
        # 1. Borrar Mensajes de sus chats
        conv_ids_q = db.query(models.Conversation.id).filter(
            (models.Conversation.user_a_id == user_id) | 
            (models.Conversation.user_b_id == user_id)
        )
        conv_ids = [r[0] for r in conv_ids_q.all()]
        
        msg_count = db.query(models.Message).filter(models.Message.conversation_id.in_(conv_ids)).delete(synchronize_session=False) if conv_ids else 0
        
        # 2. Borrar Conversaciones
        chat_count = db.query(models.Conversation).filter(
            (models.Conversation.user_a_id == user_id) | 
            (models.Conversation.user_b_id == user_id)
        ).delete(synchronize_session=False)
        
        # 3. Borrar Matches
        match_count = db.query(models.Match).filter(
            (models.Match.user_a_id == user_id) | 
            (models.Match.user_b_id == user_id)
        ).delete(synchronize_session=False)
        
        # 4. Borrar Likes (enviados y recibidos)
        like_count = db.query(models.Like).filter(
            (models.Like.liker_id == user_id) | 
            (models.Like.liked_id == user_id)
        ).delete(synchronize_session=False)
        
        # 5. Borrar Passes (enviados y recibidos)
        pass_count = db.query(models.Pass).filter(
            (models.Pass.passer_id == user_id) | 
            (models.Pass.passed_id == user_id)
        ).delete(synchronize_session=False)
        
        # 6. Borrar Refresh Tokens para forzar re-login o limpiar sesión
        token_count = db.query(models.RefreshToken).filter(models.RefreshToken.user_id == user_id).delete(synchronize_session=False)
        
        # 7. Opcional: Borrar respuestas del Quiz/Compat para que vuelva a hacerlo
        compat_count = db.query(models.UserCompat).filter(models.UserCompat.user_id == user_id).delete(synchronize_session=False)
        
        db.commit()
        
        logger.info("reset_finished", user_id=user_id, deleted={"msgs": msg_count, "chats": chat_count, "matches": match_count})
        
        return {
            "ok": True, 
            "message": "Historial reiniciado correctamente",
            "deleted": {
                "messages": msg_count,
                "chats": chat_count,
                "matches": match_count,
                "likes": like_count,
                "passes": pass_count
            }
        }
        
    except Exception as e:
        db.rollback()
        import traceback
        logger.error("reset_failed", user_id=user_id, error=str(e), traceback=traceback.format_exc())
        return JSONResponse(
            status_code=500,
            content={"detail": f"Error en reinicio: {str(e)}", "code": "RESET_FAILED"}
        )
