import os
from pathlib import Path
from typing import Any, Dict, Optional

from fastapi import APIRouter, Depends, UploadFile, File, HTTPException, Request
from pydantic import BaseModel
from sqlalchemy.orm import Session

from ..deps import get_current_user
from ..database import get_db
from .. import models, schemas
from ..services.r2_client import presigned_get_url, check_object_exists
from ..limiter import limiter, LIMIT_PHOTO
import structlog

logger = structlog.get_logger("api")

router = APIRouter()

# Base del proyecto: .../app/routes/users.py -> sube 2 niveles a /app
BASE_DIR = Path(__file__).resolve().parent.parent  # .../app

# MEDIA_ROOT absoluto (persistente si apuntas a /data/media)
MEDIA_ROOT = Path(os.getenv("MEDIA_ROOT", str(BASE_DIR / "media"))).resolve()


# -------------------------
# /users/me
# -------------------------
def user_to_out(user: models.User) -> dict:
    """Helper para centralizar la generación de UserOut con URLs firmadas."""
    photo_url = None
    # Prioridad 1: R2 (profile_photo_key)
    if user.profile_photo_key:
        photo_url = presigned_get_url(user.profile_photo_key)
    # Prioridad 2: Legacy (photo_path)
    elif user.photo_path:
        photo_url = f"/media/{Path(user.photo_path).name}"

    # Sanitización de nombre centralizada
    from ..utils import clean_name
    display_name = clean_name(user.name)

    # Generar URLs firmadas para galería
    photo_urls = []
    if user.gallery_photo_keys:
        for key in user.gallery_photo_keys:
            if key and isinstance(key, str):
                photo_urls.append(presigned_get_url(key))

    # Online logic
    is_online = False
    if user.last_seen:
        from ..security import utcnow
        from datetime import timedelta, timezone
        
        last_seen_aware = user.last_seen
        if last_seen_aware.tzinfo is None:
            last_seen_aware = last_seen_aware.replace(tzinfo=timezone.utc)

        # 5 minutes threshold
        if (utcnow() - last_seen_aware) < timedelta(minutes=5):
            is_online = True

    # Voice Intro
    exists = bool(user.voice_intro_key)
    url = presigned_get_url(user.voice_intro_key, expires_seconds=3600) if exists else None
    
    return {
        "id": user.id,
        "email": user.email,
        "name": display_name,
        "birthdate": user.birthdate,
        "email_verified": getattr(user, "email_verified", False),
        "is_online": is_online,
        "last_seen": user.last_seen,
        "city": user.city,
        "stake": user.stake,
        "lat": user.lat,
        "lon": user.lon,
        "bio": user.bio,
        "photo_url": photo_url,
        "photo_urls": photo_urls,
        "profile_photo_key": user.profile_photo_key,
        "gallery_photo_keys": user.gallery_photo_keys or [],
        
        # Campos perdidos añadidos aquí
        "gender": user.gender,
        "height_cm": user.height_cm,
        "body_type": user.body_type,
        "marital_status": user.marital_status,
        "has_children": user.has_children,
        "education": user.education,
        "occupation": user.occupation,
        "interests": user.interests or [],
        
        "mission_served": user.mission_served,
        "mission_years": user.mission_years,
        "favorite_calling": user.favorite_calling,
        "favorite_scripture": user.favorite_scripture,
        "verification_status": user.verification_status,
        "rejection_reason": getattr(user.verifications[-1], "rejection_reason", None) if user.verifications and user.verification_status == "rejected" else None,
        "active_instruction": getattr(user.verifications[-1], "instruction", None) if user.verifications and user.verification_status == "pending_upload" else None,
        
        # Voice Intro (Fixed)
        "voice_intro_exists": exists,
        "voice_intro_url": url,
        "language": user.language,
    }


def repair_voice_intro_if_missing(user: models.User, db: Session):
    """
    Prompt D: Reparación automática para usuarios que ya subieron audio pero no quedó en DB.
    """
    if user.voice_intro_key:
        return

    # Extensiones comunes a probar
    extensions = ["m4a", "mp3", "aac", "mp4", "wav", "webm"]
    for ext in extensions:
        key = f"users/{user.id}/voice_intro.{ext}"
        if check_object_exists(key):
            try:
                user.voice_intro_key = key
                db.add(user)
                db.commit()
                logger.info("repair_triggered", user_id=user.id, found_ext=ext, key=key)
            except Exception as e:
                db.rollback()
                logger.error("repair_failed", user_id=user.id, error=str(e))
            break


@router.get("/me", response_model=schemas.UserOut)
def me(
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user)
):
    # Prompt D: Reparación automática al consultar perfil propio
    repair_voice_intro_if_missing(user, db)
    
    exists = bool(user.voice_intro_key)
    logger.info("profile_requested", user_id=user.id, voice_intro_exists=exists)
    
    return user_to_out(user)


