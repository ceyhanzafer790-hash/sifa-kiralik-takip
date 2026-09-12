# Şifa V0.24 Testfix1 — Statik Test Sonuçları

Tarih: 2026-09-10

## Geçen kontroller

- Python `compileall`: geçti.
- Tüm `server/scripts/*.sh` için `bash -n`: geçti.
- PostgreSQL migration dosyaları `0001 -> 0009`: SHA-256/dosya doğrulaması geçti.
- Flutter ↔ FastAPI statik endpoint sözleşmesi: geçti (`70` server route / `72` client çağrısı).
- Offline preflight: geçti.
- Docker Compose YAML parse: geçti.
- Dart kaynak dosyası: `78`.
- Dart relative import taraması: `0` eksik.
- Dart delimiter/parantez taraması: `0` hata.
- Aktif demo müşteri/kiralama referansı: `0`.
- Restore script `--dry-run`: geçti; canlı veritabanına yazma yapmıyor.
- İlk yönetici scriptinin Docker image dahil edilmesi: statik olarak doğrulandı.

## Bu ortamda çalıştırılamayan gerçek testler

Bu test ortamında Flutter/Dart SDK, Docker daemon ve gerçek PostgreSQL runtime yok. Ayrıca dış paket ağı kapalı olduğundan `psycopg_pool` burada kurulamadı. Bu nedenle aşağıdakiler gerçek geliştirme/sunucu bilgisayarında tamamlanmalıdır:

- `flutter pub get`
- Drift `build_runner`
- `flutter analyze`
- Windows/Android/iOS derleme
- Docker image build ve container çalışma testi
- `psycopg_pool` runtime testi
- gerçek PostgreSQL migration smoke testi
- iki cihaz senkron testi
- signed belge açma testi
- gerçek restore drill

## Sonuç

V0.24 Testfix1 statik kurulum öncesi kontrolleri geçti. Paket gerçek bilgisayar kurulumu ve cihaz testine hazır adaydır; gerçek runtime testleri tamamlanmadan canlı şirket verisiyle üretim kullanımı başlatılmamalıdır.
