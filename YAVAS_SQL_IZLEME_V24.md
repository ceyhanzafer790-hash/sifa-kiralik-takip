# Yavaş SQL İzleme v0.24

Varsayılan eşik:
`DB_SLOW_QUERY_MS=500`

Her `execute` / `executemany` süresi ölçülür.

System Health metrikleri:
- toplam sorgu
- yavaş sorgu sayısı
- en uzun sorgu süresi
- son yavaş sorgu zamanı
- yavaş sorgu eşiği

Log güvenliği:
- SQL parametreleri loglanmaz.
- JWT/parola/request body loglanmaz.
- Yavaş sorguda yalnız normalize edilmiş SQL şablonu ve süre tutulur.

Eşik `.env` üzerinden değiştirilebilir.
