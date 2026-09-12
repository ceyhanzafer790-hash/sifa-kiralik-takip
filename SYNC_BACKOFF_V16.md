# Senkron Retry Backoff v0.16

Başarısız işlem her dakika körlemesine denenmez.

Bekleme dizisi:
1 dk → 2 dk → 5 dk → 15 dk → 30 dk → 60 dk

Hem JSON işlem kuyruğu hem belge yükleme kuyruğu bu mantığı kullanır.
