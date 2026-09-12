# Felaket Kurtarma Paketi v0.17

Aylık paket yalnız veritabanı dump'ı değildir.

İçerir:
- PostgreSQL `database.dump`
- tüm kiralama/sevkiyat/sözleşme belgeleri `documents.tar.gz`
- o sürümün `schema.sql`
- `migrations.tar.gz` migration geçmişi
- geri yükleme notu
- her dosya için SHA-256 içeren `manifest.json`

Komut:

```bash
./server/scripts/export_disaster_bundle.sh
```

Doğrulama:

```bash
python3 server/scripts/verify_disaster_bundle.py \
  /srv/sifa-backup/disaster/sifa_disaster_....tar.gz
```

Aylık systemd timer da hazırlanmıştır:
- `sifa-disaster-export.service`
- `sifa-disaster-export.timer`

Paket hiçbir `.env` veya düz metin parola içermez.
OneDrive'a giden kopya ayrıca mevcut şifreli rclone katmanından geçirilir.
