# Kira Dönemi Hesap Kuralı v0.8

Bu sürümde dönem tutarının sonradan değişmemesi için "snapshot" mantığı eklendi.

Örnek:
- 02.09.2026: 500 direk gitti
- 18.09.2026: 300 direk geldi
- 02.10.2026 kira yenilemesi

02.10.2026 dönem hesabı:
- kirada kalan: 200
- 02.10 tarihinde geçerli fiyat: örneğin 100 TL/adet
- dönem tutarı: 20.000 TL

Bu değerler `quantity_rate_snapshot` içinde saklanır.

Sonra:
- 05.10'da 100 direk daha iade gelse
- 15.10'da fiyat 110 TL olsa

02.10 dönemi geriye dönük değişmez.

Bir sonraki 02.11 dönemi:
- o tarihte kalan miktarı
- o tarihte geçerli fiyatı
kullanır.

Bu sayede geçmiş fatura ve tahsilat hesapları bozulmaz.
