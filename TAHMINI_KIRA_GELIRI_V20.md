# Tahmini Aylık Kira Geliri v0.20

Bu gösterge fatura değildir.

## Birim başına aylık
`kirada kalan miktar × bugün geçerli birim kira fiyatı`

## Sabit aylık
Kirada kalan miktar > 0 ise fiyat bir kez alınır.

İadeler kalan miktarı azaltır.
Bugün yürürlükte olmayan fiyatlar hesaba katılmaz.
Fiyatı olmayan aktif kiralık malzemeler ayrıca sayılır.

Dashboard iki rakamı ayırır:

- Tahmini aylık kira: operasyonel tahmin
- Kesilmiş fatura alacağı: `issued` faturaların tahsil edilmemiş gerçek bakiyesi
