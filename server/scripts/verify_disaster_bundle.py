import hashlib
import json
import sys
import tarfile
import tempfile
from pathlib import Path

def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def main() -> int:
    if len(sys.argv) != 2:
        print("Kullanım: python3 verify_disaster_bundle.py <sifa_disaster_....tar.gz>")
        return 2

    bundle = Path(sys.argv[1]).resolve()
    if not bundle.exists():
        print(f"Paket bulunamadı: {bundle}")
        return 2

    with tempfile.TemporaryDirectory(prefix="sifa_verify_") as td:
        target = Path(td)
        with tarfile.open(bundle, "r:gz") as tar:
            tar.extractall(target)

        manifest_path = target / "manifest.json"
        if not manifest_path.exists():
            print("HATA: manifest.json yok.")
            return 1

        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        failures = []

        for item in manifest.get("files", []):
            p = target / item["name"]
            if not p.exists():
                failures.append(f"{item['name']}: dosya yok")
                continue

            actual_size = p.stat().st_size
            actual_hash = sha256(p)

            if actual_size != item["size_bytes"]:
                failures.append(
                    f"{item['name']}: boyut uyuşmuyor "
                    f"({actual_size} != {item['size_bytes']})"
                )
            if actual_hash != item["sha256"]:
                failures.append(
                    f"{item['name']}: SHA-256 uyuşmuyor"
                )

        if failures:
            print("PAKET DOĞRULANAMADI")
            for f in failures:
                print(f"- {f}")
            return 1

        print("Paket manifest ve SHA-256 kontrolünden geçti.")
        print(f"Uygulama sürümü: {manifest.get('app_version')}")
        print(f"Oluşturulma: {manifest.get('created_at')}")
        print("Sonraki adım: database.dump ayrı test veritabanında pg_restore ile denenmeli.")
        return 0

if __name__ == "__main__":
    raise SystemExit(main())
