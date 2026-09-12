# Çalışma Günlüğü v0.21

1. Navigation rol bazlı hale getirildi; Yönetim yetkisiz kullanıcıya artık gösterilmiyor.
2. Staff bakım modunda salt-okunur menüye düşüyor.
3. Client bütün API isteklerinde X-App-Version gönderiyor.
4. Minimum istemci sürümü ve 426 Upgrade Required altyapısı eklendi.
5. Minimum sürüm zorunluluğu güvenli geçiş için varsayılan kapalı.
6. Finansal dashboard değerleri yalnız UI'da değil sunucu cevabında da Admin'e özel.
7. Admin-only alacak detay ve tahmini kira müşteri/şantiye dağılımı eklendi.
8. Fatura/Tahsilat raporu ve müşteri hesap ekstresi Admin'e çekildi.
9. Eski belge uyumluluk istisnası, gerekçe, audit ve geri alma desteği eklendi.
10. Rutin backup_local.sh içindeki eski v0.6 Docker volume adı düzeltildi.
11. Yedek → bakım → build/migration → health → bakım kapat sıralı safe_upgrade.sh eklendi.
12. 0006 runtime settings + document compliance exceptions migration eklendi.
13. backup_local.sh yeniden yazıldı; OneDrive durum alanlarını artık ezmiyor.
14. İlk runtime-table öncesi güncellemede Caddy kapatma fallback'i eklendi.
15. safe_upgrade sağlık testinde docker exec stdin için -i düzeltildi.
16. Felaket kurtarma manifest sürümü 0.21.0 olarak güncellendi.
17. Sistem Sağlığı toplamında log disk kritik/uyarı seviyesi de hesaba katılıyor.

