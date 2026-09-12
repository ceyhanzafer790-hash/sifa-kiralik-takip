# Ödeme Vadesi v0.24

`rental_billing_periods.payment_due_date` fatura bazlı gerçek ödeme vadesidir.

Kurallar:
- Vade yalnız `invoice_status = issued` faturada tutulur.
- Vade, fatura tarihinden önce olamaz.
- Vade zorunlu değildir.
- Vade yoksa fatura açık alacak toplamına girer.
- Vade yoksa fatura "vadesi geçmiş" sayılmaz.
- Kullanıcı vade tarihini daha sonra değiştirebilir veya tamamen kaldırabilir.
- Offline cihazda vade Drift veritabanında saklanır ve senkron kuyruğuna girer.

Gerçek gecikme:
`payment_due_date < bugün AND kalan_bakiye > 0 AND invoice_status = issued`

Gruplar:
- 1-30 gün gecikmiş
- 31-60 gün gecikmiş
- 61+ gün gecikmiş

Eski `Alacak Yaşlandırma` ekranı ayrı kavram olarak korunur. O ekran alacağın yaşını
gösterir; vade ihlali iddiasında bulunmaz.
