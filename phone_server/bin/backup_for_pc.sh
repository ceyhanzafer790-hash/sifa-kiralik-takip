#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/common.sh"
STAMP="$(date +%Y-%m-%d_%H-%M-%S)"
WORK="$BASE/backups/$STAMP"
mkdir -p "$WORK"
echo "[1/3] PostgreSQL yedeği alınıyor..."
PGPASSWORD="$POSTGRES_PASSWORD" pg_dump -h 127.0.0.1 -p 5432 -U sifa_app -d sifa_kiralik -Fc -f "$WORK/sifa_kiralik.dump"
echo "[2/3] Belgeler paketleniyor..."
tar -czf "$WORK/documents.tar.gz" -C "$BASE/data" documents import-inbox
cat > "$WORK/README_PC_AKTARIM.txt" <<TXT
Şifa İnşaat V0.24 telefon geçici sunucu aktarım paketi
Oluşturma: $STAMP
İçerik:
- sifa_kiralik.dump : PostgreSQL veritabanı
- documents.tar.gz : kiralama/sevkiyat belgeleri ve import klasörü

Parolalar bu pakete dahil edilmemiştir. PC sunucusunda yeni güçlü DB/JWT secret üretilebilir.
Veritabanındaki kullanıcı hesapları ve parola hashleri korunur.
TXT
echo "[3/3] PC aktarım paketi oluşturuluyor..."
DEST_DIR="$HOME/storage/downloads"
if [ ! -d "$DEST_DIR" ]; then DEST_DIR="$BASE/backups"; fi
ARCHIVE="$DEST_DIR/sifa_phone_to_pc_${STAMP}.tar.gz"
tar -czf "$ARCHIVE" -C "$WORK" .
sha256sum "$ARCHIVE" > "$ARCHIVE.sha256"
echo "Hazır: $ARCHIVE"
echo "SHA-256: $(cut -d' ' -f1 "$ARCHIVE.sha256")"