@router.delete("/me")
def delete_me(
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user)
):
    """
    Elimina la cuenta del usuario actual y sus datos relacionados.
    CASCADE en la DB se encarga de user_compat.
    """
    # 1. Borrar de R2 si existe (principal)
    if user.profile_photo_key:
        try:
            from ..services.r2_client import delete_object
            delete_object(user.profile_photo_key)
        except Exception:
            # Silently fail R2 deletion to ensure user account is deleted regardless
            pass

    # 2. Borrar de disco local (Legacy) si existe
    if user.photo_path:
        try:
            p = Path(user.photo_path)
            if p.exists():
                p.unlink()
        except Exception:
            pass

    # 3. Borrar dependencias manualmente para evitar IntegrityError (Foreign Keys strict)
    # Como NO tenemos ON DELETE CASCADE en la DB schema (SQLite), y no todos los modelos
    # tienen cascade="all,delete-orphan" en SQLAlchemy hacia User, debemos limpiar a mano.

    # 3.1 Conversaciones (Trigger cascade a Mensajes via SQLAlchemy)
    # Debemos borrarlas una por una para que SQLAlchemy active el cascade de Messages
    conversations = db.query(models.Conversation).filter(
        (models.Conversation.user_a_id == user.id) | 
        (models.Conversation.user_b_id == user.id)
    ).all()
    for c in conversations:
        db.delete(c)
    
    # 3.2 Matches
    db.query(models.Match).filter(
        (models.Match.user_a_id == user.id) | 
        (models.Match.user_b_id == user.id)
    ).delete(synchronize_session=False)

    # 3.3 Likes
    db.query(models.Like).filter(
        (models.Like.liker_id == user.id) | 
        (models.Like.liked_id == user.id)
    ).delete(synchronize_session=False)

    # 3.4 Passes
    db.query(models.Pass).filter(
        (models.Pass.passer_id == user.id) | 
        (models.Pass.passed_id == user.id)
    ).delete(synchronize_session=False)

    # 3.5 Blocks
    db.query(models.Block).filter(
        (models.Block.blocker_id == user.id) | 
        (models.Block.blocked_id == user.id)
    ).delete(synchronize_session=False)
    
    # 3.6 Reports
    db.query(models.Report).filter(
        (models.Report.reporter_id == user.id) | 
        (models.Report.reported_id == user.id)
    ).delete(synchronize_session=False)

    # 4. Borrar usuario (Cascades: RefreshToken, UserCompat)
    db.delete(user)
    db.commit()
    return {"ok": True}


