# Üretim Öncesi Preflight v0.19

Bilgisayara kurulumdan önce:

```bash
python3 server/scripts/preflight_check.py --offline
```

ile:
- gerekli proje dosyaları
- migration dosyaları
- migration sırası
- temel yapı

kontrol edilir.

Sunucu ortamı kurulduktan sonra:

```bash
python3 server/scripts/preflight_check.py
```

ek olarak:
- Docker
- PostgreSQL bağlantısı
- DOCUMENT_ROOT yazma izni
- yedek klasörü erişimi

kontrol edilir.

Hata varsa üretim kurulumu tamamlanmış kabul edilmez.
