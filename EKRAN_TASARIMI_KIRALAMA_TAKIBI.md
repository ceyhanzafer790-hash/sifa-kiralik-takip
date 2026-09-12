# Kiralama Takibi Detay Ekranı v0.7

Tek ekranda aşağıdaki bloklar bulunur:

## 1. Üst bilgi
- Müşteri adı
- Şantiye/adres
- İlk çıkış tarihi
- Sonraki kira yenileme tarihi
- Faturalı/Faturasız
- Aktif/Kapandı
- Bulut senkron durumu

## 2. Özet
- Kiradaki aktif malzeme kalemi
- Tahmini aylık kira
- Sonraki yenileme
- Belge sayısı

## 3. Kiradaki Malzemeler
Her malzeme ayrı:
- ilk gönderilen
- toplam iade
- kirada kalan
- güncel fiyat
- tahmini aylık tutar
- İade Ekle
- Fiyat Gir / Değiştir

Fiyat değişince eski fiyat silinmez. Yeni başlangıç tarihiyle fiyat geçmişine eklenir.

## 4. Kira & Fatura
- Faturalı / Faturasız
- kira yenileme günü
- sonraki yenileme
- bu dönem fatura kesildi

## 5. Belgeler
- Kira sözleşmesi
- Giden sevkiyat belgesi
- Gelen sevkiyat belgesi
- Fatura
- Diğer

Her giden/gelen hareketinin yanında ayrıca ataç düğmesi vardır.
Böylece imzalı sevkiyat tablosu doğrudan o harekete bağlanabilir.

## 6. Fiyat Geçmişi
Örnek:
- 02.09.2026: Direk 100 TL
- 15.10.2026: Direk 110 TL

İlk satır silinmez.

## 7. Hareket Geçmişi
Örnek:
- 02.09.2026 Giden 500
- 08.09.2026 Gelen 300
- kalan 200 hareketlerden hesaplanır

İlk çıkış tarihi iade geldi diye değişmez.
