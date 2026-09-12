# Finans Detay v0.21

Admin dashboard'daki iki para kartı artık detay ekranına iner.

## Kesilmiş Fatura Alacakları
Her açık dönem:
- müşteri
- şantiye
- kira dönemi
- fatura no
- fatura tutarı
- tahsil edilen
- kalan bakiye

Toplam yalnız `invoice_status=issued` faturaların gerçek kalan bakiyesidir.

## Tahmini Kira Dağılımı
Müşteri + şantiye bazında:
- tahmini aylık kira
- aktif kiralık kalem
- fiyatı eksik kalem

Tahmini kira fatura değildir ve alacak toplamına eklenmez.

Bu iki API yalnız Admin rolüne açıktır.
