# Eksik Belge Kontrolü v0.19

Sistem aktif Kiralama Takibi kayıtlarını kontrol eder.

Eksik sayılır:

1. Kiralama kaydında `contract` yoksa:
   - Kira sözleşmesi eksik

2. Her aktif `outbound` hareketinde o hareket ID'sine bağlı
   `outbound_delivery` yoksa:
   - Giden sevkiyat belgesi eksik

3. Her aktif `inbound_return` hareketinde o hareket ID'sine bağlı
   `inbound_delivery` yoksa:
   - Gelen/iade belgesi eksik

Bu kontrol belgeyi yalnız müşteri adına veya kiralama geneline yüklemenin yeterli
olmadığı durumları yakalar. Sevkiyat belgesi mümkün olduğunca ilgili hareketin
kendisine bağlanmalıdır.

Yönetim → Eksik Belgeler ekranından ilgili Kiralama Takibi doğrudan açılır.
