import os
import logging

logger = logging.getLogger("api")

def validate_config():
    """
    Validates critical configuration for production.
    """
    env = os.getenv("ENV", "development")
    if env == "production":
        # Ensure DEBUG is off
        if os.getenv("DEBUG", "false").lower() == "true":
            logger.warning("⚠️  PRODUCTION WARNING: DEBUG is enabled!")

        # Ensure Secret Key is strong (length check)
        secret = os.getenv("SECRET_KEY", "")
        if len(secret) < 32:
            logger.warning("⚠️  PRODUCTION WARNING: SECRET_KEY is weak or missing!")

        # Ensure database is not sqlite (usually)
        db_url = os.getenv("DATABASE_URL", "")
        if "sqlite" in db_url:
            logger.warning("⚠️  PRODUCTION WARNING: Using SQLite in production!")

        # Ensure Allowed Origins is restrictive
        origins = os.getenv("ALLOWED_ORIGINS", "")
        if origins == "*":
            logger.warning("⚠️  PRODUCTION WARNING: ALLOWED_ORIGINS is wildcard '*'!")
