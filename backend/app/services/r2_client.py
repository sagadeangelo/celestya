import os
import boto3
from botocore.config import Config

def _normalize_endpoint(raw: str) -> str:
    """
    Acepta:
      - 'e0b....r2.cloudflarestorage.com'
      - 'https://e0b....r2.cloudflarestorage.com'
    y devuelve SIEMPRE:
      - 'https://e0b....r2.cloudflarestorage.com'
    (sin rutas, sin doble esquema)
    """
    raw = (raw or "").strip()

    # quita espacios y slash final
    raw = raw.rstrip("/")

    # si accidentalmente te guardaron algo como 'https://https:/host...'
    raw = raw.replace("https://https:/", "https://")
    raw = raw.replace("http://http:/", "http://")

    # si tiene esquema, lo dejamos
    if raw.startswith("http://") or raw.startswith("https://"):
        return raw

    # si no tiene esquema, lo agregamos
    return f"https://{raw}"

import logging
import functools

logger = logging.getLogger("api")

def _get_env_or_none(key):
    val = os.getenv(key, "").strip()
    return val if val else None

@functools.lru_cache()
def get_s3_client():
    endpoint = _normalize_endpoint(os.getenv("R2_ENDPOINT", ""))
    access_key = os.getenv("R2_ACCESS_KEY_ID")
    secret_key = os.getenv("R2_SECRET_ACCESS_KEY")
    bucket = os.getenv("R2_BUCKET") or os.getenv("R2_BUCKET_NAME") or "celestya-media"

    if not all([endpoint, access_key, secret_key]):
        logger.warning("⚠️  R2 Credentials missing. S3 Client will fail on use.")
        # Return None or raise? Raising might be safer catchable.
        # But let's return a dummy or raise immediately?
        # If we raise here, startup is safe (lazy), but usage crashes.
        raise RuntimeError("R2 Credentials not configured.")

    return boto3.client(
        "s3",
        region_name=os.getenv("R2_REGION", "auto"),
        endpoint_url=endpoint,
        aws_access_key_id=access_key,
        aws_secret_access_key=secret_key,
        config=Config(signature_version="s3v4"),
    )

def _get_bucket_name():
    return os.getenv("R2_BUCKET") or os.getenv("R2_BUCKET_NAME") or "celestya-media"

def upload_fileobj(fileobj, key: str, content_type: str | None = None) -> None:
    client = get_s3_client()
    bucket = _get_bucket_name()
    extra = {"ContentType": content_type} if content_type else {}
    client.upload_fileobj(
        Fileobj=fileobj,
        Bucket=bucket,
        Key=key,
        ExtraArgs=extra if extra else None,
    )

def presigned_get_url(key: str, expires_seconds: int = 900) -> str:
    try:
        client = get_s3_client()
        bucket = _get_bucket_name()
        return client.generate_presigned_url(
            ClientMethod="get_object",
            Params={"Bucket": bucket, "Key": key},
            ExpiresIn=expires_seconds,
        )
    except Exception as e:
        logger.error(f"Failed to generate presigned URL: {e}")
        return ""

def delete_object(key: str) -> None:
    """
    Elimina un objeto del bucket R2.
    """
    try:
        client = get_s3_client()
        bucket = _get_bucket_name()
        client.delete_object(
            Bucket=bucket,
            Key=key,
        )
    except Exception as e:
        logger.error(f"Failed to delete object {key}: {e}")

def check_object_exists(key: str) -> bool:
    """
    Verifica si un objeto existe en el bucket R2.
    """
    try:
        client = get_s3_client()
        bucket = _get_bucket_name()
        client.head_object(Bucket=bucket, Key=key)
        return True
    except Exception:
        # 404 Not Found lanza excepción en boto3
        return False
