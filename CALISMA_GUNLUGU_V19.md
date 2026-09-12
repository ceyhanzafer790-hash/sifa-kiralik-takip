# Çalışma Günlüğü v0.19

1. Eski veritabanına migration sisteminin ilk kez eklenmesinde 0001'in eksik kolonlara
   erken dokunma riski bulundu.
2. `_bootstrap_legacy.sql` ve eski DB algılama eklendi.
3. Belge uyumluluk view'ı ve hareket-belge indexleri 0004 migration olarak eklendi.
4. Eksik kira sözleşmesi / giden sevkiyat / gelen iade belgesi kontrolü eklendi.
5. Admin Sistem Durumu disk, DB, yedek, migration ve kullanım metrikleriyle genişletildi.
6. Müşteri Hesap Ekstresi üç sayfalı Excel olarak eklendi.
7. Kiralama ve fatura raporlarına müşteri/tarih filtresi eklendi.
8. Üretim öncesi offline ve online preflight scripti eklendi.