@router.put("/me", response_model=schemas.UserOut)
def update_me(
    payload: schemas.UserUpdate,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    """
    Actualiza el perfil del usuario utilizando un dump parcial (exclude_unset=True).
    """
    update_data = payload.model_dump(exclude_unset=True)

    # Campos especiales que requieren lógica adicional
    if "birthdate" in update_data:
        from .auth import _calc_age, _bucket
        birthdate = update_data["birthdate"]
        user.birthdate = birthdate
        age = _calc_age(birthdate)
        user.age_bucket = _bucket(age)
        del update_data["birthdate"]

    # Mapeo dinámico de TODOS los campos presentes en el payload
    for field, value in update_data.items():
        if hasattr(user, field):
            if field == "name":
                from ..utils import clean_name
                value = clean_name(value)
            setattr(user, field, value)
            logger.info("user_update_field", field=field, value=value, user_id=user.id)

    db.add(user)
    db.commit()
    db.refresh(user)
    return user_to_out(user)


@router.patch("/me/language")
def update_language(
    payload: schemas.LanguageUpdateIn,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    lang = payload.language.lower()
    if lang not in ["es", "en"]:
        raise HTTPException(status_code=422, detail={"detail": "Invalid language", "code": "INVALID_LANGUAGE"})
    
    user.language = lang
    db.add(user)
    db.commit()
    
    return {"ok": True, "language": lang}


# -------------------------
# (Legacy) subir foto local a /data/media
# -------------------------
@router.post("/me/photo", response_model=schemas.PhotoOut)
@limiter.limit(LIMIT_PHOTO)
def upload_photo_local(
    request: Request,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    MEDIA_ROOT.mkdir(parents=True, exist_ok=True)

    safe_name = (file.filename or "photo").replace(" ", "_")
    filename = f"user_{user.id}_{safe_name}"
    dest_path = MEDIA_ROOT / filename

    content = file.file.read()
    with open(dest_path, "wb") as f:
        f.write(content)

    user.photo_path = str(dest_path)
    db.add(user)
    db.commit()
    db.refresh(user)

    return {"url": f"/media/{filename}"}


# =========================
# ✅ QUIZ ANSWERS (R2 no aplica, esto va a DB)
# =========================
class QuizAnswersIn(BaseModel):
    answers: Dict[str, Any]
    version: Optional[str] = None


@router.post("/me/quiz-answers", response_model=schemas.QuizAnswersOut)
def save_quiz_answers(
    payload: QuizAnswersIn,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    """
    Guarda respuestas en user_compat (1 registro por usuario).
    Requiere que exista el modelo UserCompat y la relación user.compat.
    """
    # Asegura que exista compat
    compat = getattr(user, "compat", None)
    if compat is None:
        compat = models.UserCompat(user_id=user.id, answers={})
        db.add(compat)
        db.commit()
        db.refresh(compat)

    compat.answers = payload.answers or {}
    # Si luego agregas columna version en UserCompat, aquí la seteas
    if hasattr(compat, "version"):
        compat.version = payload.version

    db.add(compat)
    db.commit()
    db.refresh(compat)

    return {"user_id": user.id, "answers": compat.answers or {}, "version": payload.version}


@router.get("/me/quiz-answers", response_model=schemas.QuizAnswersOut)
def get_quiz_answers(
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    compat = getattr(user, "compat", None)
    if compat is None:
        return {"user_id": user.id, "answers": {}, "version": None}

    return {"user_id": user.id, "answers": compat.answers or {}, "version": None}


# ✅ Opción B (R2): guardar profile_photo_key en DB
@router.put("/me/photo-key", response_model=schemas.PhotoKeyOut)
@limiter.limit(LIMIT_PHOTO)
def set_photo_key(
    request: Request,
    payload: schemas.PhotoKeyIn,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    key = (payload.profile_photo_key or "").strip()
    if not key:
        raise HTTPException(status_code=400, detail="profile_photo_key requerido")

    _validate_photo_ownership(key, user.id)

    user.profile_photo_key = key
    db.add(user)
    db.commit()
    db.refresh(user)

    logger.info("photo_key_saved", user_id=user.id, key=user.profile_photo_key)
    return {"ok": True, "profile_photo_key": user.profile_photo_key}


def _validate_photo_ownership(key: str, user_id: int):
    """
    Validates that the key belongs to the user.
    New format: uploads/user_{id}_{uuid}.ext
    Legacy format: uploads/{uuid}.ext (Allowed for backward compatibility, but less secure)
    """
    if key.startswith("uploads/user_"):
        expected_prefix = f"uploads/user_{user_id}_"
        if not key.startswith(expected_prefix):
            raise HTTPException(status_code=403, detail="You do not own this photo")
    elif key.startswith("uploads/"):
        # Legacy key, allow for now
        pass
    else:
        # Unknown format (e.g. external URL?), failing safe for now if we strictly want R2 keys
        # If we allow external URLs, remove this else block.
        # Assuming we only want our R2 keys:
        pass 


# ✅ Obtener URL firmada para la foto principal
@router.get("/me/photo-url", response_model=schemas.PhotoUrlOut)
def get_my_photo_url(user: models.User = Depends(get_current_user), expires: int = 900):
    key = user.profile_photo_key
    if not key:
        return {"ok": True, "url": None, "profile_photo_key": None, "expires": expires}

    url = presigned_get_url(key=key, expires_seconds=expires)
    return {"ok": True, "profile_photo_key": key, "url": url, "expires": expires}


# --- GALLERY ENDPOINTS ---

@router.post("/me/gallery", response_model=schemas.UserOut)
def add_gallery_photo(
    payload: schemas.PhotoKeyIn, 
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user)
):
    key = payload.profile_photo_key.strip() # Reusamos el esquema que tiene 'profile_photo_key'
    if not key:
        raise HTTPException(status_code=400, detail="Key vacía")
    
    _validate_photo_ownership(key, user.id)

    gallery = list(user.gallery_photo_keys or [])
    if key in gallery:
        return user # Ya existe
    
    if len(gallery) >= 6:
        raise HTTPException(status_code=400, detail="Máximo 6 fotos en galería")
    
    gallery.append(key)
    user.gallery_photo_keys = gallery
    db.add(user)
    db.commit()
    db.refresh(user)
    return user_to_out(user)

@router.delete("/me/gallery", response_model=schemas.UserOut)
def remove_gallery_photo(
    key: str, 
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user)
):
    gallery = list(user.gallery_photo_keys or [])
    if key in gallery:
        gallery.remove(key)
        user.gallery_photo_keys = gallery
        db.add(user)
        db.commit()
        db.refresh(user)
    
    return user_to_out(user)
