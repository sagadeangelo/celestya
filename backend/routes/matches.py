from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from ..database import get_db
from ..deps import get_current_user
from .. import models

router = APIRouter()

@router.get("/suggested")
def suggested(db: Session = Depends(get_db), user: models.User = Depends(get_current_user)):
    # Demo: devuelve 0 resultados por ahora
    return {"matches": []}
