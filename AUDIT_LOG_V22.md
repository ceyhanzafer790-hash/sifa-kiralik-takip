# İşlem Geçmişi / Audit v0.22

Admin ekranında işlem geçmişi artık yalnız son kayıtları döken liste değildir.

Filtreler:
- kullanıcı
- kayıt türü
- işlem türü
- tarih aralığı
- serbest metin

Serbest metin:
- kullanıcı adı/e-posta
- entity type
- entity ID
- action
- audit payload

üzerinde aranabilir.

API server-side toplam kayıt sayısı döndürür ve 100 kayıtlık sayfalama kullanılır.
Audit tablosuna tarih, kullanıcı, entity ve action indexleri eklenmiştir.

Audit geçmişi normal uygulama iş akışında silinmez veya yeniden yazılmaz.
