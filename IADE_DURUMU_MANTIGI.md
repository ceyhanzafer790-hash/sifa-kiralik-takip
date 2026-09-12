# İade Durumu Mantığı v0.10

Müşteriden geri gelen kiralık malzeme üç durumdan biriyle kaydedilir:

## Kullanılabilir
- müşterideki kiradan düşer
- `available` depo stokuna girer

## Tamirlik
- müşterideki kiradan düşer
- kullanılabilir depoya girmez
- `repair` kovasına girer

## Hurda
- müşterideki kiradan düşer
- kullanılabilir depoya girmez
- `scrap` kovasına girer

Örnek:

500 direk kirada
300 geri geldi:
- 250 kullanılabilir
- 40 tamirlik
- 10 hurda

Kiralama Takibi kalan:
200

Stok etkisi:
+250 available
+40 repair
+10 scrap

Bu ayrım depo gerçeğini korur.
