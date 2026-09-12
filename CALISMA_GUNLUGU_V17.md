# Çalışma Günlüğü v0.17

1. LocalRentals tablosunda kullanılan fakat tanımlanmamış rowVersion alanı düzeltildi.
2. HTTP 409 tek tip hata olmaktan çıkarıldı:
   - operation_already_processed
   - row_version_conflict
3. Sunucu cevabı kaybolduktan sonraki retry işlemlerinde aynı operation UUID'nin
   korunabilmesi için enqueueWithId eklendi.
4. Çakışmalar ayrı Drift tablosuna alınarak sonsuz retry döngüsü engellendi.
5. Kullanıcıya Sunucu Sürümünü Kullan / Benim Değişikliğimi Tekrar Uygula seçenekleri
   veren çakışma ekranı eklendi.
6. Kira ve fatura hatırlatma motoru yerel SQLite üzerinde hazırlandı.
7. Felaket kurtarma paketi veritabanı + belgeler + şema + SHA-256 manifest içerecek
   şekilde tasarlandı.
8. Eski dosya tarama motoru hash, dosya adı tarihi ve Excel yapısal önizleme desteğiyle
   hazırlandı.
9. Eski dosya tahminleri hiçbir zaman otomatik olarak canlı müşteri kaydına bağlanmıyor.
