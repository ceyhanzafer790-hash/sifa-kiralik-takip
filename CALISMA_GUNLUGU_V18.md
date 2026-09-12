# Çalışma Günlüğü v0.18

1. PostgreSQL kurulum/güncelleme modeli schema.sql tekrarından versioned migration
   sistemine çevrildi.
2. Uygulanmış migration dosyalarının SHA-256 değerleri saklanıyor.
3. Docker API başlamadan migration çalıştırıyor.
4. Kiralama, stok ve fatura/tahsilat için XLSX/CSV rapor API'leri eklendi.
5. Flutter Raporlar ekranı eklendi.
6. Yönetim > Sistem Durumu ile migration ve yedek bilgileri birleştirildi.
7. Senkron çakışma ekranı ham JSON yerine iş alanlarını yan yana karşılaştırıyor.
8. Eski Excel için configurable mapping profile motoru eklendi.
9. Önceki gerçek Excel dosyaları aktif dosya alanında bulunamadığı için gerçek sütun
   şeması varsayılmadı; bilgisayar erişiminde inspect aracıyla profil kesinleştirilecek.
