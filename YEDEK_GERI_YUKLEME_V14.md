# Yedek Sağlığı ve Geri Yükleme v0.14

## Yedek sağlık ekranı

Admin → Yönetim → Yedek Sağlığı

gösterir:

- son başarılı yerel PostgreSQL yedeği
- son başarılı OneDrive şifreli yedeği
- zaman bilgisi

## Yedek doğrulama

Sunucuda:

```bash
./server/scripts/test_latest_backup.sh
```

En son `.dump` dosyasını geçici `sifa_backup_test` veritabanına açar.
Tablolar okunabiliyorsa test DB'sini siler.

Bu önemli: dosyanın var olması yedeğin gerçekten açılabildiği anlamına gelmez.

## Geri yükleme güvenliği

`restore_database.sh` canlı veritabanını körlemesine ezmez.

Önce verilen yedeği ayrı test veritabanına açar. Canlıya geri dönüş daha sonra
kontrollü bakım işlemi olarak yapılır.

İnsanların "yedek varmış" deyip bozuk yedeği felaket günü fark etmesi pek hoş bir
gelenek olmadığı için, doğrulama ayrı tutuldu.
