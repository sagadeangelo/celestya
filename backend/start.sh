#!/bin/sh
set -e

echo "[START] Applying migrations..."
alembic upgrade head

echo "[START] Starting FastAPI server..."
exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8080}
