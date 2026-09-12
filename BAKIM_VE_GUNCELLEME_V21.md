# Bakım ve Güvenli Güncelleme v0.21

`app_runtime_settings` tek merkez çalışma ayarıdır.

Alanlar:
- maintenance_mode
- maintenance_message
- min_client_version
- latest_client_version
- enforce_min_client_version

## Güvenli geçiş

Minimum sürüm zorunluluğu varsayılan olarak KAPALI gelir.

Önerilen akış:
1. v0.21 cihazlara kurulur
2. bütün aktif cihazlar kontrol edilir
3. `latest_client_version` güncellenir
4. gerekirse minimum sürüm belirlenir
5. en son `enforce_min_client_version` açılır

Eski istemci zorunluluk açıkken `426 Upgrade Required` alır.

## Sunucu güncellemesi

```bash
server/scripts/safe_upgrade.sh
```

Sıra:
1. yerel DB + belge yedeği
2. bakım modu
3. yeni API build
4. migration
5. health + migration check
6. başarılıysa bakım modunu kapat

Hata olursa bakım modu açık bırakılır.
