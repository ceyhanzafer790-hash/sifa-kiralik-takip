# Çalışma Günlüğü v0.22

1. db.py her istekte yeni connection açmaktan psycopg connection pool mimarisine geçti.
2. Pool min/max/timeout ortam değişkenleri eklendi.
3. FastAPI lifespan ile pool açılış/kapanış yönetimi eklendi.
4. Audit API kullanıcı/entity/action/tarih/serbest metin filtreleri ve pagination aldı.
5. Audit ekranı faceted filtre, arama ve 100 kayıtlık sayfalama aldı.
6. 0007 migration audit indexleri ve app_releases tablosunu ekledi.
7. Alacak ekranına müşteri, tarih ve metin filtresi eklendi.
8. Tahmini kira dağılımına müşteri/şantiye/malzeme araması ve kalem detayı eklendi.
9. Release artifactları için SHA-256 + boyut manifest üretici ve doğrulayıcı eklendi.
10. Admin Sürüm Paketleri ekranı eklendi.
11. Beklenmeyen 500 hataları kontrollü response ve X-Request-ID ile yönetiliyor.
12. Client ApiException request ID tutuyor ve kullanıcıya gösterebiliyor.
13. System Health PostgreSQL pool istatistiklerini döndürüyor.
14. Runtime latest-version fallback 0.22.0'a güncellendi.
