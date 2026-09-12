#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/common.sh"
ubuntu_run bash -lc '
  set -e
  source /opt/sifa-phone/phone.env
  export DATABASE_URL="postgresql://sifa_app:${POSTGRES_PASSWORD}@127.0.0.1:5432/sifa_kiralik"
  cd /opt/sifa-phone/server
  /opt/sifa-phone/venv/bin/python scripts/create_first_admin.py
'
