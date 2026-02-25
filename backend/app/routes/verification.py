import random
import structlog
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from sqlalchemy.orm import Session
from sqlalchemy import desc

from ..database import get_db
from ..models import User, UserVerification
from ..schemas import VerificationRequestOut, VerificationMeOut
from ..deps import get_current_user
from ..services.r2_client import upload_fileobj
import os

router = APIRouter()
logger = structlog.get_logger("verification")

INSTRUCTIONS = [
    "Sostén un Libro de Mormón y mira a la cámara",
    "Levanta tu mano derecha",
    "Inclina tu cabeza hacia la izquierda",
    "Sonríe mostrando dientes",
    "Toca tu nariz"
]

@router.post("/request", response_model=VerificationRequestOut)
def request_verification(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user)
):
    """
    Inicia o recupera una solicitud de verificación.
    """
    latest = db.query(UserVerification).filter(
        UserVerification.user_id == user.id
    ).order_by(desc(UserVerification.id)).first()

    if latest:
        # Reutilizar si ya está en proceso
        if latest.status in ["pending_upload", "pending_review"]:
            logger.info("request_reuse_active", user_id=user.id, status=latest.status)
            return {
                "verificationId": latest.id,
                "instruction": latest.instruction,
                "status": latest.status,
                "attempt": latest.attempt
            }
        
        # Bloquear si ya está aprobado
        if latest.status == "approved":
            logger.info("request_already_approved", user_id=user.id)
            raise HTTPException(
                status_code=409, 
                detail={"detail": "Ya estás verificado", "code": "ALREADY_VERIFIED"}
            )
        
        # Cooldown si fue rechazado (5 min)
        if latest.status == "rejected" and latest.reviewed_at:
            import datetime
            now = datetime.datetime.now(datetime.timezone.utc)
            # Asegurar que reviewed_at tenga timezone o comparar naive
            # Asumimos que DB guarda UTC sin tz si no se especifica
            diff = now.replace(tzinfo=None) - latest.reviewed_at.replace(tzinfo=None)
            if diff.total_seconds() < 300:
                logger.warning("request_cooldown_active", user_id=user.id)
                raise HTTPException(
                    status_code=429,
                    detail={"detail": "Por favor espera 5 minutos tras el rechazo.", "code": "COOLDOWN_ACTIVE"}
                )

    # Crear nueva solicitud
    attempt = (latest.attempt + 1) if (latest and latest.status == "rejected") else 1
    instruction = random.choice(INSTRUCTIONS)
    
    new_request = UserVerification(
        user_id=user.id,
        instruction=instruction,
        status="pending_upload",
        attempt=attempt
    )
    
    db.add(new_request)
    db.commit()
    db.refresh(new_request)
    
    logger.info("request_created", user_id=user.id, verification_id=new_request.id, attempt=attempt)
    
    return {
        "verificationId": new_request.id,
        "instruction": new_request.instruction,
        "status": new_request.status,
        "attempt": new_request.attempt
    }

@router.post("/upload")
async def upload_verification(
    verification_id: int = Form(..., alias="verification_id"),
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user)
):
    """
    Sube la imagen de verificación a R2.
    """
    # Validar solicitud
    verification = db.query(UserVerification).filter(
        UserVerification.id == verification_id,
        UserVerification.user_id == user.id
    ).first()
    
    if not verification:
        raise HTTPException(status_code=404, detail={"detail": "Solicitud no encontrada", "code": "NOT_FOUND"})
    
    if verification.status == "pending_review":
        raise HTTPException(status_code=409, detail={"detail": "La imagen ya fue subida", "code": "ALREADY_UPLOADED"})

    if verification.status != "pending_upload":
        raise HTTPException(
            status_code=400, 
            detail={"detail": f"Estado inválido: {verification.status}", "code": "INVALID_STATE"}
        )

    # Key determinística: verifications/{user_id}/{verification_id}.jpg
    key = f"verifications/{user.id}/{verification.id}.jpg"
    
    try:
        upload_fileobj(file.file, key=key, content_type="image/jpeg")
        
        verification.image_key = key
        verification.status = "pending_review"
        db.commit()
        
        logger.info("upload_success", user_id=user.id, verification_id=verification.id, key=key)
        return {"ok": True, "status": "pending_review"}
        
    except Exception as e:
        logger.error("verification_upload_failed", user_id=user.id, error=str(e))
        # No fallback a local si estamos en prod (asumido por el plan ajustado)
        raise HTTPException(
            status_code=500, 
            detail=f"Error al subir a almacenamiento remoto: {str(e)}"
        )

@router.get("/me", response_model=VerificationMeOut)
def get_my_verification(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user)
):
    """
    Retorna el estado de la última verificación del usuario.
    """
    latest = db.query(UserVerification).filter(
        UserVerification.user_id == user.id
    ).order_by(desc(UserVerification.id)).first()
    
    if not latest:
        return {"status": "none"}
    
    return {
        "status": latest.status,
        "instruction": latest.instruction if latest.status == "pending_upload" else None,
        "rejectionReason": latest.rejection_reason if latest.status == "rejected" else None,
        "attempt": latest.attempt
    }
