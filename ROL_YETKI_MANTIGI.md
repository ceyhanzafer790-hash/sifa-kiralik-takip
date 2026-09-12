# Rol ve Yetki Mantığı v0.11

## Admin
- tüm kayıtları görür
- müşteri ekler
- kiralama/satış/iade/fiyat/fatura/tahsilat girer
- belge ekler
- stok sayımı ve stok durum hareketleri girer
- kullanıcı yönetimi ileride yalnız Admin'e açılacak

## Staff
- operasyonel kayıtları görür ve ekler
- kiralama/satış/iade/fiyat/belge/stok işlemleri yapar
- kullanıcı yönetemez

## Viewer
- tüm yetkili veriyi okuyabilir
- yeni kayıt ekleyemez
- iade/fiyat/fatura/belge/stok hareketi oluşturamaz

Önemli:
Sadece butonu gizlemek güvenlik değildir.

UI butonları kapatılır ama asıl güvenlik sunucudaki `require_write`
kontrolüdür. Viewer değiştirilmiş bir uygulamayla API'ye yazmaya çalışsa bile
sunucu 403 döndürür.
