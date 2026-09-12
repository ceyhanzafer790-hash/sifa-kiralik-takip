#!/usr/bin/env bash
set -euo pipefail

: "${RESTIC_PASSWORD:?RESTIC_PASSWORD gerekli}"
: "${RCLONE_REMOTE:?RCLONE_REMOTE gerekli}"
: "${RCLONE_PATH:?RCLONE_PATH gerekli}"

BACKUP_DIR="${LOCAL_BACKUP_DIR:-/srv/sifa-backup}"
export RESTIC_REPOSITORY="rclone:${RCLONE_REMOTE}:${RCLONE_PATH}"

if ! restic snapshots >/dev/null 2>&1; then
  restic init
fi

restic backup "$BACKUP_DIR"

restic forget \
  --keep-daily 14 \
  --keep-weekly 8 \
  --keep-monthly 12 \
  --prune

restic check

python3 - <<'PY'
import json, os
from datetime import datetime, timezone

backup_dir = os.environ.get("LOCAL_BACKUP_DIR", "/srv/sifa-backup")
path = os.path.join(backup_dir, "backup_status.json")
try:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
except Exception:
    data = {}

data["cloud_backup_ok"] = True
data["cloud_backup_at"] = datetime.now(timezone.utc).astimezone().isoformat()

with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
PY

echo "OneDrive şifreli yedeği tamamlandı."
