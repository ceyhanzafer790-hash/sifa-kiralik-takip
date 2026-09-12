# Önerilen Mimari

## Merkez

- Ubuntu Server LTS
- Docker Compose
- PostgreSQL 16
- FastAPI REST API
- Caddy HTTPS reverse proxy
- MinIO veya sunucu dosya sistemi + metadata DB
- WebSocket canlı güncelleme
- Restic + rclone yedekleme

## İstemciler

Tek Flutter kod tabanı:

- Android
- iOS
- Windows

Her cihazda lokal Drift veritabanı bulunur.

### İnternet yokken

Personel örneğin:

Zafer Ceyhan
→ Kiralama Takibi
→ 300 direk geldi
→ Kaydet

işlemini yapar.

Kayıt:
- telefonda hemen görünür
- "Senkronizasyon bekliyor" durumuna geçer

İnternet gelince:
- API'ye gönderilir
- merkez PostgreSQL'e işlenir
- diğer cihazlara WebSocket ile değişiklik bildirimi gider

## Çakışma kuralı

Hareket kayıtları mümkün olduğunca ekleme tabanlıdır.

Örnek:
- Giden 500
- Gelen 300

"500" satırı düzenlenip "200" yapılmaz.
Kalan miktar hareketlerden hesaplanır.

Bu yöntem aynı anda birden fazla personelin kayıt girmesinde veri çakışmasını ciddi
ölçüde azaltır.

## OneDrive'ın görevi

OneDrive istemcilerin veri kaynağı değildir.

OneDrive:
- günlük şifreli yedek
- belge yedeği
- felaket kurtarma
içindir.

Uygulama cihazları doğrudan merkez API ile konuşur.
