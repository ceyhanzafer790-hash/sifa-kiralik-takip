#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/common.sh"
termux-wake-lock >/dev/null 2>&1 || true
if ! pg_ctl -D "$PGDATA" status >/dev/null 2>&1; then
  echo "[1/4] PostgreSQL başlatılıyor..."
  pg_ctl -D "$PGDATA" -l "$LOG_DIR/postgres.log" start >/dev/null
fi
for _ in $(seq 1 30); do
  pg_isready -h 127.0.0.1 -p 5432 >/dev/null 2>&1 && break
  sleep 1
done
pg_isready -h 127.0.0.1 -p 5432 >/dev/null 2>&1 || { echo "PostgreSQL başlatılamadı. Log: $LOG_DIR/postgres.log" >&2; exit 1; }
echo "[2/4] Migration kontrolü..."
ubuntu_run bash -lc '
  set -e
  source /opt/sifa-phone/phone.env
  export DATABASE_URL="postgresql://sifa_app:${POSTGRES_PASSWORD}@127.0.0.1:5432/sifa_kiralik"
  export JWT_SECRET
  export DOCUMENT_ROOT=/opt/sifa-phone/data/documents
  export IMPORT_ROOT=/opt/sifa-phone/data/import-inbox
  export BACKUP_STATUS_FILE=/opt/sifa-phone/data/backup_status.json
  export LOG_ROOT=/opt/sifa-phone/data/logs
  export DB_POOL_MIN_SIZE=1
  export DB_POOL_MAX_SIZE=4
  export DB_POOL_TIMEOUT_SECONDS=10
  export DB_SLOW_QUERY_MS=750
  export REQUIRED_RELEASE_PLATFORMS=android
  cd /opt/sifa-phone/server
  /opt/sifa-phone/venv/bin/python -m app.migrate
'
ubuntu_run bash -lc "pkill -f 'uvicorn app.main:app --host 127.0.0.1 --port 8000' >/dev/null 2>&1 || true" || true
sleep 1
echo "[3/4] Şifa API başlatılıyor..."
ubuntu_bg bash -lc '
  set -e
  source /opt/sifa-phone/phone.env
  export DATABASE_URL="postgresql://sifa_app:${POSTGRES_PASSWORD}@127.0.0.1:5432/sifa_kiralik"
  export JWT_SECRET
  export DOCUMENT_ROOT=/opt/sifa-phone/data/documents
  export IMPORT_ROOT=/opt/sifa-phone/data/import-inbox
  export BACKUP_STATUS_FILE=/opt/sifa-phone/data/backup_status.json
  export LOG_ROOT=/opt/sifa-phone/data/logs
  export DB_POOL_MIN_SIZE=1
  export DB_POOL_MAX_SIZE=4
  export DB_POOL_TIMEOUT_SECONDS=10
  export DB_SLOW_QUERY_MS=750
  export REQUIRED_RELEASE_PLATFORMS=android
  cd /opt/sifa-phone/server
  exec /opt/sifa-phone/venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8000
'
for _ in $(seq 1 45); do
  curl -fsS http://127.0.0.1:8000/health >/dev/null 2>&1 && break
  sleep 1
done
curl -fsS http://127.0.0.1:8000/health >/dev/null 2>&1 || { echo "API başlatılamadı. Log: $LOG_DIR/api.log" >&2; exit 1; }
pkill -f 'cloudflared tunnel.*127.0.0.1:8000' >/dev/null 2>&1 || true
: > "$LOG_DIR/cloudflared.log"
echo "[4/4] Geçici HTTPS tüneli açılıyor..."
nohup cloudflared tunnel --url http://127.0.0.1:8000 > "$LOG_DIR/cloudflared.log" 2>&1 < /dev/null &
echo $! > "$BASE/cloudflared.pid"
URL=""
for _ in $(seq 1 60); do
  URL="$(grep -Eo 'https://[a-z0-9-]+\.trycloudflare\.com' "$LOG_DIR/cloudflared.log" | tail -n 1 || true)"
  [ -n "$URL" ] && break
  sleep 1
done
[ -n "$URL" ] || { echo "Cloudflare adresi alınamadı. Log: $LOG_DIR/cloudflared.log" >&2; exit 1; }
printf '%s\n' "$URL" > "$BASE/API_URL.txt"
printf '\n==============================================\nŞİFA TELEFON SUNUCUSU ÇALIŞIYOR\nSunucu adresi: %s\n==============================================\n\n' "$URL"
printf 'Android uygulamasında: Giriş ekranı > Sunucu adresini değiştir > yukarıdaki adresi yapıştır.\n'
