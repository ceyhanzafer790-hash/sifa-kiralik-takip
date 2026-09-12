# Eski Belge Uyumluluk İstisnası v0.21

Eski yıllara ait fiziksel belge doğrulanmış ama sistemde hareket ID'sine bağlı dijital
dosya yoksa Admin gerekçeli istisna verebilir.

İstisna:
- Kiralama Takibi ID
- varsa hareket ID
- belge türü
- gerekçe
- ekleyen kullanıcı
- tarih
- geri alma bilgisi

ile saklanır.

İstisna belge yaratmaz ve dosya varmış gibi davranmaz.
Sadece `Eksik Belgeler` uyumluluk alarmından o doğrulanmış kalemi çıkarır.

İstisna geri alınabilir. Oluşturma ve geri alma audit log'a yazılır.
