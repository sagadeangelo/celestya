import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from .database import Base, engine
from .routes import auth, users, matches

MEDIA_ROOT = os.getenv("MEDIA_ROOT", "./media")
ALLOWED_ORIGINS = os.getenv("ALLOWED_ORIGINS", "*")

def create_app() -> FastAPI:
    Base.metadata.create_all(bind=engine)

    app = FastAPI(title="Celestya API", version="0.1.0")

    app.add_middleware(
        CORSMiddleware,
        allow_origins=[ALLOWED_ORIGINS] if ALLOWED_ORIGINS != "*" else ["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # rutas
    app.include_router(auth.router, prefix="/auth", tags=["auth"])
    app.include_router(users.router, prefix="/users", tags=["users"])
    app.include_router(matches.router, prefix="/matches", tags=["matches"])

    # media estática
    os.makedirs(MEDIA_ROOT, exist_ok=True)
    app.mount("/media", StaticFiles(directory=MEDIA_ROOT), name="media")
    return app

app = create_app()
