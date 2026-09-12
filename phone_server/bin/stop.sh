#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/common.sh"
pkill -f 'cloudflared tunnel.*127.0.0.1:8000' >/dev/null 2>&1 || true
ubuntu_run bash -lc "pkill -f 'uvicorn app.main:app --host 127.0.0.1 --port 8000' >/dev/null 2>&1 || true" || true
if pg_ctl -D "$PGDATA" status >/dev/null 2>&1; then pg_ctl -D "$PGDATA" stop -m fast >/dev/null; fi
termux-wake-unlock >/dev/null 2>&1 || true
echo "Şifa telefon sunucusu durduruldu."
