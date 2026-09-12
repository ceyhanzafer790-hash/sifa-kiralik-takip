# Çalışma Günlüğü v0.14

1. Kiralama listesi hâlâ demo kayıtlarından çalışıyordu. Demo bağı kaldırıldı.
2. Kiralama detayı offline-first repository üzerinden açılır hale getirildi.
3. Şantiye/adres ayrı yerel tabloya alındı ve yeni kiralamada seçilebilir/eklenebilir.
4. Rental item ID'si client-generated UUID oldu.
5. İade ve fiyat değişikliği offline iken gerçek rental_item_id'ye bağlanabilir hale geldi.
6. Rental item, movement, rate, document ve billing verileri typed Drift cache'e alındı.
7. Yerel ürün kataloğu uygulama açılışında seed edilir.
8. Yedeklerin yalnız oluşması değil, sağlık bilgisinin Admin ekranında görünmesi eklendi.
9. En son veritabanı yedeğini geçici DB'ye açarak test eden script eklendi.
10. Geri yükleme scripti canlı veriyi otomatik ezmeyecek şekilde güvenli tutuldu.
