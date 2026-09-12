# Sistem Sağlığı v0.19

Admin → Sistem Durumu artık yalnız migration/yedek göstermiyor.

Kontrol edilenler:

- PostgreSQL bağlantısı
- veritabanı boyutu
- belge diski toplam/kullanılan/boş alan
- import staging diski
- kayıtlı belge sayısı ve boyutu
- son yerel yedek yaşı
- son OneDrive yedek yaşı
- migration bekleyen/hatalı sürüm
- aktif kullanıcı sayısı
- aktif/toplam Kiralama Takibi sayısı

Disk eşikleri:

- kritik: 5 GB'tan az veya %10'dan az boş
- uyarı: 10 GB'tan az veya %20'den az boş
- normal: üzeri

Yedek hedefi:

- yerel yedek yaklaşık 6 saatte bir
- OneDrive gecelik

Uzun süredir yedek yoksa Sistem Durumu uyarı/kritik gösterir.
