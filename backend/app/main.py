import os
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from .database import Base, engine
from .routes import auth, users, matches


# ✅ Base del proyecto (carpeta donde está /app)
BASE_DIR = Path(__file__).resolve().parent.parent  # .../celestya-backend/app/..

# ✅ MEDIA_ROOT ABSOLUTO (para que no dependa del "cwd")
# Puedes sobreescribirlo con variable de entorno MEDIA_ROOT si quieres.
MEDIA_ROOT = Path(os.getenv("MEDIA_ROOT", str(BASE_DIR / "media"))).resolve()

# ✅ CORS
ALLOWED_ORIGINS = os.getenv("ALLOWED_ORIGINS", "*")


def create_app() -> FastAPI:
    # crea tablas (si así lo estás manejando)
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

    # ✅ Archivos estáticos (IMÁGENES)
    # IMPORTANTE: crear carpeta antes del mount
    MEDIA_ROOT.mkdir(parents=True, exist_ok=True)
    app.mount("/media", StaticFiles(directory=str(MEDIA_ROOT)), name="media")

    return app


app = create_app()
