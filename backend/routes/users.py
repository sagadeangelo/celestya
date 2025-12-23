import os
from fastapi import APIRouter, Depends, UploadFile, File, HTTPException
from sqlalchemy.orm import Session
from ..deps import get_current_user
from ..database import get_db
from .. import models, schemas

MEDIA_ROOT = os.getenv("MEDIA_ROOT", "./media")

router = APIRouter()

@router.get("/me", response_model=schemas.UserOut)
def me(user: models.User = Depends(get_current_user)):
    photo_url = None
    if user.photo_path:
        photo_url = f"/media/{os.path.basename(user.photo_path)}"
    return {
        "id": user.id,
        "email": user.email,
        "city": user.city,
        "stake": user.stake,
        "lat": user.lat,
        "lon": user.lon,
        "bio": user.bio,
        "photo_url": photo_url,
    }

@router.post("/me/photo", response_model=schemas.PhotoOut)
def upload_photo(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    os.makedirs(MEDIA_ROOT, exist_ok=True)
    filename = f"user_{user.id}_{file.filename.replace(' ', '_')}"
    dest = os.path.join(MEDIA_ROOT, filename)
    with open(dest, "wb") as f:
        f.write(file.file.read())

    user.photo_path = dest
    db.add(user)
    db.commit()

    return {"url": f"/media/{filename}"}
