# Tam Offline Kiralama Akışı v0.14

Artık internet yokken şu zincir tasarlandı:

Müşteri
→ Şantiye / Adres
→ Kiralama Takibi
→ Kiralık malzeme satırları
→ Giden hareketi
→ Fiyat
→ İade
→ İade durumu
→ Belge kuyruğu

## Kritik ID kuralı

Sadece kiralama ID'si değil, her `rental_item` ID'si de cihazda üretilir.

Böylece yeni kiralama sunucuya gitmeden önce bile o malzeme satırına iade veya fiyat
hareketi bağlanabilir.

## Typed Drift tabloları

- LocalCustomers
- LocalAddresses
- LocalProducts
- LocalRentals
- LocalRentalItems
- LocalRentalMovements
- LocalRentalRates
- LocalRentalDocuments
- LocalBillingPeriods

Kiralama listesi ve detay ekranı artık demo verisine mecbur değildir.
Önce cihazdaki cache açılır, internet varsa sunucudan tazelenir.
