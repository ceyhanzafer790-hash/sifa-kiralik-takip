# Çalışma Günlüğü v0.9

Bu sürümde alınan ana teknik kararlar:

1. SharedPreferences offline kuyruğu üretim için yetersiz bulundu.
   Drift/SQLite kalıcı kuyruk tasarlandı.

2. Senkronizasyon her dakika ve ağ geri geldiğinde otomatik tetiklenecek.

3. Cihaz bütün veritabanını sürekli indirmeyecek.
   Sunucunun artımlı `sync_events` akışı kullanılacak.

4. Satış ile kiralama kesin olarak ayrı veri modelleri olarak tutuldu.

5. Fiziksel stok sayımı bir miktarı elle ezmeyecek.
   Ledger ile fiziksel sayım farkı `count_adjustment` hareketi olacak.

6. Kiralık çıkış ve kullanılabilir iade, merkez stok hareketine otomatik bağlandı.

7. Ana ekran gerçek sunucu kurulunca yaklaşan kira/fatura bilgisini API'den alacak.


## Kontrol sırasında düzeltilen kritik uyumsuzluk

Flutter ürün kataloğu `p01..p48` sabit kimliklerini kullanırken eski self-hosted
PostgreSQL taslağında ürün PK alanı UUID kalmıştı.

Gerçek veri girmeden düzeltildi:

- `products.id` artık text ve sabit `p01..p48`
- tüm product foreign key alanları text
- 48 ürün SQL ilk kurulum seed'ine eklendi
- fiziksel sayımdan sonra ürünün stok güveni `counted` olur
- son fiziksel sayım tarihi üründe saklanır
