# Şifa V0.24 Geçici Android Telefon Sunucusu

Bu paket bilgisayar hazır olana kadar Android telefonu geçici merkez sunucu yapar.

Mimari:
- PostgreSQL: Termux içinde, sadece localhost
- FastAPI: Ubuntu PRoot içinde, sadece 127.0.0.1:8000
- Dış HTTPS erişim: ücretsiz Cloudflare Quick Tunnel
- Belgeler/veritabanı: ~/sifa-phone altında

Quick Tunnel adresi telefon veya tünel yeniden başlatıldığında değişebilir. Yeni adres `~/sifa-phone/API_URL.txt` dosyasına yazılır.

Komutlar:
- Başlat: `bash ~/sifa-phone/bin/start.sh`
- Durum: `bash ~/sifa-phone/bin/status.sh`
- İlk admin: `bash ~/sifa-phone/bin/create_admin.sh`
- PC yedeği: `bash ~/sifa-phone/bin/backup_for_pc.sh`
- Durdur: `bash ~/sifa-phone/bin/stop.sh`

Kalıcı üretim sunucusu değildir. Telefonun pil optimizasyonunda Termux için kısıtlamayı kaldırın.
