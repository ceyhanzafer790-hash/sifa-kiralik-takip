#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="${LOCAL_BACKUP_DIR:-/srv/sifa-backup}"
LATEST="$(find "$BACKUP_DIR/database" -type f -name 'sifa_*.dump' \
  -printf '%T@ %p\n' | sort -nr | head -1 | cut -d' ' -f2-)"

if [ -z "$LATEST" ]; then
  echo "Test edilecek yedek bulunamadı."
  exit 1
fi

echo "Test ediliyor: $LATEST"

docker exec sifa-db dropdb \
  -U sifa_app \
  --if-exists sifa_backup_test

docker exec sifa-db createdb \
  -U sifa_app \
  sifa_backup_test

cat "$LATEST" | docker exec -i sifa-db \
  pg_restore \
  -U sifa_app \
  -d sifa_backup_test

COUNT="$(docker exec sifa-db psql -U sifa_app -d sifa_backup_test -tAc \
  "select count(*) from information_schema.tables where table_schema='public';")"

docker exec sifa-db dropdb \
  -U sifa_app \
  sifa_backup_test

echo "Yedek doğrulandı. Public tablo sayısı: $COUNT"
