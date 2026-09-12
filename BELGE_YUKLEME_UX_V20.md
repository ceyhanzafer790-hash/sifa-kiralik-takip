# Belge Yükleme UX v0.20

Telefon hedef akışı:

`Belge Ekle`
→ `Kamerayla Tara`
→ `Galeriden Seç`
→ `Dosyadan Seç`

## Kamerayla Tara
Kurulum/derleme aşamasında güncel ve test edilmiş Flutter kamera/image-picker paketi
seçildikten sonra etkinleştirilecek.

Akış:
1. Fotoğraf çek
2. Önizleme
3. Yeniden çek / Kullan
4. Belge türünü doğrula
5. Kiralama Takibi veya hareket ID'sine bağla
6. Uygulamanın özel support dizinine kopyala
7. Offline kuyruğa al
8. İnternet gelince SHA-256 ile merkeze yükle

## Galeriden Seç
JPG/PNG aynı güvenli offline belge kuyruğuna girer.

## Dosyadan Seç
Mevcut `file_picker` ile:
- PDF
- JPG/JPEG
- PNG
- DOC/DOCX
- XLSX

desteklenir.

## Güvenlik
- JWT/parola loglanmaz.
- Belge içeriği loglanmaz.
- Hareket-belge ilişkisi upload öncesinde korunur.
- Sunucuda SHA-256 tekrar kontrolü bulunur.

Kamera paketi sürümü bilgisayarda gerçek `flutter pub` çözümü görülmeden sabitlenmez.
