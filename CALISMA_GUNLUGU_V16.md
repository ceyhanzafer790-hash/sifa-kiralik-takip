# Çalışma Günlüğü v0.16

1. Sessiz son-yazan-kazan davranışı riskli bulundu, row_version çakışma kontrolü eklendi.
2. Kira dönemi/fatura/tahsilat offline-first yapıya taşındı.
3. Offline dönem güncellemesi UUID yerine kiralama + yenileme tarihiyle eşleşebilir hale geldi.
4. Senkron hata tekrarları artan bekleme süreli hale getirildi.
5. Aynı sözleşme/sevkiyat belgesinin yanlışlıkla iki kez yüklenmesini önlemek için SHA-256 eklendi.
