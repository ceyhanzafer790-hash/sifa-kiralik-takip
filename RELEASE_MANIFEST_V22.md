# Release Manifest v0.22

Gerçek uygulama build dosyasının yalnız dosya adına güvenilmez.

Her artifact için:
- version
- platform
- file_name
- size_bytes
- SHA-256
- opsiyonel download_path
- release notes
- mandatory flag

saklanabilir.

Desteklenen platformlar:
- Android
- Windows
- iOS

Manifest üretme örneği:

```bash
python3 server/scripts/build_release_manifest.py \
  --version 0.22.0 \
  --artifact android:/build/sifa-kiralik.apk \
  --artifact windows:/build/sifa-kiralik-windows.zip \
  --output release-manifest.json
```

Doğrulama:

```bash
python3 server/scripts/verify_release_manifest.py \
  release-manifest.json \
  --artifact-dir /build
```

Bu sistem dijital imzanın yerine geçmez. SHA-256, build dosyasının manifestteki
dosyayla aynı olup olmadığını doğrular. Platform imzalama ayrıca Android/iOS/Windows
build sürecinde yapılacaktır.
