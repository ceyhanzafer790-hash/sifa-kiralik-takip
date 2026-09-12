# Stabil ID ve Senkron Onayı v0.15

Cihaz ve sunucu artık müşteri, adres, kiralama, kiralık malzeme satırı, giden hareketi,
iade hareketi, fiyat satırı ve satış için aynı UUID'leri kullanır.

Başarılı push sonrası SyncWorker ilgili typed Drift kaydındaki `pendingSync` işaretini
hemen temizler.
