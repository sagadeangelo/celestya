import os
from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from starlette.responses import JSONResponse

from .database import Base, engine, SessionLocal, get_db, ensure_user_columns, DATABASE_URL
from .routes import auth, users, matches, safety, chats, debug, admin
from . import models
from .security import utcnow
from datetime import timedelta
import asyncio
from .routes.upload import router as upload_router
from .routes.media import router as media_router
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.errors import RateLimitExceeded
from .limiter import limiter
from .middleware import SecurityHeadersMiddleware
from .config import validate_config

# ✅ Base del proyecto (carpeta donde está /app)
BASE_DIR = Path(__file__).resolve().parent.parent

def _default_media_root() -> Path:
    if Path("/data").exists():
        return Path("/data/media")
    return BASE_DIR / "media"

MEDIA_ROOT = Path(os.getenv("MEDIA_ROOT", str(_default_media_root()))).resolve()

# ✅ CORS
ALLOWED_ORIGINS = os.getenv("ALLOWED_ORIGINS", "*")

from .logging_conf import configure_logging
import structlog
import uuid
import time
from sqlalchemy import text

configure_logging()
logger = structlog.get_logger("api")


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

    env = os.getenv("ENV", "production").lower()
    is_prod = env == "production"
    
    app = FastAPI(
        title="Celestya API", 
        version="0.1.0",
        docs_url=None if is_prod else "/docs",
        redoc_url=None if is_prod else "/redoc",
        openapi_url=None if is_prod else "/openapi.json"
    )
    
    # ✅ Rate Limiting
    app.state.limiter = limiter
    app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

    @app.get("/")
    def read_root():
        db_type = "unknown"
        if "sqlite" in str(DATABASE_URL):
            db_type = "sqlite"
        elif "postgres" in str(DATABASE_URL):
            db_type = "postgres"
        
        return {
            "app": "Celestya API",
            "version": "0.1.0",
            "deployment_check": "VERSION_ROOT_HEALTH_CHECK",
            "db_type": db_type
        }

    @app.on_event("startup")
    async def startup_event():
        # Log DB identity and simple counts to verify correct DB file
        try:
            logger.info(f"[DB-STARTUP] DATABASE_URL={DATABASE_URL}")
            if str(DATABASE_URL).startswith("sqlite"):
                # mostrar la ruta absoluta del sqlite
                sqlite_path = str(DATABASE_URL).replace("sqlite:", "")
                logger.info(f"[DB-STARTUP] SQLite file: {sqlite_path}")

            # Ejecutar conteos simples
            try:
                with SessionLocal() as db:
                    total = db.execute(text("SELECT count(*) FROM users")).scalar()
                    female = db.execute(text("SELECT count(*) FROM users WHERE gender='female'")).scalar()
                    verified = db.execute(text("SELECT count(*) FROM users WHERE email_verified=1")).scalar()
                    has_photo = db.execute(text("SELECT count(*) FROM users WHERE profile_photo_key IS NOT NULL OR photo_path IS NOT NULL")).scalar()
                    logger.info(f"[DB-COUNTS] users_total={total} female={female} email_verified={verified} has_photo={has_photo}")
            except Exception as e:
                logger.error(f"[DB-STARTUP] Error running counts: {e}")
        except Exception as e:
            logger.error(f"[DB-STARTUP] Error logging DATABASE_URL: {e}")

        # Iniciar el job de limpieza en segundo plano
        asyncio.create_task(daily_cleanup_job())
        
        # Validar configuración
        validate_config()

    # ✅ Security Headers
    app.add_middleware(SecurityHeadersMiddleware)

    # ✅ CORS
    app.add_middleware(
        CORSMiddleware,
        allow_origins=[ALLOWED_ORIGINS] if ALLOWED_ORIGINS != "*" else ["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # ✅ Middleware logging + catch 500 (Structlog)
    @app.middleware("http")
    async def log_requests(request: Request, call_next):
        request_id = request.headers.get("X-Request-ID") or uuid.uuid4().hex
        structlog.contextvars.clear_contextvars()
        structlog.contextvars.bind_contextvars(request_id=request_id)

        start_time = time.time()
        try:
            response = await call_next(request)
            process_time = (time.time() - start_time) * 1000

            # Log completion
            logger.info(
                "request_finished",
                method=request.method,
                path=request.url.path,
                status=response.status_code,
                latency=f"{process_time:.2f}ms"
            )
            return response
        except Exception as e:
            import traceback
            process_time = (time.time() - start_time) * 1000
            
            error_id = uuid.uuid4().hex
            logger.error(
                "request_failed",
                error=str(e),
                traceback=traceback.format_exc(),
                error_id=error_id,
                latency=f"{process_time:.2f}ms"
            )
            return JSONResponse(
                status_code=500,
                content={
                    "detail": "Internal Server Error",
                    "error_id": error_id,
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
    
    # ✅ Admin (Protected) - Persistence Checks
    app.include_router(admin.router, prefix="/admin", tags=["admin"])

    # ✅ Static files (local / media persistente)
    MEDIA_ROOT.mkdir(parents=True, exist_ok=True)
    app.mount("/media", StaticFiles(directory=str(MEDIA_ROOT)), name="media")

    return app


app = create_app()
