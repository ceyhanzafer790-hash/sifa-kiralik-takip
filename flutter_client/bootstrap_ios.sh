#!/usr/bin/env bash
set -euo pipefail

if [ "$(uname -s)" != "Darwin" ]; then
  echo "iOS platform hazırlığı macOS üzerinde çalıştırılmalıdır." >&2
  exit 1
fi
if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter komutu bulunamadı." >&2
  exit 1
fi

flutter create --project-name sifa_kiralik_takip --platforms=ios .
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze

echo "iOS kaynak platformu hazır. Signing/release için Xcode ayarlarını tamamlayın."
