# Audit → İlgili Kayda Git v0.24

Audit listesi yüklenirken her satır için ayrı ilişki sorgusu yapılmaz.

Kullanıcı audit detayını açtığında:
`GET /audit/{audit_id}/navigation`

tek kaydın hedefini çözer.

Desteklenen hedef örnekleri:
- customer → Müşteri ekranı
- rental_record → Kiralama Takibi
- rental_billing_period → bağlı Kiralama Takibi
- rental_rate → bağlı Kiralama Takibi
- rental_document → bağlı Kiralama Takibi
- rental_movement → bağlı Kiralama Takibi
- document_compliance_exception → bağlı Kiralama Takibi
- sale → bağlı Müşteri

Hedef bulunamazsa audit kaydı yine görüntülenir, sadece navigasyon düğmesi gösterilmez.
