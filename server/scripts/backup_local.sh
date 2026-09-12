#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="${LOCAL_BACKUP_DIR:-/srv/sifa-backup}"
STAMP="$(date +%Y-%m-%d_%H-%M-%S)"
DB_REL="database/sifa_${STAMP}.dump"
DOC_REL="documents/documents_latest.tar.gz"

mkdir -p "$BACKUP_DIR/database"
mkdir -p "$BACKUP_DIR/documents"

echo "[1/3] PostgreSQL yerel yedeği..."
docker exec sifa-db \
  pg_dump -U sifa_app -d sifa_kiralik -Fc \
  > "$BACKUP_DIR/$DB_REL"

echo "[2/3] Belge deposu yerel yedeği..."
if ! docker inspect sifa-api >/dev/null 2>&1; then
  echo "sifa-api container bulunamadı; belge volume erişimi doğrulanamadı." >&2
  exit 1
fi

docker run --rm \
  --volumes-from sifa-api:ro \
  -v "$BACKUP_DIR/documents:/backup" \
  alpine:3.20 \
  sh -c 'cd /data/documents && tar -czf /backup/documents_latest.tar.gz .'

find "$BACKUP_DIR/database" \
  -type f \
  -name "*.dump" \
  -mtime +14 \
  -delete

echo "[3/3] Backup status güncelleniyor..."
STATUS_FILE="$BACKUP_DIR/backup_status.json"
STATUS_FILE="$STATUS_FILE" \
DB_REL="$DB_REL" \
DOC_REL="$DOC_REL" \
python3 - <<'PY'
import json
import os
from datetime import datetime, timezone
from pathlib import Path

path = Path(os.environ["STATUS_FILE"])

try:
    data = json.loads(path.read_text(encoding="utf-8"))
except Exception:
    data = {}

data["local_backup_ok"] = True
data["local_backup_at"] = (
    datetime.now(timezone.utc).astimezone().isoformat()
)
data["database_file"] = os.environ["DB_REL"]
data["documents_file"] = os.environ["DOC_REL"]

path.parent.mkdir(parents=True, exist_ok=True)
path.write_text(
    json.dumps(data, ensure_ascii=False, indent=2),
    encoding="utf-8",
)
PY

echo "Yerel yedek tamamlandı: $STAMP"
