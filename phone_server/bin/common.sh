#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
BASE="$HOME/sifa-phone"
ENV_FILE="$BASE/phone.env"
LOG_DIR="$BASE/data/logs"
PGDATA="$BASE/postgres"
SERVER_DIR="$BASE/server"

if [ ! -f "$ENV_FILE" ]; then
  echo "Şifa telefon sunucu ayarları bulunamadı: $ENV_FILE" >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$ENV_FILE"
mkdir -p "$LOG_DIR"

ubuntu_run() {
  proot-distro login ubuntu \
    --bind "$BASE:/opt/sifa-phone" \
    -- "$@"
}

ubuntu_bg() {
  nohup proot-distro login ubuntu \
    --bind "$BASE:/opt/sifa-phone" \
    -- "$@" >> "$LOG_DIR/proot-api.log" 2>&1 < /dev/null &
  echo $! > "$BASE/api-proot.pid"
}
