# Şifa V0.24 Phone Ready değişiklikleri

- API_BASE_URL artık yalnızca derleme zamanında sabit olmak zorunda değil.
- Sunucu adresi ilk açılışta telefondan girilebilir ve cihazda saklanır.
- Giriş ekranından sunucu adresi değiştirilebilir.
- Uygulama içi menüden sunucu adresi sıfırlanıp yeniden girilebilir.
- Sunucu henüz hazır değilse APK telefonda kurulu kalabilir; sunucu daha sonra bağlanabilir.
- GitHub Actions üzerinden Android release APK üretimi için workflow eklendi.
- Workflow Flutter 3.47.2 stable ile Android platformunu oluşturur, paketleri indirir, Drift kodunu üretir, analyze çalıştırır ve release APK üretir.
