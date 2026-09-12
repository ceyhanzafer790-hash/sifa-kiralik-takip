#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${SIFA_APP_DIR:-/opt/sifa-kiralik}"
BACKUP_DIR="${LOCAL_BACKUP_DIR:-/srv/sifa-backup}"
COMPOSE="${COMPOSE_CMD:-docker compose}"

cd "$APP_DIR"

HAS_RUNTIME_TABLE=0
GATEWAY_STOPPED=0
FAILED=1

has_runtime_table() {
  docker exec sifa-db psql \
    -U sifa_app \
    -d sifa_kiralik \
    -tAc "
      select case
        when to_regclass('public.app_runtime_settings') is null
        then 0
        else 1
      end;
    " | tr -d '[:space:]'
}

maintenance_on() {
  docker exec sifa-db psql \
    -U sifa_app \
    -d sifa_kiralik \
    -v ON_ERROR_STOP=1 \
    -c "
      update app_runtime_settings
      set maintenance_mode = true,
          maintenance_message =
            'Sistem güncelleniyor. Lütfen birkaç dakika bekleyin.',
          updated_at = now()
      where id = 1;
    " >/dev/null
}

maintenance_off() {
  docker exec sifa-db psql \
    -U sifa_app \
    -d sifa_kiralik \
    -v ON_ERROR_STOP=1 \
    -c "
      update app_runtime_settings
      set maintenance_mode = false,
          maintenance_message = null,
          updated_at = now()
      where id = 1;
    " >/dev/null
}

cleanup() {
  if [ "$FAILED" -ne 0 ]; then
    echo
    echo "GÜNCELLEME BAŞARISIZ."
    if [ "$HAS_RUNTIME_TABLE" -eq 1 ]; then
      echo "Bakım modu güvenlik için AÇIK bırakıldı."
    fi
    if [ "$GATEWAY_STOPPED" -eq 1 ]; then
      echo "Caddy dış erişimi güvenlik için KAPALI bırakıldı."
    fi
    echo "Log ve migration durumunu kontrol etmeden canlı trafiği açma."
  fi
}
trap cleanup EXIT

echo "[1/7] Güncelleme öncesi yerel yedek..."
LOCAL_BACKUP_DIR="$BACKUP_DIR" \
  "$APP_DIR/server/scripts/backup_local.sh"

echo "[2/7] Yazma trafiği güvenli moda alınıyor..."
if [ "$(has_runtime_table)" = "1" ]; then
  HAS_RUNTIME_TABLE=1
  maintenance_on
  echo "Bakım modu açıldı."
else
  echo "Runtime tablosu henüz yok. İlk geçiş için Caddy durduruluyor."
  docker stop sifa-caddy >/dev/null
  GATEWAY_STOPPED=1
fi

echo "[3/7] Yeni API image build ediliyor..."
$COMPOSE build api

echo "[4/7] DB ve API güncelleniyor; startup migration çalıştıracak..."
$COMPOSE up -d db api

echo "[5/7] API sağlık kontrolü bekleniyor..."
HEALTH_OK=0
for i in $(seq 1 30); do
  if docker exec -i sifa-api python - <<'PY' >/dev/null 2>&1
import urllib.request

with urllib.request.urlopen(
    "http://127.0.0.1:8000/health",
    timeout=3,
) as response:
    if response.status != 200:
        raise SystemExit(1)
PY
  then
    HEALTH_OK=1
    break
  fi
  sleep 2
done

if [ "$HEALTH_OK" -ne 1 ]; then
  echo "API sağlık kontrolü başarısız."
  docker logs --tail 100 sifa-api || true
  exit 1
fi

echo "[6/7] Migration bütünlüğü doğrulanıyor..."
docker exec sifa-api python -m app.migrate --check

# v0.21 migration sonrası runtime tablosu artık bulunmalıdır.
if [ "$(has_runtime_table)" != "1" ]; then
  echo "app_runtime_settings migration sonrası bulunamadı." >&2
  exit 1
fi

echo "[7/7] Dış erişim ve normal çalışma açılıyor..."
maintenance_off
$COMPOSE up -d caddy

GATEWAY_STOPPED=0
FAILED=0

echo "Şifa Kiralık Takip güncellemesi başarıyla tamamlandı."
