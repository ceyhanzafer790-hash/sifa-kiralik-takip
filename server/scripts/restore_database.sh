#!/usr/bin/env bash
set -euo pipefail

DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=1
  shift
fi

if [ "$#" -ne 1 ]; then
  echo "Kullanım: $0 [--dry-run] /srv/sifa-backup/database/sifa_YYYY-MM-DD_HH-MM-SS.dump"
  exit 1
fi

BACKUP_FILE="$1"

if [ ! -f "$BACKUP_FILE" ]; then
  echo "Yedek dosyası bulunamadı: $BACKUP_FILE"
  exit 1
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo "DRY-RUN: hiçbir veritabanı değiştirilmeyecek."
  echo "1. Canlı sifa_kiralik veritabanının acil durum dump'ı alınacaktı."
  echo "2. sifa_restore_test adlı ayrı test veritabanı yeniden oluşturulacaktı."
  echo "3. Seçilen yedek yalnız test veritabanına açılacaktı: $BACKUP_FILE"
  echo "4. Canlı sifa_kiralik veritabanı otomatik olarak ezilmeyecekti."
  exit 0
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker bulunamadı. Geri yükleme doğrulaması çalıştırılamaz."
  exit 1
fi

if ! docker inspect sifa-db >/dev/null 2>&1; then
  echo "sifa-db container bulunamadı veya erişilemiyor."
  exit 1
fi

echo "Seçilen yedek önce AYRI test veritabanına açılacak."
echo "Canlı sifa_kiralik veritabanı otomatik olarak değiştirilmeyecek."
read -r -p "Devam etmek için GERI_YUKLE_TEST yazın: " CONFIRM

if [ "$CONFIRM" != "GERI_YUKLE_TEST" ]; then
  echo "İptal edildi."
  exit 1
fi

EMERGENCY_DUMP="/tmp/sifa_before_restore_$(date +%Y%m%d_%H%M%S).dump"
docker exec sifa-db pg_dump \
  -U sifa_app \
  -d sifa_kiralik \
  -Fc > "$EMERGENCY_DUMP"

echo "Canlı DB acil durum kopyası alındı: $EMERGENCY_DUMP"

docker exec sifa-db dropdb \
  -U sifa_app \
  --if-exists sifa_restore_test

docker exec sifa-db createdb \
  -U sifa_app \
  sifa_restore_test

cat "$BACKUP_FILE" | docker exec -i sifa-db \
  pg_restore \
  -U sifa_app \
  -d sifa_restore_test \
  --clean \
  --if-exists

COUNT="$(docker exec sifa-db psql -U sifa_app -d sifa_restore_test -tAc \
  "select count(*) from information_schema.tables where table_schema='public';")"

echo "Yedek test veritabanına başarıyla açıldı. Public tablo sayısı: $COUNT"
echo "Canlı veritabanı değiştirilmedi."
echo "Test DB: sifa_restore_test"
