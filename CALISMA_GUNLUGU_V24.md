# Çalışma Günlüğü v0.24

1. Gerçek fatura ödeme vadesi alanı PostgreSQL'e eklendi.
2. Vade yalnız kesilmiş faturada kullanılabiliyor ve fatura tarihinden önce olamıyor.
3. Vade explicit null ile kaldırılabiliyor.
4. Drift local billing tablosuna paymentDueDate eklendi; schemaVersion 6.
5. Offline billing kuyruğu vade ekleme/değiştirme/kaldırmayı taşıyor.
6. Fatura ekranı yeniden düzenlendi; fatura tarihi ve ödeme vadesi ayrı seçiliyor.
7. Fatura bilgisi düzenlenirken eski fatura tarihi otomatik bugüne çevrilmiyor.
8. Gerçek vadesi geçmiş alacak API/ekranı ve 1-30 / 31-60 / 61+ grupları eklendi.
9. Dashboard'daki finans kartı gerçek payment_due_date üzerinden overdue gösteriyor.
10. Yavaş SQL süre ölçümü ve System Health metrikleri eklendi.
11. SQL parametreleri loglanmıyor.
12. Audit detayından ilgili müşteri/kiralama kaydına geçiş eklendi.
13. v0.23 SystemStatus içindeki kopya _downloadDiagnostics metodu temizlendi.
14. Admin Üretime Hazırlık API ve ekranı eklendi.
15. Tek parça üretime hazırlık kontrol listesi oluşturuldu.
16. 0009 payment_due_date migration eklendi.

## Testfix1 — kurulum öncesi statik denetim

17. Flutter istemcisinin beklediği `/documents/{id}/url` endpoint'i eklendi.
18. Belge açma için 5 dakikalık, belge kimliğine bağlı süreli token üretildi; signed-download minimum client version filtresinden güvenli şekilde muaf tutuldu.
19. Signed URL relative path dönecek şekilde düzenlendi; Flutter kendi `API_BASE_URL` değeriyle birleştiriyor.
20. Buluttan kiralama detayı yenilenirken `payment_due_date` Drift'e yazılmama hatası düzeltildi.
21. Offline billing detail map'e `payment_due_date`, snapshot, row_version ve pending_sync eklendi.
22. Kiralama detayı yenilenirken yerel müşteri telefon/not alanlarının null ile ezilmesi engellendi.
23. Incremental sync eventleri artık customer/customer_address typed cache'e uygulanıyor; rental/billing/document eventlerinde ilgili kiralama bir kez sunucudan yenileniyor. Cursor yalnız başarılı uygulamadan sonra ilerliyor.
24. `validate_api_contracts.py` eklendi ve offline preflight'a bağlandı.
25. `restore_database.sh --dry-run` eklendi; gerçek çalışmada da canlı DB yerine ayrı `sifa_restore_test` veritabanına doğrulama yapıldığı açıklaştırıldı.
26. Hatırlatma Merkezi V0.24'ün uygulama içi hatırlatma kullandığını ve OS bildiriminin henüz aktif olmadığını açıkça gösteriyor.

27. Müşteri listesi ve Sevkiyat ekranındaki sahte demo müşteri fallback'i kaldırıldı.
28. Sevkiyat sekmesi kaydedilmeyen demo taslak yerine gerçek müşteri seçip `RentalCreateScreen` üzerinden offline-safe Kiralama kaydı oluşturuyor.
29. İlk yönetici oluşturma scripti Docker API image içine dahil edildi; `docker exec -it sifa-api python /app/scripts/create_first_admin.py` ile çalıştırılabilir.
30. Docker Compose DB pool/yavaş sorgu/release platform ayarları `.env` değerlerini gerçekten kullanacak hale getirildi.
31. Eski Supabase kurulum belgeleri legacy olarak işaretlendi; güncel `KURULUM_V24_TESTFIX1.md` eklendi.
