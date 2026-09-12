# Şifa İnşaat Kiralık Malzeme Takibi v0.24 Testfix1

Güncel mimari: Flutter (Android/iOS/Windows) + FastAPI + PostgreSQL + Caddy.
Supabase belgeleri yalnız eski v0.5 tarihçesi olarak tutulur ve güncel kurulumda kullanılmaz.
Güncel kurulum için `KURULUM_V24_TESTFIX1.md` dosyasını izleyin.

## v0.9

- Drift/SQLite kalıcı offline veritabanı
- kalıcı senkronizasyon kuyruğu
- bağlantı gelince otomatik senkron
- 1 dakikalık periyodik senkron kontrolü
- artımlı sunucu değişikliklerini yerel cache'e alma
- API tabanlı ana ekran kira/fatura hatırlatmaları
- Satılanlar API ve ekran altyapısı
- fiziksel stok sayım ekranı
- bağ/paket + açık adet hızlı sayım
- sayım farkını otomatik stok düzeltme hareketine çevirme
- kiralık çıkış/iade ve satışların stok hareketlerine bağlanması

## Bilgisayara geçince gereken kod üretimi

Flutter SDK kurulduğunda Drift için:

```bash
cd flutter_client
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

Ardından istemci derlenebilir.

OneDrive canlı veritabanı değildir.
Şifreli yedek katmanı olarak kalır.

## v0.10

- İadede Kullanılabilir / Tamirlik / Hurda ayrımı eklendi.
- İade durumu stok kovasına doğru şekilde yansır.
- Satılanlar ekranında çok kalemli gerçek satış formu hazırlandı.
- Satış internet yokken Drift offline kuyruğuna alınır.

## v0.11

- Admin / Staff / Viewer rolü istemci ekranlarına uygulanmaya başladı.
- Viewer yazma butonlarını kullanamaz; sunucu da yazma isteğini reddeder.
- Offline belge yüklemede dosya kalıcı uygulama klasörüne kopyalanır.
- Drift içinde ayrı belge yükleme kuyruğu eklendi.
- Otomatik senkron hem veri hem belge kuyruklarını gönderir.
- Tamirden çıkan malzeme repair -> available hareketiyle stoğa döner.
- Hurda ve kayıp hareketleri ayrı kovalarla tarihçeli tutulur.

## v0.12

- Offline müşteri/adres/kiralama/satış kayıtlarında cihaz UUID üretir.
- Sunucu bu UUID'leri aynen kabul eder.
- Yönetici kullanıcı ekranı eklendi.
- Admin / Staff / Viewer rol değişimi.
- Kullanıcı aktif/pasif yönetimi.
- Yönetici tarafından şifre yenileme.
- Audit/işlem geçmişi ekranı.
- İlk yönetici hesabı için `server/scripts/create_first_admin.py`.

## v0.13

- Offline Yeni Müşteri ekranı.
- Offline Yeni Kiralama ekranı.
- Typed Drift cache: müşteri, ürün, kiralama.
- Açılış stoğu API + ekran.
- Satın alma API + ekran.
- Açılış stoğu yalnız ilk stok hareketi olarak kabul edilir.

## v0.14

- Kiralama Takibi demo verisinden çıkarılıp offline-first yapıya bağlandı.
- Şantiye/adres offline ekleme ve kiralamaya bağlama eklendi.
- Kiralık malzeme satırlarına cihazda UUID atanıyor.
- İade/fiyat işlemleri sunucu olmadan doğru satıra bağlanabiliyor.
- Rental item/movement/rate/document/billing typed Drift cache eklendi.
- Yönetici Yedek Sağlığı ekranı eklendi.
- En son PostgreSQL yedeğini gerçek restore testiyle doğrulayan script eklendi.

## v0.15

- Hareket/fiyat kayıtlarında cihaz ve sunucu aynı UUID'yi kullanır.
- Başarılı senkron sonrası pendingSync temizlenir.
- Genel Arama: müşteri, şantiye, malzeme, kiralama, belge.
- Admin Eski Veri Eşleştirme ekranı.

## v0.16

- row_version ile cihazlar arası değişiklik çakışması koruması.
- Kira dönemi, fatura ve tahsilat offline çalışır.
- Senkron hata tekrarlarında 1/2/5/15/30/60 dakika backoff.
- Belge SHA-256 tekrar yükleme koruması.

## v0.17

- LocalRentals rowVersion eksikliği düzeltildi.
- Aynı işlemin tekrar gönderilmesi ile gerçek row-version çakışması ayrıldı.
- Online deneme ve offline retry aynı operation UUID'yi koruyabiliyor.
- Drift SyncConflicts + kullanıcı çakışma çözme ekranı.
- Offline kira/fatura hatırlatma merkezi.
- Aylık felaket kurtarma paketi: DB + belgeler + schema + SHA-256 manifest.
- Eski dosya tarayıcı: hash tekrar kontrolü, dosya adı tarih/müşteri adayı,
  XLSX yapısal önizleme.

## v0.18

- Versioned PostgreSQL migration sistemi ve SHA-256 koruması.
- Docker API başlamadan otomatik migration.
- Kiralama / Stok / Fatura-Tahsilat XLSX ve CSV raporları.
- Flutter Raporlar ekranı.
- Yönetim > Sistem Durumu migration + yedek görünümü.
- Çakışma ekranında alan alan Türkçe karşılaştırma.
- Eski Excel dosyaları için yapılandırılabilir eşleme profili motoru.

## v0.19

- Legacy veritabanı için migration bootstrap güvenliği.
- 0004 document compliance migration.
- Eksik sözleşme / sevkiyat / iade belgesi kontrolü.
- Admin Sistem Durumu: DB, disk, yedek, migration, kullanım.
- Müşteri Hesap Ekstresi: Özet + Kiralamalar + Fatura/Tahsilat Excel.
- Raporlarda müşteri ve tarih filtresi.
- Offline/production preflight kontrol scripti.

## v0.20

- Genel Durum artık offline gerçek Drift verisinden çalışır.
- Tahmini aylık kira geliri ve fiyatı eksik kiralık kalem göstergesi.
- Kesilmiş faturalardan gerçek açık alacak ayrı gösterilir.
- Eksik belge / kira / fatura / stok güveni dashboard kartları.
- Müşteri Hesap Ekstresi dönem filtresi ve Satışlar sayfası.
- JSONL API logları, X-Request-ID ve 10 MB x 10 rotasyon.
- Kalıcı Docker `logs_data` volume.
- 0005 dashboard/revenue migration.

## v0.21

- Admin / Staff / Viewer için gerçek rol bazlı navigation.
- Bakım modunda Staff salt-okunur arayüze düşer.
- X-App-Version ve opsiyonel 426 minimum sürüm enforcement.
- Admin-only alacak ve tahmini kira dağılımı detay ekranları.
- Finansal toplamlar server-side da Admin'e özel.
- Eski arşiv belgeleri için gerekçeli ve geri alınabilir compliance exception.
- Rutin yerel yedekte eski v0.6 volume adı düzeltildi.
- Güvenli sunucu güncellemesi: backup → maintenance → migration → health → reopen.
- 0006 runtime settings / compliance exceptions migration.

## v0.22

- PostgreSQL connection pool: varsayılan min 2 / max 10.
- FastAPI lifespan ile pool açılış/kapanış yönetimi.
- İşlem Geçmişi: kullanıcı, kayıt türü, işlem, tarih ve metin filtresi.
- Audit server-side pagination ve toplam kayıt sayısı.
- Alacak ekranında müşteri/tarih/fatura araması.
- Tahmini kira ekranında müşteri/şantiye/malzeme araması ve kalem detayı.
- `app_releases` metadata tablosu ve Admin Sürüm Paketleri ekranı.
- Android/Windows/iOS build artifact SHA-256 manifest üretme/doğrulama araçları.
- Kontrollü internal_error 500 cevabı ve X-Request-ID destek akışı.
- System Health connection-pool istatistikleri.
- 0007 audit/release migration.

## v0.23

- Kesilmiş açık alacaklarda 0-30 / 31-60 / 61+ gün yaşlandırma.
- Dashboard'da 31+ günlük açık alacak göstergesi.
- Audit filtreleriyle XLSX/CSV dışa aktarma.
- Admin için hassas bilgi içermeyen teşhis ZIP'i.
- Release manifest kayıt yardımcısı; token yalnız ortam değişkeninden okunur.
- 0008 receivable aging migration.
- Uygulama/API sürümü 0.23.0.

## v0.24

- Fatura bazlı gerçek `payment_due_date`.
- Vade ekleme/değiştirme/kaldırma, offline Drift + senkron desteği.
- Gerçek vadesi geçmiş alacak: 1-30 / 31-60 / 61+ gün.
- Dashboard gerçek overdue toplamı ve vadesi eksik açık fatura sayısı.
- SQL sorgu süre ölçümü ve yavaş sorgu System Health metrikleri.
- Audit detayından müşteri/Kiralama Takibi kaydına doğrudan geçiş.
- Admin Üretime Hazırlık kontrol ekranı.
- Tek parça üretime hazırlık kontrol listesi.
- v0.23 System Status kopya metod düzeltmesi.
- 0009 payment due date migration.

