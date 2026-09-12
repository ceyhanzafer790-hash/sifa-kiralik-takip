# Üretim Log Sistemi v0.20

API logları:
`/data/logs/sifa-api.jsonl`

Tutulanlar:
- tarih/saat
- seviye
- request_id
- HTTP method
- path
- status code
- süre (ms)
- istemci IP

Tutulmayanlar:
- Authorization/JWT
- parola
- request body
- belge içeriği

Rotasyon:
- 10 MB dosya
- 10 eski dosya
- Docker `logs_data` volume
- console log devam eder

Her API yanıtında `X-Request-ID` bulunur.
