import os
from pathlib import Path
from typing import Any, Dict, Optional

from fastapi import APIRouter, Depends, UploadFile, File, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from ..deps import get_current_user
from ..database import get_db
from .. import models, schemas
from ..services.r2_client import presigned_get_url

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

    return {
        "id": user.id,
        "email": user.email,
        "name": display_name,
        "birthdate": user.birthdate,
        "email_verified": getattr(user, "email_verified", False),
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
    }


@router.get("/me", response_model=schemas.UserOut)
def me(user: models.User = Depends(get_current_user)):
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

    # 3. Borrar de DB
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
            print(f"[UPDATE] Set user.{field} = {value}")

    db.add(user)
    db.commit()
    db.refresh(user)
    return user_to_out(user)



# -------------------------
# (Legacy) subir foto local a /data/media
# -------------------------
@router.post("/me/photo", response_model=schemas.PhotoOut)
def upload_photo_local(
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
def set_photo_key(
    payload: schemas.PhotoKeyIn,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    key = (payload.profile_photo_key or "").strip()
    if not key:
        raise HTTPException(status_code=400, detail="profile_photo_key requerido")

    user.profile_photo_key = key
    db.add(user)
    db.commit()
    db.refresh(user)

    print(f"[PHOTO] Key guardada para user {user.id}: {user.profile_photo_key}")
    return {"ok": True, "profile_photo_key": user.profile_photo_key}


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
