# Eski Dosya Tarama Motoru v0.17

Bilgisayardaki eski klasörler geldiğinde:

```bash
python3 server/importers/scan_legacy_folder.py \
  "D:/ESKI SOZLESMELER" \
  --dry-run
```

ile önce yalnız tespit yapılabilir.

Gerçek staging:

```bash
python3 server/importers/scan_legacy_folder.py \
  "D:/ESKI SOZLESMELER"
```

Motor:
- SHA-256 hesaplar
- aynı dosyanın ikinci kopyasını ayırır
- dosya adından tarih tahmini yapar
- dosya adından müşteri adayı çıkarır
- Excel'de ilk sayfalardan yapısal önizleme toplar
- orijinal dosyayı staging `raw/` alanına kopyalar
- `pending_match` olarak veritabanına ekler

Önemli:
Tahmin edilen müşteri otomatik canlı kayda bağlanmaz.

PDF/fotoğraf için bu aşamada OCR yapılmaz. Tarama sonucu yönetici eşleştirme
ekranında insan kontrolüne sunulur.
