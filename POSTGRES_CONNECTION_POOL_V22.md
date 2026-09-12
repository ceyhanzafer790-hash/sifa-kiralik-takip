# PostgreSQL Connection Pool v0.22

Eski yapı her `db()` kullanımında yeni PostgreSQL bağlantısı açıyordu.

v0.22:
- `psycopg_pool.ConnectionPool`
- varsayılan minimum: 2
- varsayılan maksimum: 10
- bağlantı bekleme timeout: 10 saniye

Ortam değişkenleri:
- `DB_POOL_MIN_SIZE`
- `DB_POOL_MAX_SIZE`
- `DB_POOL_TIMEOUT_SECONDS`

FastAPI lifespan:
- uygulama başlarken pool açılır
- uygulama kapanırken pool temiz kapatılır

Sistem Durumu:
- pool size
- bekleyen istek sayısı

gibi `pool.get_stats()` metriklerini gösterebilir.

Not:
Bu çalışma ortamında `psycopg_pool` kurulu değildir. Docker/PC kurulumunda
`psycopg[binary,pool]==3.2.3` requirements üzerinden kurulduktan sonra gerçek
bağlantı ve yük testi yapılacaktır.
