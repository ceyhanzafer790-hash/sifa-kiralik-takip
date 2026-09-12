# Şifa Kiralık Takip PWA / iPhone Kurulumu

Bu sürüm Apple Developer üyeliği gerektirmez. iPhone ve iPad kullanıcıları uygulamayı Safari üzerinden ana ekrana ekler.

## Alan adları

- API: `https://api.sifains.com`
- PWA: `https://app.sifains.com`

Her iki DNS kaydı da merkez sunucuya yönlendirilmelidir. HTTPS sertifikalarını Caddy otomatik yönetir.

## Sunucu hazırlığı

`.env` içinde en az şu değerler bulunmalıdır:

```env
API_DOMAIN=api.sifains.com
PWA_DOMAIN=app.sifains.com
PWA_ORIGIN=https://app.sifains.com
```

PWA derlemesinin `build/web` içeriğini sunucuda `/srv/sifa-pwa` klasörüne kopyalayın. `index.html` doğrudan `/srv/sifa-pwa/index.html` olmalıdır.

Ardından:

```bash
sudo mkdir -p /srv/sifa-pwa
docker compose up -d --build
```

## iPhone / iPad kurulumu

1. Safari'de `https://app.sifains.com` adresini açın.
2. Paylaş düğmesine dokunun.
3. **Ana Ekrana Ekle** seçeneğini seçin.
4. Adı `Şifa Kiralık` olarak bırakıp **Ekle** deyin.
5. Bundan sonra uygulama ana ekrandaki simgeden bağımsız uygulama görünümünde açılır.

Apple Developer hesabı veya yıllık ücret gerekmez.

## PWA davranışı

- Uygulama kabuğu service worker ile önbelleğe alınır.
- Yerel Drift verisi tarayıcı depolamasında tutulur.
- API verileri Android ve Windows istemcileriyle aynı merkez sunucudan gelir.
- Belge yükleme internet bağlantısı varken tarayıcı dosya seçicisiyle yapılır.
- Native sürümdeki çevrimdışı belge dosya kuyruğu PWA'da devre dışıdır; diğer çevrimdışı kayıt/senkron özellikleri yerel veritabanı üzerinden çalışmaya devam eder ve gerçek cihazda ayrıca test edilmelidir.

## Güncelleme

Yeni PWA derlemesinin `build/web` içeriği `/srv/sifa-pwa` üzerine kopyalanır. Kullanıcının uygulamayı yeniden kurması gerekmez; service worker yeni web paketini alır.
