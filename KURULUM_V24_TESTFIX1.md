# Şifa İnşaat Kiralık Takip v0.24 Testfix1
# Kurulum ve Gerçek Cihaz Test Sırası

Bu rehber güncel self-hosted mimari içindir. Supabase kullanılmaz.

## 1. Merkez sunucu

Önerilen merkez: Ubuntu Server LTS + Docker Compose. Sunucuda 80/443 portları erişilebilir olmalı ve `API_DOMAIN` DNS kaydı bu sunucuya yönelmelidir.

Proje klasöründe:

```bash
cp .env.example .env
```

`.env` içinde en az şu değerleri gerçek ve güçlü değerlerle değiştirin:

```env
POSTGRES_PASSWORD=...
JWT_SECRET=...
API_DOMAIN=api.sifains.com
```

`JWT_SECRET` en az 32 karakter olmalı; 64+ rastgele karakter tercih edilir.

Yedek klasörünü hazırlayın:

```bash
sudo mkdir -p /srv/sifa-backup
sudo chown -R "$USER":"$USER" /srv/sifa-backup
```

Sunucuyu başlatın:

```bash
docker compose up -d --build
docker compose ps
```

API container başlarken `0001 -> 0009` migrationlarını otomatik uygular.

Sağlık kontrolü:

```bash
curl https://api.sifains.com/health
```

## 2. İlk yönetici hesabı

V0.24 Testfix1 ile ilk yönetici scripti API image içine dahil edilir.

```bash
docker exec -it sifa-api python /app/scripts/create_first_admin.py
```

E-posta, ad soyad ve en az 8 karakterlik parola istenir. Sonraki kullanıcılar uygulamadaki Yönetim ekranından oluşturulur.

## 3. Veritabanı ve sunucu smoke testi

```bash
docker exec sifa-api python -m app.migrate --check
docker logs --tail 100 sifa-api
```

Host üzerinde proje kaynakları ve gerekli Python ortamı hazırsa ayrıca:

```bash
python3 server/scripts/validate_migrations.py
python3 server/scripts/validate_api_contracts.py
```

## 4. Flutter geliştirme bilgisayarı

`flutter_client` içinde platform klasörleri henüz yoksa önce klasörün bir yedeğini alın, ardından:

Windows geliştirme bilgisayarında Android + Windows için en kolay yol:

```powershell
cd flutter_client
.\bootstrap_windows_android.ps1
```

Komutları elle çalıştırmak isterseniz:

```powershell
flutter create --project-name sifa_kiralik_takip --platforms=android,windows .
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
```

iOS platformu macOS üzerinde hazırlanır:

```bash
cd flutter_client
./bootstrap_ios.sh
```

Bu akış web platformu oluşturmaz. Windows uygulaması için Windows Flutter toolchain; iOS release/signing için macOS + Xcode gerekir.

## 5. İlk çalıştırma

```bash
flutter run --dart-define=API_BASE_URL=https://api.sifains.com
```

Giriş ekranında 2. adımda oluşturulan yönetici hesabını kullanın.

## 6. Zorunlu gerçek test akışı

Aşağıdaki sıra tek tek doğrulanmalıdır:

1. Gerçek müşteri oluşturun; uygulamayı kapatıp açınca müşteri hâlâ görünmeli.
2. Sevkiyat sekmesinden aynı gerçek müşteriyi seçip 500 adet kiralık çıkış oluşturun.
3. İkinci cihazda aynı kayıt görünmeli.
4. Birinci cihaz internet kapalıyken 300 adet iade girsin; kalan 200 hemen yerelde görünmeli.
5. İnternet açılınca işlem tek kez sunucuya gitmeli; ikinci cihazda kalan 200 görünmeli.
6. Aynı müşteriye farklı tarihte ikinci sevkiyat girin; iki Kiralama Takibi kaydı birleşmemeli.
7. Bir malzemenin fiyatını değiştirin; eski fiyat geçmişte kalmalı.
8. Fatura tarihi ve ödeme vadesi girin; vade geçince doğru 1-30 / 31-60 / 61+ grubuna düşmeli.
9. Kira sözleşmesi yükleyin ve tekrar açın. Signed/private indirme bağlantısı çalışmalı.
10. Giden ve gelen sevkiyat belgelerini ilgili harekete bağlayın.
11. Aynı offline işlemin tekrar gönderilmesi çift müşteri/adres/kiralama oluşturmamalı.
12. Android, Windows ve iPhone'da aynı bulut verisi doğrulanmalı.

## 7. Yedek restore testi

Önce gerçek yedek alın:

```bash
server/scripts/backup_local.sh
```

Restore planını değişiklik yapmadan görmek için:

```bash
server/scripts/restore_database.sh --dry-run /srv/sifa-backup/database/YEDEK.dump
```

Gerçek doğrulama seçilen dump'ı `sifa_restore_test` adlı ayrı veritabanına açar; canlı `sifa_kiralik` veritabanını otomatik ezmez.

## 8. V0.24 Testfix1 notları

Bu paket kurulum öncesi taramada bulunan şu sorunları düzeltir:

- Flutter belge URL endpoint'i ile FastAPI route uyumsuzluğu
- signed belge indirme bağlantısı ve minimum istemci sürümü uyumu
- belge upload/açma isteklerinde `X-App-Version` eksikliği
- `payment_due_date` alanının typed Drift cache'e yazılmaması
- kiralama detayı yenilenirken müşteri telefon/not bilgisinin `null` ile ezilmesi
- artımlı sync eventlerinin typed Drift tablolarına uygulanmaması
- müşteri/adres create retry işlemlerinin tam idempotent olmaması
- restore scriptine güvenli `--dry-run` ve ayrı test DB akışı
- sahte demo müşterilerin gerçek kurulum ekranlarında görünmesi
- Sevkiyat sekmesinin kaydedilmeyen demo taslak yerine gerçek Kiralama oluşturma akışını kullanması
- ilk yönetici scriptinin Docker image içinde bulunmaması

V0.24'te hatırlatmalar uygulama içidir. Uygulama tamamen kapalıyken Android/iOS/Windows işletim sistemi bildirimi gönderme entegrasyonu henüz gerçek cihaz izniyle tamamlanmamıştır.
