# OneDrive Yedek Stratejisi

Şirketin mevcut ortak OneDrive alanı yedek hedefi olarak kullanılabilir.

Önerilen klasör:

Şifa İnşaat/
└── Uygulama Yedekleri/
    └── Kiralık Takip/

## Araçlar

- rclone: OneDrive bağlantısı
- restic: şifreli, sürümlü, tekilleştirilmiş yedek

İkisi de açık kaynak yazılımdır.

## Önerilen zamanlama

Yerel hızlı yedek:
- PostgreSQL: 6 saatte bir
- Belgeler: günlük

OneDrive dış yedek:
- her gece 02:30

Saklama:
- son 14 günlük yedek
- son 8 haftalık yedek
- son 12 aylık yedek

## Çok önemli

OneDrive ortak klasöründe bulunan **canlı backup repository klasörü**
personel tarafından elle düzenlenmemeli veya taşınmamalıdır.

Uygulama içindeki belgeler normal kullanıcı arayüzünden açılır.
OneDrive yedek klasörü yalnızca sistem yöneticisi/felaket kurtarma içindir.

## Fidye yazılımına karşı

Sadece OneDrive yeterli değildir çünkü silme/şifreleme senkronize olabilir.

Bu nedenle:
- merkezde ikinci SSD
- OneDrive sürüm geçmişi
- restic şifreli snapshot
birlikte kullanılmalıdır.
