# rclone ile şirket OneDrive bağlantısı

Ubuntu sunucuda:

```bash
sudo apt install rclone restic
rclone config
```

Yeni remote oluştur:
- isim: `onedrive`
- tür: Microsoft OneDrive
- şirket hesabıyla giriş yap
- gerekiyorsa ortak/SharePoint belge kitaplığını seç

Test:

```bash
rclone lsd onedrive:
```

Sonra `.env`/backup ortamında:

```text
RCLONE_REMOTE=onedrive
RCLONE_PATH=Sifa-Insaat/Uygulama-Yedekleri/Kiralik-Takip/restic
RESTIC_PASSWORD=uzun-ve-ayri-bir-yedek-sifresi
```

Bu parola kaybolursa şifreli restic yedeği açılamaz.
Parolayı ayrıca fiziksel/şifre yöneticisi gibi ikinci güvenli yerde sakla.
