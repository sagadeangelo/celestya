from datetime import date as d
from fastapi import APIRouter, Depends, HTTPException, Form
from sqlalchemy.orm import Session
from ..database import get_db
from .. import models, schemas
from ..security import hash_password, verify_password, create_access_token
from ..enums import AgeBucket

router = APIRouter()

def _calc_age(birth: d) -> int:
    t = d.today()
    return t.year - birth.year - ((t.month, t.day) < (birth.month, birth.day))

def _bucket(age: int) -> AgeBucket:
    if 18 <= age <= 25: return AgeBucket.A_18_25
    if 26 <= age <= 45: return AgeBucket.B_26_45
    return AgeBucket.C_45_75_PLUS

@router.post("/register", response_model=schemas.Token)
def register(payload: schemas.UserCreate, db: Session = Depends(get_db)):
    if db.query(models.User).filter(models.User.email == payload.email).first():
        raise HTTPException(status_code=400, detail="Email ya registrado")
    age = _calc_age(payload.birthdate)
    if age < 18:
        raise HTTPException(status_code=400, detail="Debes tener 18 años o más")

    user = models.User(
        email=payload.email,
        password_hash=hash_password(payload.password),
        birthdate=payload.birthdate,
        age_bucket=_bucket(age),
        city=payload.city, stake=payload.stake,
        lat=payload.lat, lon=payload.lon,
        bio=payload.bio, wants_adjacent_bucket=payload.wants_adjacent_bucket,
    )
    db.add(user)
    db.commit()
    return {"access_token": create_access_token(user.id)}

@router.post("/login", response_model=schemas.Token)
def login(username: str = Form(...), password: str = Form(...), db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.email == username).first()
    if not user or not verify_password(password, user.password_hash):
        raise HTTPException(status_code=400, detail="Credenciales inválidas")
    return {"access_token": create_access_token(user.id)}
