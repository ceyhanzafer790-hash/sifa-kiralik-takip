# Offline Fatura ve Tahsilat v0.16

Kira dönemi internet yokken yerel kiralık miktarları ve o tarihte geçerli fiyatlardan
hesaplanır. Fatura kesildi ve tahsilat hareketleri Drift'te tutulur, sonra sunucuya
`kiralama + yenileme tarihi` ile aktarılır. Sunucu nihai dönem tutarını kendi verisinden
yeniden hesaplar.
