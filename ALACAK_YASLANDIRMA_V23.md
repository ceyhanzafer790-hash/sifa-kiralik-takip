# Alacak Yaşlandırma v0.23

Sistem yalnız `invoice_status = issued` ve kalan bakiyesi > 0 dönemleri yaşlandırır.

Yaş başlangıcı:
1. `invoice_date` varsa fatura tarihi
2. yoksa `renewal_date`

Gruplar:
- 0-30 gün
- 31-60 gün
- 61+ gün

Dashboard ayrıca:
- 31+ günlük açık alacak tutarı
- 31+ günlük açık dönem sayısı

gösterir.

Bu gösterge "vadesi geçmiş" ifadesini kullanmaz çünkü ayrı ödeme vadesi alanı henüz
tanımlı değildir. Ticari vade bilgisi daha sonra eklenirse gerçek overdue hesabı ayrı
yapılabilir.
