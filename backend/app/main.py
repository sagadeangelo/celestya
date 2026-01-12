import os
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from .database import Base, engine
from app.routes import auth, users, matches
from app.routes.upload import router as upload_router
from app.routes.media import router as media_router  # ✅ ok

# ✅ Base del proyecto (carpeta donde está /app)
BASE_DIR = Path(__file__).resolve().parent.parent

# ✅ MEDIA_ROOT ABSOLUTO
MEDIA_ROOT = Path(os.getenv("MEDIA_ROOT", str(BASE_DIR / "media"))).resolve()

# ✅ CORS
ALLOWED_ORIGINS = os.getenv("ALLOWED_ORIGINS", "*")


def create_app() -> FastAPI:
    Base.metadata.create_all(bind=engine)

    app = FastAPI(title="Celestya API", version="0.1.0")

    # CORS
    app.add_middleware(
        CORSMiddleware,
        allow_origins=[ALLOWED_ORIGINS] if ALLOWED_ORIGINS != "*" else ["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # Rutas API
    app.include_router(auth.router, prefix="/auth", tags=["auth"])
    app.include_router(users.router, prefix="/users", tags=["users"])
    app.include_router(matches.router, prefix="/matches", tags=["matches"])

    # ✅ SUBIDAS (R2 / upload)
    app.include_router(upload_router, tags=["uploads"])

    # ✅ media router (ponlo AQUÍ, no afuera)
    app.include_router(media_router, tags=["media"])

    # ✅ Archivos estáticos (si sigues usando /media local)
    MEDIA_ROOT.mkdir(parents=True, exist_ok=True)
    app.mount("/media", StaticFiles(directory=str(MEDIA_ROOT)), name="media")

    return app


app = create_app()
