# Şifa İnşaat Kiralık Takip
# Üretime Hazırlık Kontrol Listesi v0.24

Uygulama gerçek kullanıma alınmadan önce aşağıdaki maddeler kapatılmalıdır.

## Sunucu
- [ ] Ayrılmış sunucu/mini PC belirlendi.
- [ ] Ubuntu Server + Docker kurulumu tamamlandı.
- [ ] PostgreSQL container kalıcı volume ile çalışıyor.
- [ ] `0001 → 0009` migration zinciri gerçek DB'de geçti.
- [ ] `psycopg_pool` gerçek runtime testi geçti.
- [ ] DB pool yük altında test edildi.
- [ ] `DB_SLOW_QUERY_MS` gözlemlendi ve uygun eşik doğrulandı.
- [ ] HTTPS aktif ve sertifika yenilemesi çalışıyor.
- [ ] Sunucu yeniden başlatma testi geçti.

## Güvenlik
- [ ] JWT_SECRET benzersiz ve en az 32 karakter.
- [ ] Varsayılan/test parolaları yok.
- [ ] Admin / Staff / Viewer yetki testleri geçti.
- [ ] Staff bakım modunda yazamıyor.
- [ ] Viewer hiçbir yazma endpoint'ine erişemiyor.
- [ ] Minimum client version koruması bütün cihazlar güncellendikten sonra test edildi.
- [ ] Teşhis ZIP'i tekrar incelendi; secret/JWT/IP/belge içeriği yok.

## Flutter istemci
- [ ] `flutter pub get` geçti.
- [ ] Drift `build_runner` üretimi geçti.
- [ ] `flutter analyze` temiz veya kabul edilen uyarılar belgeli.
- [ ] Windows release build alındı.
- [ ] Android imzalı release build alındı.
- [ ] iOS release/signing akışı tamamlandı.
- [ ] Her artifact SHA-256 manifest ile doğrulandı.
- [ ] Admin Sürüm Paketleri ekranında gerçek artifactlar kayıtlı.

## Senkron testi
- [ ] Cihaz A müşteri/kiralama oluşturdu, cihaz B'de göründü.
- [ ] 500 adet çıkış → 300 iade → kalan 200 doğrulandı.
- [ ] Aynı müşterinin farklı tarihteki kiralamaları ayrı kaldı.
- [ ] İnternet kapalıyken hareket girildi.
- [ ] İnternet açılınca tek kayıt olarak senkronlandı.
- [ ] Aynı işlem tekrar gönderildiğinde çift kayıt oluşmadı.
- [ ] Row-version çakışma ekranı gerçek iki cihazla test edildi.

## Fatura ve finans
- [ ] Fatura dönemi snapshot geçmiş fiyatı koruyor.
- [ ] Fatura tarihi manuel seçilebiliyor.
- [ ] Ödeme vadesi ekleme/değiştirme/kaldırma test edildi.
- [ ] Vade yokken "vadesi geçmiş" etiketi oluşmuyor.
- [ ] Vade geçince gerçek overdue ekranına düşüyor.
- [ ] Kısmi tahsilat ve tam tahsilat bakiyesi doğru.
- [ ] Tahmini kira ile kesilmiş fatura alacağı birbirine karışmıyor.

## Belgeler
- [ ] Kira sözleşmesi upload testi geçti.
- [ ] Giden sevkiyat belgesi doğru harekete bağlandı.
- [ ] Gelen/iade belgesi doğru harekete bağlandı.
- [ ] Offline belge kuyruğu gerçek cihazda test edildi.
- [ ] Kamera/galeri seçimi Android ve iPhone'da test edildi.
- [ ] SHA-256 duplicate kontrolü test edildi.
- [ ] Signed/private indirme bağlantısı test edildi.

## Yedek ve felaket kurtarma
- [ ] Yerel ikinci kopya yedeği çalışıyor.
- [ ] OneDrive şifreli/versioned yedek çalışıyor.
- [ ] Yedek yaşları Sistem Durumu'nda doğru görünüyor.
- [ ] Boş bir PostgreSQL'e gerçek DB restore edildi.
- [ ] Belgeler yedekten geri getirildi.
- [ ] Restore sonrası uygulama açıldı ve örnek kayıt doğrulandı.
- [ ] Felaket kurtarma prosedürü en az bir kez baştan sona uygulandı.

## Eski veri aktarımı
- [ ] Eski Excel/sözleşme/sevkiyat dosyaları hash ile tarandı.
- [ ] Kesin eşleşenler otomatik aktarıldı.
- [ ] Belirsizler `needs_review` kuyruğunda bırakıldı.
- [ ] Tarihler bugünün tarihiyle değiştirilmedi.
- [ ] Rastgele müşteri/kiralama eşleştirmesi yapılmadı.

Tüm kritik maddeler tamamlanmadan canlı şirket verisiyle üretim kullanımı başlatılmamalıdır.
