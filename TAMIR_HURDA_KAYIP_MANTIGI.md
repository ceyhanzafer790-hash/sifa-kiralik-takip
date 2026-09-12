# Tamir / Hurda / Kayıp v0.11

## Tamirden çıkan malzeme
Tamirlik kovadan düşer ve kullanılabilir stoğa eklenir.

Örnek:
- repair = 40 direk
- 25 direk tamir edildi

Hareketler:
- repair: -25
- available: +25

Kalan:
- repair = 15
- available = önceki + 25

## Hurdaya ayırma
Kullanılabilir veya tamirlik stoktan düşürülür ve `scrap` kovasına eklenir.

## Kayıp
Kullanılabilir veya tamirlik stoktan düşürülür ve `lost` kovasına eklenir.

Bu kayıtlar doğrudan miktar değiştirme değildir.
Her biri tarihçeli stok hareketidir.
