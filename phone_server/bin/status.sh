#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/common.sh"
echo "--- PostgreSQL ---"
if pg_ctl -D "$PGDATA" status >/dev/null 2>&1; then echo "çalışıyor"; else echo "kapalı"; fi
echo "--- API ---"
if curl -fsS http://127.0.0.1:8000/health; then echo; else echo "kapalı/yanıt vermiyor"; fi
echo "--- HTTPS adresi ---"
if [ -s "$BASE/API_URL.txt" ]; then cat "$BASE/API_URL.txt"; else echo "henüz yok"; fi
