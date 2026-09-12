# Eski Excel Eşleme Profili v0.18

Gerçek eski dosyaların sütun düzeni uydurulmaz.

Şimdilik genel Şifa profili hazırlanmıştır:

`server/importers/profiles/sifa_generic_v1.json`

Aday alanlar:
- müşteri
- şantiye/adres
- tarih
- malzeme
- miktar
- giden
- gelen/iade
- kalan
- birim
- fiyat
- not

Başlıklar Türkçe karakter ve büyük/küçük harf farkından arındırılır.
Örneğin:
- `Çıkış`
- `CIKIS`
- `çıkış`
aynı normalize değere yaklaşır.

Gerçek dosyalar bilgisayarda erişilebilir olduğunda:

```bash
python3 server/importers/inspect_excel_profiles.py "D:/ESKI_EXCELLER"
```

ile bütün dosyaların önerilen başlık satırı ve sütun eşleşmeleri çıkarılır.

Bu sonuçtan sonra `sifa_generic_v1` yerine gerçek Şifa dosyalarına özgü profil
kesinleştirilir.
