import os
from pathlib import Path
from typing import Any, Dict, Optional

from fastapi import APIRouter, Depends, UploadFile, File
from pydantic import BaseModel
from sqlalchemy.orm import Session

from ..deps import get_current_user
from ..database import get_db
from .. import models, schemas

router = APIRouter()

# ✅ Base del proyecto: .../app/routes/users.py -> sube 2 niveles a /app
BASE_DIR = Path(__file__).resolve().parent.parent  # .../app
# ✅ MEDIA_ROOT absoluto (puedes sobreescribir con env MEDIA_ROOT)
MEDIA_ROOT = Path(os.getenv("MEDIA_ROOT", str(BASE_DIR / "media"))).resolve()


@router.get("/me", response_model=schemas.UserOut)
def me(user: models.User = Depends(get_current_user)):
    photo_url = None
    if user.photo_path:
        photo_url = f"/media/{Path(user.photo_path).name}"

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
    # ✅ asegura carpeta
    MEDIA_ROOT.mkdir(parents=True, exist_ok=True)

    safe_name = file.filename.replace(" ", "_")
    filename = f"user_{user.id}_{safe_name}"
    dest_path = MEDIA_ROOT / filename

    # ✅ guardar archivo local
    content = file.file.read()
    with open(dest_path, "wb") as f:
        f.write(content)

    # ✅ guarda path en DB
    user.photo_path = str(dest_path)
    db.add(user)
    db.commit()
    db.refresh(user)

    return {"url": f"/media/{filename}"}


# =========================
# ✅ QUIZ ANSWERS (para que NO salga 404)
# =========================

class QuizAnswersIn(BaseModel):
    answers: Dict[str, Any]
    version: Optional[str] = None


@router.post("/me/quiz-answers")
def save_quiz_answers(
    payload: QuizAnswersIn,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    """
    Este endpoint existe para que Flutter no reciba 404.
    Si tu modelo User todavía NO tiene columnas para guardar quiz,
    igual regresa ok=True y luego lo conectamos a DB.
    """
    # Si YA tienes campos en tu modelo:
    if hasattr(user, "quiz_answers"):
        user.quiz_answers = payload.answers
        if hasattr(user, "quiz_version"):
            user.quiz_version = payload.version
        db.add(user)
        db.commit()
        db.refresh(user)

    return {"ok": True}
