# Senkronizasyon v0.8

Sunucu her önemli değişiklikte `sync_events` tablosuna artan bir sıra numarası yazar.

Örnek:
- seq 105 müşteri oluşturuldu
- seq 106 300 direk iadesi eklendi
- seq 107 fiyat değişti
- seq 108 sözleşme yüklendi

Her cihaz son aldığı `seq` değerini saklar.

Cihaz:
`GET /sync/changes?after=108`

dediğinde sadece yeni değişiklikleri alır.

Bu, her seferinde bütün veritabanını indirmekten daha profesyonel ve daha hafiftir.

Offline cihazın gönderdiği her işlem UUID taşır.
Sunucu `client_operations` tablosuyla aynı UUID'nin ikinci kez işlenmesini önler.
