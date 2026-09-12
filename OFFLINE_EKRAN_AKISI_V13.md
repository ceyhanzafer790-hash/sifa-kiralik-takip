# Offline Ekran Akışı v0.13

İnternet yokken artık ekran üzerinden:

1. Müşteri oluştur
2. Müşteriye gir
3. Yeni Kiralama
4. Malzemeleri ekle
5. Faturalı/Faturasız seç
6. Kaydet

yapılabilir.

Cihaz:
- müşteri UUID'sini
- kiralama UUID'sini
önceden üretir.

Kayıtlar yerel cache + Drift kuyruğunda kalır.
İnternet gelince bağlı kayıtlar aynı ID'lerle merkeze gönderilir.
