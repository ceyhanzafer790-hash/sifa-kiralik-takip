> **ESKİ / KULLANILMAYAN REHBER:** Bu dosya v0.5 tarihçesidir. v0.24 Supabase kullanmaz. Güncel sistem FastAPI + PostgreSQL + Caddy kullanır. Kurulum için proje kökündeki `KURULUM_V24_TESTFIX1.md` dosyasını izleyin.

# Supabase Kurulum Sırası - Şifa İnşaat v0.5

Bu sürüm ilk kez gerçek ortak bulut yapısına geçmek için hazırlanmıştır.

## 1. Supabase projesi oluştur

Yeni bir Supabase projesi oluştur.

## 2. SQL Editor

`supabase_schema.sql` dosyasının tamamını SQL Editor'da çalıştır.

Bu işlem:
- 48 ürünü oluşturur
- müşteri/kiralama/iade/fiyat/fatura/belge tablolarını kurar
- özel belge Storage alanını açar
- Realtime tablolarını etkinleştirir
- admin/staff/viewer yetkilerini kurar

## 3. Authentication

Supabase Authentication altında e-posta/şifre girişini kullan.

Güvenlik için kullanıcıların kendi kendine kayıt olmasını kapalı tut.
Personel hesapları yönetici tarafından oluşturulsun/davet edilsin.

## 4. İlk yönetici

İlk kullanıcı hesabını oluşturduktan sonra kullanıcının UUID'sini al.

SQL Editor'da:

```sql
insert into profiles (id, full_name, role)
values ('KULLANICI_UUID', 'Zafer', 'admin');
```

## 5. Personel

Personel hesabı oluşturulduktan sonra:

```sql
insert into profiles (id, full_name, role)
values ('PERSONEL_UUID', 'Personel Adı', 'staff');
```

Sadece bakacak kullanıcı:

```sql
insert into profiles (id, full_name, role)
values ('KULLANICI_UUID', 'Kullanıcı Adı', 'viewer');
```

## 6. Flutter bağlantısı

Supabase Project Settings -> API içinden:
- Project URL
- anon/public key

alınır.

Uygulama:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://PROJE.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=ANON_KEY
```

ile çalıştırılır.

## Yetki düzeni

| Rol | Görüntüleme | Giden/Gelen | Fiyat | Belge yükleme | Silme / yönetim |
|---|---|---|---|---|---|
| Yönetici | Evet | Evet | Evet | Evet | Evet |
| Personel | Evet | Evet | Evet | Evet | Kısıtlı |
| Sadece görüntüleme | Evet | Hayır | Hayır | Hayır | Hayır |

## Güvenlik notu

`service_role` anahtarı uygulamanın içine KESİNLİKLE konmaz.
Mobil/Windows uygulamasında yalnızca `anon` anahtar kullanılır.
Asıl erişim güvenliği RLS politikalarıyla sağlanır.
