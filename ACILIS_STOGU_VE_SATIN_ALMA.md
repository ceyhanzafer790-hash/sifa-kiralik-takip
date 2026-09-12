# Açılış Stoğu ve Satın Alma v0.13

## Açılış Stoğu

Bir ürün sistemde ilk kez takip edilmeye başlanıyorsa kullanılabilir.

Örnek:
- bugün direkleri sisteme ilk kez alıyoruz
- yaklaşık 10.000 direk var
- `opening +10000`

Ancak bu üründe daha önce herhangi bir stok hareketi varsa sunucu ikinci kez
açılış stoğuna izin vermez.

Bu durumda doğru yöntem:
- fiziksel sayım
- sayım düzeltmesi

## Satın Alma

Sonradan alınan yeni malzeme:

`purchase + miktar`

hareketi oluşturur.

Satın almada isteğe bağlı:
- tedarikçi
- fatura no
- birim alış maliyeti
- not
saklanır.
