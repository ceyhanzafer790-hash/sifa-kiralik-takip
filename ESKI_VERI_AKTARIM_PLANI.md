# Eski Veri ve Belge Aktarım Planı

Bilgisayara erişim sağlandığında eski klasörler doğrudan canlı kayıtlara boca edilmeyecek.

## Aşama 1 - Tarama
Kaynaklar:
- Excel müşteri/sevkiyat dosyaları
- kira sözleşmeleri
- giden sevkiyat tabloları
- gelen sevkiyat tabloları
- faturalar
- diğer PDF/fotoğraflar

Her dosya önce `legacy_import_items` tablosuna bir aday olarak düşer.

## Aşama 2 - Otomatik tespit
Mümkünse:
- müşteri adı
- belge tarihi
- belge türü
- malzeme/miktar
tespit edilir.

## Aşama 3 - Eşleştirme
Dosya:
- müşteriye
- Kiralama Takibi kaydına
- gerekiyorsa giden/gelen hareketine
bağlanır.

Emin olunmayan dosya yanlış eşleştirilmez.
Durumu `pending_match` veya `needs_review` kalır.

## Aşama 4 - İçeri alma
Onaylı eşleşme:
- gerçek eski tarihini korur
- belgeyi merkez depoya kopyalar
- audit kaydı oluşturur
- OneDrive yedeğine dahil olur

## Kritik kural
Eski bir belge bugün içeri aktarıldı diye `bugünün tarihi` verilmez.
Belgenin gerçek tarihi ve eski hareket tarihi korunur.
