FROM python:3.12-slim
WORKDIR /app

ENV PYTHONPATH=/app

# Instalar sqlite3 para backups en la bd
RUN apt-get update && apt-get install -y sqlite3 && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
# Instalar AWS CLI para subir backups a Cloudflare R2
RUN pip install --no-cache-dir awscli

COPY . .
RUN chmod +x start.sh scripts/backup_to_r2.sh && sed -i 's/\r$//' start.sh scripts/backup_to_r2.sh

ENV PYTHONUNBUFFERED=1
ENV PORT=8080
EXPOSE 8080
CMD ["./start.sh"]
