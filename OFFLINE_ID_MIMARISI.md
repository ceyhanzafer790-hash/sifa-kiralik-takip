# Offline ID Mimarisi v0.12

Merkez sunucu kayıt ID'sini üretmeyi beklemek offline zincir işlemlerini zorlaştırır.

Bu nedenle cihaz yeni bir kayıt oluştururken UUID üretir.

Örnek:

1. İnternet yok.
2. Yeni müşteri: `customer_id = A`
3. Aynı müşteriye adres: `address_id = B`, `customer_id = A`
4. Aynı müşteriye kiralama: `rental_id = C`, `customer_id = A`, `address_id = B`
5. Hepsi Drift kuyruğunda bekler.
6. İnternet gelir.
7. Sunucu A, B ve C kimliklerini aynen kabul eder.

Böylece bağlı kayıtlar kopmaz.

Bu yaklaşım müşteri, adres, kiralama ve satış için uygulanmıştır.
