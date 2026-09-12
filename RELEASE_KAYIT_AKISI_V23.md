# Release Kayıt Akışı v0.23

Bilgisayarda gerçek APK / Windows / iOS artifact üretildikten sonra:

1. Manifest üret:
```bash
python3 server/scripts/build_release_manifest.py \
  --version 0.23.0 \
  --artifact android:/build/sifa-kiralik.apk \
  --artifact windows:/build/sifa-kiralik-windows.zip \
  --output release-manifest.json
```

2. SHA-256 doğrula:
```bash
python3 server/scripts/verify_release_manifest.py \
  release-manifest.json \
  --artifact-dir /build
```

3. Admin token'ı komut satırına yazmadan ortam değişkenine koy:
```bash
export SIFA_ADMIN_TOKEN="..."
```

4. Manifest kayıtlarını sunucuya işle:
```bash
python3 server/scripts/register_release_manifest.py \
  --base-url https://api.sifains.com \
  --manifest release-manifest.json
```

Token dosyaya yazılmaz. Komut satırı argümanı olarak da alınmaz.
