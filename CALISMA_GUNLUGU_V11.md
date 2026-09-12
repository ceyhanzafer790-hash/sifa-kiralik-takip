# Çalışma Günlüğü v0.11

Bu turdaki kararlar:

1. Viewer rolünde yalnız buton gizlemekle yetinilmedi.
   Sunucudaki yazma yetkisi zaten `require_write` ile korunuyor; istemci de buna
   uygun hale getirildi.

2. Offline belgelerde orijinal dosya yoluna güvenmenin riskli olduğu kabul edildi.
   Dosya uygulamanın kalıcı destek klasörüne kopyalanıyor.

3. Belge kuyruğu diğer veri kuyruğundan ayrıldı.
   Çünkü dosya byte aktarımı normal JSON işleminden farklı hata/yeniden deneme
   davranışı gerektiriyor.

4. Tamirden çıkan ürün hareketi iki satırla tutuluyor:
   repair -X, available +X.
   Böylece stok kovalarının toplamı açıklanabilir kalıyor.

5. Hurda ve kayıp yine doğrudan stok alanını ezmiyor.
   Kaynak kovadan eksi, hedef kovaya artı hareket oluşuyor.
