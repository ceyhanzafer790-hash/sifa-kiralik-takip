# Offline Belge Kuyruğu v0.11

Belge internet yokken seçildiğinde kaynak dosyanın eski yoluna güvenilmez.

Örnek sorun:
- kullanıcı WhatsApp'tan PDF seçti
- Android geçici cache yolunu verdi
- ertesi gün sistem cache'i temizledi
- eski uygulama yalnızca yolu saklasaydı belge kaybolurdu

Çözüm:

1. Kullanıcı PDF/fotoğraf seçer.
2. Uygulama dosyanın byte içeriğini kendi `ApplicationSupport/pending_uploads`
   klasörüne kopyalar.
3. Drift `PendingFileUploads` tablosuna:
   - kiralama ID
   - hareket ID
   - belge türü
   - yerel güvenli yol
   - orijinal dosya adı
   kaydedilir.
4. İnternet gelince FileSyncWorker sunucuya Multipart upload yapar.
5. Sunucu başarı verdikten sonra yerel geçici kopya ve kuyruk satırı silinir.
6. Başarısız olursa dosya yerinde kalır ve tekrar denenir.

Bu sistem uygulama kapanınca da belgeyi kaybetmez.
