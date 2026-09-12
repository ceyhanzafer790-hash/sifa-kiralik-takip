$ErrorActionPreference = "Stop"

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw "Flutter komutu bulunamadı. Flutter SDK kurulumunu ve PATH ayarını tamamlayın."
}
if (-not (Get-Command dart -ErrorAction SilentlyContinue)) {
    throw "Dart komutu bulunamadı. Flutter SDK PATH ayarını kontrol edin."
}

Write-Host "[1/4] Android + Windows platform klasörleri hazırlanıyor..."
flutter create --project-name sifa_kiralik_takip --platforms=android,windows .

Write-Host "[2/4] Flutter paketleri indiriliyor..."
flutter pub get

Write-Host "[3/4] Drift kodu üretiliyor..."
dart run build_runner build --delete-conflicting-outputs

Write-Host "[4/4] Flutter analyze çalışıyor..."
flutter analyze

Write-Host "Hazır. Çalıştırma örneği:"
Write-Host "flutter run --dart-define=API_BASE_URL=https://api.sifains.com"
