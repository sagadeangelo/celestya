#!/bin/bash
set -e

echo "[backup] START"

DB_PATH="/data/celestya.db"
if [ ! -f "$DB_PATH" ]; then
    echo "[backup] ERROR: Database not found at $DB_PATH"
    exit 1
fi

TIMESTAMP=$(date -u +"%Y%m%d_%H%M%S")
YEAR=$(date -u +"%Y")
MONTH=$(date -u +"%m")
DAY=$(date -u +"%d")
HOSTNAME=$(hostname)

LOCAL_BACKUP_DIR="/data/backups"
mkdir -p "$LOCAL_BACKUP_DIR"

TMP_DB="$LOCAL_BACKUP_DIR/celestya-${HOSTNAME}-${TIMESTAMP}.db"
GZ_FILE="${TMP_DB}.gz"

echo "[backup] Creating consistent snapshot to $TMP_DB..."
sqlite3 "$DB_PATH" ".backup '$TMP_DB'"

echo "[backup] Compressing snapshot..."
gzip -c "$TMP_DB" > "$GZ_FILE"

echo "[backup] SNAPSHOT OK"

# Verificar variables necesarias para Cloudflare R2
if [ -z "$R2_BUCKET" ] || [ -z "$R2_ENDPOINT" ] || [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "[backup] ERROR: Faltan credenciales de R2. Verifica R2_BUCKET, R2_ENDPOINT, AWS_ACCESS_KEY_ID, y AWS_SECRET_ACCESS_KEY."
    rm -f "$TMP_DB" "$GZ_FILE"
    exit 1
fi

# Rutas de subida en R2
R2_PATH="s3://${R2_BUCKET}/backups/sqlite/${YEAR}/${MONTH}/${DAY}/celestya-${HOSTNAME}-${TIMESTAMP}.db.gz"
LATEST_PATH="s3://${R2_BUCKET}/backups/sqlite/latest/celestya-latest.db.gz"

echo "[backup] Uploading to $R2_PATH..."
aws s3 cp "$GZ_FILE" "$R2_PATH" --endpoint-url "$R2_ENDPOINT"

echo "[backup] Updating latest pointer..."
aws s3 cp "$GZ_FILE" "$LATEST_PATH" --endpoint-url "$R2_ENDPOINT"

echo "[backup] UPLOAD OK"

echo "[backup] Cleaning up raw snapshot..."
rm -f "$TMP_DB"

echo "[backup] Deleting local backups older than 30 days..."
find "$LOCAL_BACKUP_DIR" -type f -name "*.gz" -mtime +30 -exec rm -f {} \;

echo "[backup] COMPLETE"
