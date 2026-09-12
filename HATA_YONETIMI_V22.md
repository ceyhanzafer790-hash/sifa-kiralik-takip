# Üretim Hata Yönetimi v0.22

Beklenmeyen backend exception kullanıcıya traceback olarak gönderilmez.

HTTP 500 cevabı:
- `code = internal_error`
- kısa kullanıcı mesajı
- request_id

içerir.

API cevabında ayrıca:
`X-Request-ID`

header'ı bulunur.

İstemci request ID'yi `ApiException` içinde saklar ve kullanıcı mesajında gösterebilir.

Özel iş kodları:
- maintenance_mode
- client_update_required
- row_version_conflict
- operation_already_processed
- internal_error

Loglarda traceback request ID ile bulunur.

JWT, parola, request body ve belge içeriği loglanmaz.
