# Şifa Kiralık Takip Flutter İstemcisi — v0.24 Testfix1

Bu klasör güncel Android, iOS ve Windows Flutter kaynak kodudur.
Bulut katmanı Supabase değildir. Güncel sistem FastAPI + PostgreSQL merkez sunucusunu kullanır.

## Platform klasörleri

ZIP içinde `android/`, `ios/` ve `windows/` klasörleri bulunmayabilir. Flutter SDK kurulu geliştirme bilgisayarında, bu klasörde önce bir yedek alın ve ardından:

Windows için:

```powershell
.\bootstrap_windows_android.ps1
```

macOS üzerinde iOS için:

```bash
./bootstrap_ios.sh
```

Betiğin yaptığı işlemler `flutter create`, `flutter pub get`, Drift `build_runner` ve `flutter analyze` adımlarıdır. Web hedefi oluşturulmaz.

## API adresi

Uygulama API adresini derleme/çalıştırma sırasında `API_BASE_URL` ile alır:

```bash
flutter run --dart-define=API_BASE_URL=https://api.sifains.com
```

Release örnekleri:

```bash
flutter build windows --release --dart-define=API_BASE_URL=https://api.sifains.com
flutter build apk --release --dart-define=API_BASE_URL=https://api.sifains.com
```

iOS release/signing işlemi macOS + Xcode üzerinde yapılmalıdır.

## Offline yapı

- Drift/SQLite yerel veritabanı
- Kalıcı senkron kuyruğu
- Bağlantı geldiğinde otomatik gönderim
- Sunucudan artımlı değişiklikleri yerel typed cache'e işleme
- Belge yüklemeleri için ayrı kalıcı kuyruk

## Eski Supabase dosyaları

`SUPABASE_KURULUM.md` ve `supabase_schema.sql` yalnız tarihsel v0.5 referansıdır. Güncel v0.24 kurulumu için kullanılmamalıdır.
Ana kurulum rehberi proje kökündeki `KURULUM_V24_TESTFIX1.md` dosyasıdır.
