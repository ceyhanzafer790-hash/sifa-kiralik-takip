"""Register Şifa's custom service worker in the generated Flutter web shell."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
index_path = ROOT / "flutter_client" / "web" / "index.html"
index = index_path.read_text(encoding="utf-8")

needle = '  <script src="sql-wasm.js"></script>\n  <script src="flutter_bootstrap.js" async></script>'
registration = '''  <script src="sql-wasm.js"></script>
  <script>
    if ('serviceWorker' in navigator) {
      window.addEventListener('load', () => {
        navigator.serviceWorker
          .register('sifa_service_worker.js', { scope: './' })
          .catch((error) => console.warn('Şifa PWA service worker kaydı başarısız:', error));
      });
    }
  </script>
  <script src="flutter_bootstrap.js" async></script>'''

if needle not in index:
    raise RuntimeError("PWA bootstrap insertion point was not found in web/index.html")

index_path.write_text(index.replace(needle, registration, 1), encoding="utf-8")
print("Custom Şifa service worker registration added.")
