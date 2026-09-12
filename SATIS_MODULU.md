# Satılanlar Modülü v0.9

Müşteri detayı iki ana kola ayrılmaya devam eder:

- Satılanlar
- Kiralananlar

Satış kaydı:
- müşteri
- tarih
- malzeme
- miktar
- birim satış fiyatı
- satır toplamı
- not

Satış stokta `available` kovasından eksi hareket üretir.

Satış kiralama değildir:
- kira yenileme tarihi yoktur
- iade/kalan kiralık hesabı yoktur
- fatura/tahsilat yapısı ileride satış faturası tarafına ayrıca genişletilebilir
