# Yönetici Kullanıcı Sistemi v0.12

Yalnız Admin:

- kullanıcı listesini görür
- yeni kullanıcı oluşturur
- Admin / Staff / Viewer rolü verir
- hesabı aktif/pasif yapar
- kullanıcı şifresini yeniler
- audit kayıtlarını görüntüler

Koruma:

- Admin kendi hesabını yanlışlıkla pasif yapamaz.
- Admin kendi yönetici rolünü bu endpoint üzerinden düşüremez.
- Şifreler düz metin saklanmaz, bcrypt hash saklanır.
- E-posta küçük/büyük harfe duyarsız benzersiz tutulur.
