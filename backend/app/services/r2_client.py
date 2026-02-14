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

R2_ACCESS_KEY_ID = os.getenv("R2_ACCESS_KEY_ID")
R2_SECRET_ACCESS_KEY = os.getenv("R2_SECRET_ACCESS_KEY")

# IMPORTANTE: esto debe ser SOLO host base (sin /bucket ni /key)
# Ej: e0b176....r2.cloudflarestorage.com  (o con https://)
R2_ENDPOINT = _normalize_endpoint(os.getenv("R2_ENDPOINT", ""))

R2_REGION = os.getenv("R2_REGION", "auto")

# Usa UN nombre consistente:
# Recomiendo R2_BUCKET (pero si ya tienes R2_BUCKET_NAME en secrets, lo soportamos)
R2_BUCKET = os.getenv("R2_BUCKET") or os.getenv("R2_BUCKET_NAME") or "celestya-media"

if not all([R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_ENDPOINT, R2_BUCKET]):
    # Aquí conviene loguear, pero sin imprimir secretos.
    # Déjalo silencioso si prefieres.
    pass

s3_client = boto3.client(
    "s3",
    region_name=R2_REGION,
    endpoint_url=R2_ENDPOINT,
    aws_access_key_id=R2_ACCESS_KEY_ID,
    aws_secret_access_key=R2_SECRET_ACCESS_KEY,
    config=Config(signature_version="s3v4"),
)

def upload_fileobj(fileobj, key: str, content_type: str | None = None) -> None:
    extra = {"ContentType": content_type} if content_type else {}
    s3_client.upload_fileobj(
        Fileobj=fileobj,
        Bucket=R2_BUCKET,
        Key=key,
        ExtraArgs=extra if extra else None,
    )

def presigned_get_url(key: str, expires_seconds: int = 900) -> str:
    return s3_client.generate_presigned_url(
        ClientMethod="get_object",
        Params={"Bucket": R2_BUCKET, "Key": key},
        ExpiresIn=expires_seconds,
    )

def delete_object(key: str) -> None:
    """
    Elimina un objeto del bucket R2.
    """
    s3_client.delete_object(
        Bucket=R2_BUCKET,
        Key=key,
    )
