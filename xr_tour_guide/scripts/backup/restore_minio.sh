#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Uso:"
  echo "  $0 /percorso/backup/minio/YYYYMMDD_HHMMSS"
  exit 1
fi

BACKUP_DIR="$1"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/backup.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "Errore: file mancante: $ENV_FILE"
  exit 1
fi

if [ ! -d "$BACKUP_DIR" ]; then
  echo "Errore: directory backup MinIO non trovata: $BACKUP_DIR"
  exit 1
fi

set -a
source "$ENV_FILE"
set +a

APP_DIR="${APP_DIR:-/home/ater/progetti/XRTourGuide/xr_tour_guide}"
DOCKER_NETWORK="${DOCKER_NETWORK:-backend_net}"

cd "$APP_DIR"

echo "Restore MinIO da: $BACKUP_DIR"
echo "ATTENZIONE: i file del bucket verranno sovrascritti."
echo "Continuo tra 5 secondi..."
sleep 5

docker run --rm \
  --network "$DOCKER_NETWORK" \
  --env-file "$APP_DIR/.env" \
  -v "$BACKUP_DIR:/backup" \
  minio/mc@sha256:aead63c77f9db9107f1696fb08ecb0faeda23729cde94b0f663edf4fe09728e3 \
  sh -c '
    mc alias set myminio http://minio:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" &&
    mc mirror --overwrite /backup/"$AWS_STORAGE_BUCKET_NAME" myminio/"$AWS_STORAGE_BUCKET_NAME"
  '

echo "Restore MinIO completato"
