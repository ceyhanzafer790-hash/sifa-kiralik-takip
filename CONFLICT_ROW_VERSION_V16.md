# Çakışma Koruması v0.16

Mutable kayıtlar `row_version` taşır. Cihaz değişiklik gönderirken elindeki sürümü de
gönderir. Sunucudaki sürüm farklıysa 409 Conflict döner ve eski cihazın değişikliği
sessizce yeni veriyi ezmez.

İlk uygulanan alanlar:
- Kiralama Takibi faturalı/faturasız tercihi
- kira dönemi fatura/tahsilat bilgileri
