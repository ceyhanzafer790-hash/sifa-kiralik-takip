# Hatırlatma Motoru v0.17

Yerel SQLite içinde üç uyarı tipi üretilir:

1. `rental_soon`
   Kira yenilemesine 3 gün kala.

2. `rental_due`
   Kira yenileme günü.

3. `invoice_due`
   Kiralama faturalıysa ve ilgili dönem faturası henüz kesilmediyse.

Uyarılar müşteri ve Kiralama Takibi ID'sine bağlıdır.
İnternet yokken de hesaplanır ve Hatırlatmalar ekranında görünür.

Android/iOS işletim sistemi bildirimi için cihaz kurulum aşamasında bildirim izni,
kanal ve imzalama entegrasyonu bağlanacaktır. Hatırlatma takvimi ve iş mantığı
şimdiden hazırdır.
