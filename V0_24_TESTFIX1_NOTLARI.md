# Şifa V0.24 Testfix1 — Kurulum Öncesi Denetim Notları

Bu paket yeni işlev sürümü değildir. Uygulama sürümü `0.24.0+24` olarak kalır.
Amaç, gerçek Windows/Android/iPhone kurulumuna geçmeden önce statik olarak yakalanabilen kurulum ve senkron sorunlarını düzeltmektir.

## Düzeltilen kritik noktalar

- Belge açma istemci/sunucu endpoint uyumsuzluğu giderildi.
- Belgeler için 5 dakikalık süreli signed-download token akışı eklendi.
- Ödeme vadesinin buluttan Drift'e geri yazılmaması düzeltildi.
- Offline billing map ödeme vadesi + snapshot + row version alanlarını taşıyor.
- Kiralama detayı yenilemesi müşteri telefon/not bilgisini artık null ile ezmiyor.
- Incremental sync eventleri typed Drift cache'i güncelliyor; rental değişikliklerinde ilgili kiralama yeniden çekiliyor.
- Flutter ↔ FastAPI statik endpoint sözleşme kontrolü preflight'a eklendi.
- Restore scriptine güvenli `--dry-run` modu eklendi ve canlı DB'nin otomatik ezilmediği netleştirildi.
- V0.24 hatırlatmalarının uygulama içi olduğu arayüzde açıkça yazıldı.
- Gerçek ekranlarda kalan demo müşteri fallback'i kaldırıldı.
- Sevkiyat sekmesi gerçek Kiralama oluşturma akışına bağlandı; kaydedilmeyen demo taslak kaldırıldı.
- İlk yönetici scripti Docker API image içine dahil edildi.
- Docker Compose runtime ayarları `.env` değerlerini kullanacak şekilde düzeltildi.
- Eski Supabase kurulum belgeleri legacy olarak işaretlendi ve güncel v0.24 kurulum rehberi eklendi.

## Bu ortamda geçen testler

- Python compile: geçti.
- Shell `bash -n`: geçti.
- Migration 0001→0009 dosya doğrulaması: geçti.
- Offline preflight: geçti. Yalnız `psycopg_pool` runtime paketi bu test ortamında kurulu değil.
- API contract scan: geçti. 70 sunucu route'u / 72 istemci çağrısı kontrol edildi.
- Dart relative import: 0 eksik.
- Dart delimiter balance: 0 hata.

## Gerçek bilgisayarda sıradaki kritik testler

1. Python server requirements kurulumu (`psycopg_pool` dahil).
2. `flutter pub get`.
3. Drift `build_runner` (`schemaVersion 6`).
4. `flutter analyze`.
5. Docker/PostgreSQL üzerinde 0001→0009 smoke test.
6. Ödeme vadesi online + offline + iki cihaz senkron testi.
7. Belge yükle → aç → signed link süresi testi.
8. Yavaş SQL metriği gerçek yük testi.
9. Diagnostics ZIP secret sızıntısı kontrolü.
10. Windows + Android build; iOS build/signing macOS üzerinde.
11. Restore drill.

## Hatırlatma notu

V0.24'te Hatırlatma Merkezi cihazın yerel veritabanında çalışır. Uygulama kapalıyken işletim sistemi seviyesinde bildirim henüz gönderilmez. Bu, gerçek cihaz testinden sonra ayrıca ele alınacaktır.
