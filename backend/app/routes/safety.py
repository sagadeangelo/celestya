from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional

from ..deps import get_current_user
from ..database import get_db
from .. import models

router = APIRouter(prefix="/reports", tags=["safety"])

class ReportIn(BaseModel):
    target_user_id: int
    reason: str
    details: Optional[str] = None

class BlockIn(BaseModel):
    target_user_id: int

@router.post("")
def report_user(
    payload: ReportIn,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user)
):
    # Verify target exists
    target = db.query(models.User).filter(models.User.id == payload.target_user_id).first()
    if not target:
        raise HTTPException(status_code=404, detail="Usuario a reportar no encontrado")

    new_report = models.Report(
        reporter_id=user.id,
        reported_id=payload.target_user_id,
        reason=payload.reason,
        details=payload.details
    )
    db.add(new_report)
    db.commit()
    
    return {"ok": True, "message": "Reporte recibido"}

@router.post("/block")
def block_user(
    payload: BlockIn,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user)
):
    # Check if already blocked
    existing = db.query(models.Block).filter(
        models.Block.blocker_id == user.id,
        models.Block.blocked_id == payload.target_user_id
    ).first()

    if existing:
        return {"ok": True, "message": "Usuario ya estaba bloqueado"}

    new_block = models.Block(
        blocker_id=user.id,
        blocked_id=payload.target_user_id
    )
    db.add(new_block)
    
    # Also delete any existing Match or Conversation?
    # Usually safer to just hide them, but deleting match ensures they don't see each other.
    # Let's delete the match if it exists.
    existing_match = db.query(models.Match).filter(
        ((models.Match.user_a_id == user.id) & (models.Match.user_b_id == payload.target_user_id)) |
        ((models.Match.user_a_id == payload.target_user_id) & (models.Match.user_b_id == user.id))
    ).first()
    
    if existing_match:
        db.delete(existing_match)

    db.commit()
    return {"ok": True, "message": "Usuario bloqueado"}
