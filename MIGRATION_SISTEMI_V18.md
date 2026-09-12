# PostgreSQL Migration Sistemi v0.18

Üretimde `schema.sql` dosyasını tekrar tekrar çalıştırmak yerine
sürümlü migration sistemi kullanılır.

Dosyalar:

- `server/migrations/0001_initial_snapshot.sql`
- `server/migrations/0002_compatibility_hardening.sql`
- `server/migrations/0003_reporting_views.sql`

API container başlamadan önce:

```bash
python -m app.migrate
```

çalışır.

Her uygulanan migration:
- sürüm
- dosya adı
- SHA-256
- uygulanma zamanı

ile `schema_migrations` tablosuna kaydedilir.

Daha önce uygulanmış bir migration dosyasının içeriği sonradan değiştirilirse
checksum uyuşmazlığı nedeniyle başlangıç durdurulur.

Yeni değişiklik için eski SQL dosyası değiştirilmez.
Yeni `0004_...sql` oluşturulur.

Durum kontrolü:

```bash
python -m app.migrate --check
```

Admin uygulamasında da `Yönetim > Sistem Durumu` üzerinden mevcut ve uygulanmış
migration sürümleri görülebilir.


## PostgreSQL olmadan migration kontrolü

```bash
python3 server/scripts/validate_migrations.py
```

Dosya adlarını, sürüm sırasını, boş migration olup olmadığını ve SHA-256 özetlerini
kontrol eder.

Felaket kurtarma paketi ayrıca `migrations.tar.gz` içerir.
