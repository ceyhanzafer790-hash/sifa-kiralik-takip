# Teşhis Paketi v0.23

Admin → Sistem Durumu → TEŞHİS PAKETİ OLUŞTUR

ZIP içeriği:
- diagnostics.json
- recent_errors.json
- README.txt

diagnostics.json:
- uygulama sürümü
- Python/platform bilgisi
- bakım ve istemci sürüm ayarları
- PostgreSQL boyutu
- temel kayıt adetleri
- migration durumu
- connection-pool istatistikleri

recent_errors.json:
- yalnız WARNING / ERROR / CRITICAL kayıtları
- request_id
- method
- path
- HTTP status
- süre
- log mesajı

Bilerek dışarıda bırakılır:
- DATABASE_URL
- JWT / Authorization
- parola
- request body
- sözleşme/sevkiyat dosyası içeriği
- istemci IP adresi

Teşhis paketi destek amacıyla paylaşılabilir ama yine de iş verisi içeren sistem
metadata'sı barındırdığı için rastgele kişilere gönderilmemelidir.
