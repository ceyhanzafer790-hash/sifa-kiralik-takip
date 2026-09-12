#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="${LOCAL_BACKUP_DIR:-/srv/sifa-backup}"
APP_DIR="${SIFA_APP_DIR:-/opt/sifa-kiralik}"
STAMP="$(date +%Y-%m-%d_%H-%M-%S)"
WORK="$BACKUP_DIR/disaster/work_$STAMP"
OUT_DIR="$BACKUP_DIR/disaster"
BUNDLE="$OUT_DIR/sifa_disaster_$STAMP.tar.gz"

mkdir -p "$WORK" "$OUT_DIR"

cleanup() {
  rm -rf "$WORK"
}
trap cleanup EXIT

echo "[1/5] PostgreSQL dump alınıyor..."
docker exec sifa-db pg_dump \
  -U sifa_app \
  -d sifa_kiralik \
  -Fc > "$WORK/database.dump"

echo "[2/5] Belgeler paketleniyor..."
if docker inspect sifa-api >/dev/null 2>&1; then
  docker run --rm \
    --volumes-from sifa-api:ro \
    -v "$WORK":/backup \
    alpine:3.20 \
    sh -c 'cd /data/documents && tar -czf /backup/documents.tar.gz .'
else
  echo "sifa-api container bulunamadı." >&2
  exit 1
fi

echo "[3/5] Şema, migration geçmişi ve kurtarma notları ekleniyor..."
cp "$APP_DIR/server/sql/schema.sql" "$WORK/schema.sql"
tar -C "$APP_DIR/server" -czf "$WORK/migrations.tar.gz" migrations

cat > "$WORK/RESTORE_README.txt" <<'EOF'
ŞİFA İNŞAAT KİRALIK TAKİP - FELAKET KURTARMA PAKETİ

İçerik:
- database.dump        PostgreSQL custom-format yedeği
- documents.tar.gz     sözleşme/sevkiyat vb. belge deposu
- schema.sql           kurulum şemasının o anki kopyası
- migrations.tar.gz    sürümlü veritabanı migration geçmişi
- manifest.json        dosya SHA-256 ve boyut bilgileri

Bu paket doğrudan canlı sisteme körlemesine geri yüklenmemelidir.
Önce verify_disaster_bundle.py ile hash kontrolü yapılır,
sonra database.dump ayrı test veritabanında pg_restore ile denenir.
EOF

echo "[4/5] SHA-256 manifest hazırlanıyor..."
WORK_DIR="$WORK" STAMP="$STAMP" python3 - <<'PY'
import hashlib
import json
import os
from datetime import datetime, timezone
from pathlib import Path

work = Path(os.environ["WORK_DIR"])
stamp = os.environ["STAMP"]

names = [
    "database.dump",
    "documents.tar.gz",
    "schema.sql",
    "migrations.tar.gz",
    "RESTORE_README.txt",
]

files = []
for name in names:
    p = work / name
    h = hashlib.sha256()
    with p.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    files.append({
        "name": name,
        "size_bytes": p.stat().st_size,
        "sha256": h.hexdigest(),
    })

manifest = {
    "product": "Şifa İnşaat Kiralık Takip",
    "bundle_format": 2,
    "app_version": "0.24.0",
    "created_at": datetime.now(timezone.utc).astimezone().isoformat(),
    "stamp": stamp,
    "contains_secrets": False,
    "files": files,
}

with (work / "manifest.json").open("w", encoding="utf-8") as f:
    json.dump(manifest, f, ensure_ascii=False, indent=2)
PY

echo "[5/5] Paket oluşturuluyor..."
tar -C "$WORK" -czf "$BUNDLE" \
  database.dump \
  documents.tar.gz \
  schema.sql \
  migrations.tar.gz \
  RESTORE_README.txt \
  manifest.json

BUNDLE_SHA="$(sha256sum "$BUNDLE" | awk '{print $1}')"
echo "$BUNDLE_SHA  $(basename "$BUNDLE")" > "$BUNDLE.sha256"

STATUS_FILE="$BACKUP_DIR/backup_status.json"
STATUS_FILE="$STATUS_FILE" BUNDLE="$BUNDLE" BUNDLE_SHA="$BUNDLE_SHA" python3 - <<'PY'
import json
import os
from datetime import datetime, timezone
from pathlib import Path

path = Path(os.environ["STATUS_FILE"])

try:
    data = json.loads(path.read_text(encoding="utf-8"))
except Exception:
    data = {}

bundle = Path(os.environ["BUNDLE"])
data["disaster_export_ok"] = True
data["disaster_export_at"] = datetime.now(timezone.utc).astimezone().isoformat()
data["disaster_export_file"] = str(bundle)
data["disaster_export_sha256"] = os.environ["BUNDLE_SHA"]

path.parent.mkdir(parents=True, exist_ok=True)
path.write_text(
    json.dumps(data, ensure_ascii=False, indent=2),
    encoding="utf-8",
)
PY

echo "Felaket kurtarma paketi hazır:"
echo "$BUNDLE"
echo "SHA-256: $BUNDLE_SHA"
