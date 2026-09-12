# Çalışma Günlüğü v0.23

1. Kesilmiş açık faturalar 0-30 / 31-60 / 61+ gün olarak yaşlandırılıyor.
2. Yaş fatura tarihi varsa fatura tarihinden, yoksa kira döneminden hesaplanıyor.
3. Dashboard'a 31+ günlük açık alacak tutarı ve dönem sayısı eklendi.
4. "Vadesi geçmiş" etiketi kullanılmadı; sistemde ayrı vade alanı olmadığı için
   ticari bir varsayım yapılmadı.
5. Audit filtreleriyle birebir XLSX/CSV dışa aktarma eklendi.
6. Secretsiz admin teşhis ZIP'i eklendi.
7. Teşhis loglarından istemci IP ve hassas alanlar çıkarıldı.
8. Release manifest kayıt yardımcısı eklendi; Admin token ortam değişkeninden alınır.
9. 0008 receivable aging index migration eklendi.
10. Runtime latest_client_version ve istemci sürümü 0.23.0'a yükseltildi.
