# Drift / SQLite Offline Mimari v0.9

Telefon ve Windows istemcisi artık kalıcı yerel SQLite için Drift kullanacak.

## Yerel veritabanı üç işi yapıyor

### 1. Kalıcı işlem kuyruğu
İnternet yokken:
- iade
- fiyat değişikliği
- kiralama oluşturma
- fatura/tahsilat
- satış
- fiziksel sayım

`PendingOperations` tablosuna yazılır.

Uygulama kapansa ve telefon yeniden başlasa bile kuyruk kaybolmaz.

### 2. Artımlı sunucu önbelleği
Sunucudaki `sync_events` kayıtları `CachedEntities` tablosuna işlenir.

Her cihaz son aldığı sıra numarasını saklar:
`last_server_seq`

### 3. Çift kayıt koruması
Her offline işlem UUID taşır.
Merkez sunucu aynı UUID'yi ikinci kez işlemeyi reddeder.

## Build notu

Drift kod üretimi bilgisayarda Flutter SDK kurulduktan sonra:

```bash
dart run build_runner build --delete-conflicting-outputs
```

komutuyla `local_database.g.dart` üretir.
