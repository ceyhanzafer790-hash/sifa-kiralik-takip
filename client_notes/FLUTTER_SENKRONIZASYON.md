# Flutter cihaz senkronizasyonu

Uygulama OneDrive klasörünü doğrudan açmaz.

Her cihaz:
1. lokal Drift DB'ye kaydeder
2. API'ye gönderilmemiş işlemi `pending_sync` olarak işaretler
3. bağlantı gelince API'ye yollar
4. merkezde oluşan değişiklikleri tekrar çeker

Her yeni hareket için cihazda UUID üretilir.
API aynı UUID'yi ikinci kez alırsa işlemi tekrar uygulamaz.
Bu sayede internet gidip gelirken çift kayıt riski azaltılır.

Belge yükleme:
- foto/PDF telefondan seçilir
- API'ye yüklenir
- merkezde saklanır
- tüm cihazlar metadata'yı görür
- OneDrive gece yedeğine otomatik girer
