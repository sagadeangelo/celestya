import os
from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from starlette.responses import JSONResponse

from .database import Base, engine, SessionLocal, get_db, ensure_user_columns
from .routes import auth, users, matches, safety, chats, debug
from . import models
from .security import utcnow
from datetime import timedelta
import asyncio
from .routes.upload import router as upload_router
from .routes.media import router as media_router

# ✅ Base del proyecto (carpeta donde está /app)
BASE_DIR = Path(__file__).resolve().parent.parent

def _default_media_root() -> Path:
    if Path("/data").exists():
        return Path("/data/media")
    return BASE_DIR / "media"

MEDIA_ROOT = Path(os.getenv("MEDIA_ROOT", str(_default_media_root()))).resolve()

# ✅ CORS
ALLOWED_ORIGINS = os.getenv("ALLOWED_ORIGINS", "*")

# ✅ Logging
import logging
import time

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("api")


async def daily_cleanup_job():
    """
    Tarea automática que corre cada 24 horas.
    Limpia usuarios con email_verified=False que:
    - Expiraron su código de verificación.
    - O tienen más de 24 horas sin verificar.
    """
    while True:
        try:
            # Esperamos un poco al inicio para no entorpecer el arranque
            await asyncio.sleep(60) 
            
            with SessionLocal() as db:
                now = utcnow()
                yesterday = now - timedelta(hours=24)
                
                deleted = db.query(models.User).filter(
                    models.User.email_verified == False,
                    (
                        (models.User.email_verification_expires_at < now) |
                        (models.User.created_at < yesterday)
                    )
                ).delete(synchronize_session=False)
                
                db.commit()
                if deleted > 0:
                    logger.info(f"[JOB] Limpieza automática completada: {deleted} usuarios eliminados.")
        except Exception as e:
            logger.error(f"[JOB] Error en limpieza automática: {e}")
        
        # Dormir 24 horas
        await asyncio.sleep(86400)


def create_app() -> FastAPI:
    # ✅ En prod normalmente NO conviene auto-crear tablas.
    # Pero lo dejo como lo tienes, solo lo hago opcional:
    if os.getenv("AUTO_CREATE_TABLES", "true").lower() == "true":
        Base.metadata.create_all(bind=engine)

    # Migración manual segura (SQLite)
    ensure_user_columns(engine)

    app = FastAPI(title="Celestya API", version="0.1.0")

    @app.on_event("startup")
    async def startup_event():
        # Iniciar el job de limpieza en segundo plano
        asyncio.create_task(daily_cleanup_job())

    # ✅ CORS
    app.add_middleware(
        CORSMiddleware,
        allow_origins=[ALLOWED_ORIGINS] if ALLOWED_ORIGINS != "*" else ["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # ✅ Middleware logging + catch 500
    @app.middleware("http")
    async def log_requests(request: Request, call_next):
        start_time = time.time()
        try:
            response = await call_next(request)
            process_time = (time.time() - start_time) * 1000

            if response.status_code >= 400:
                logger.error(
                    f"❌ {request.method} {request.url.path} - {response.status_code} - {process_time:.2f}ms"
                )
            return response
        except Exception as e:
            import traceback

            logger.error(
                "INTERNAL SERVER ERROR: %s\n%s",
                str(e),
                traceback.format_exc(),
            )
            return JSONResponse(
                status_code=500,
                content={
                    "detail": "Internal Server Error",
                    "error_id": str(int(time.time())),
                    "trace": str(e),
                },
            )

    # ✅ Handler de validación JSON
    @app.exception_handler(RequestValidationError)
    async def validation_exception_handler(request: Request, exc: RequestValidationError):
        logger.error(f"Validation Error: {exc.errors()}")
        return JSONResponse(
            status_code=422,
            content={
                "detail": "Error de validación en los datos enviados. Asegúrate de enviar un JSON válido.",
                "errors": exc.errors(),
            },
        )

    # ✅ Rutas API
    app.include_router(auth.router, prefix="/auth", tags=["auth"])
    app.include_router(users.router, prefix="/users", tags=["users"])
    app.include_router(matches.router, prefix="/matches", tags=["matches"])
    app.include_router(chats.router, prefix="/chats", tags=["chats"])

    # ✅ Upload a R2
    app.include_router(upload_router, tags=["uploads"])

    # ✅ Media (ej: /media/url)
    app.include_router(media_router, tags=["media"])

    # ✅ Safety
    app.include_router(safety.router)

    # ✅ Debug (Protected)
    app.include_router(debug.router, prefix="/_debug", tags=["debug"])

    # ✅ Static files (local / media persistente)
    MEDIA_ROOT.mkdir(parents=True, exist_ok=True)
    app.mount("/media", StaticFiles(directory=str(MEDIA_ROOT)), name="media")

    return app


app = create_app()
