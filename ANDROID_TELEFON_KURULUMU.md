# Şifa Kiralık Takip V0.24 - Android telefon kurulumu

## Bu pakette değişen önemli nokta
V0.24 telefon sürümü artık API adresini APK derlenirken sabitlemez.
Uygulama ilk açılışta sunucu adresini telefonda ister ve SharedPreferences içinde saklar.
Sunucu daha sonra değişirse giriş ekranından veya uygulama menüsünden adres değiştirilebilir.

Bu nedenle sunucu henüz kurulmamış olsa bile aynı APK telefona kurulabilir. Sunucu hazır olduğunda
örneğin `https://api.sifains.com` adresi uygulamaya girilir ve giriş yapılır.

## GitHub Actions ile APK üretme
Depoyu GitHub'a gönderin. `.github/workflows/build-android-apk.yml` otomatik olarak:

1. Flutter 3.47.2 stable kurar.
2. Android platform dosyalarını üretir.
3. Paketleri indirir.
4. Drift kod üretimini çalıştırır.
5. `flutter analyze` çalıştırır.
6. Release APK üretir.
7. APK ve SHA-256 dosyasını Actions artifact olarak verir.

Workflow adı: `Android APK Build`
Artifact adı: `sifa-kiralik-takip-v0.24-android`

## Telefonda
1. `app-release.apk` dosyasını telefona indirin.
2. Android isterse tarayıcı/dosya yöneticisi için `Bu kaynaktan uygulama yüklemeye izin ver` seçeneğini açın.
3. APK'yı kurun.
4. İlk açılışta sunucu hazır değilse uygulamayı kapatabilirsiniz; kurulu kalır.
5. Sunucu hazır olduğunda uygulamayı açıp sunucu adresini girin.
6. Yönetici hesabıyla giriş yapın.
