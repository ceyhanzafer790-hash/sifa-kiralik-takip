# Offline ve Senkronizasyon Kuralı

Uygulama hareket odaklı çalışır.

Telefon internet çekmiyorsa:
1. Kullanıcı kaydı yapar.
2. Ekranda sonuç anında görünür.
3. İşlem benzersiz bir UUID ile `bekleyen senkron` kuyruğuna alınır.
4. İnternet gelince merkez API'ye gönderilir.
5. Sunucu aynı UUID'yi daha önce işlediyse ikinci kez uygulamaz.
6. Başarılı olunca kuyruktan silinir.

Bu özellikle giden/gelen hareketlerinde çift kayıt riskini azaltır.

v0.7'de yerel kuyruk SharedPreferences ile prototip olarak oluşturuldu.
Üretim sürümünde bu kuyruk ve yerel veri Drift/SQLite'a taşınacak.
