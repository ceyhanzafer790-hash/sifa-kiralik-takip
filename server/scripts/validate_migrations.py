from __future__ import annotations

import hashlib
import re
from pathlib import Path

MIGRATION_RE = re.compile(
    r"^(?P<version>\d{4})_(?P<name>[a-z0-9_]+)\.sql$"
)


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    h.update(path.read_bytes())
    return h.hexdigest()


def main() -> int:
    root = Path(__file__).resolve().parent.parent / "migrations"
    files = sorted(p for p in root.glob("*.sql") if not p.name.startswith("_"))

    if not files:
        print("HATA: migration dosyası yok.")
        return 1

    seen = set()
    previous = None

    for path in files:
        match = MIGRATION_RE.match(path.name)
        if not match:
            print(f"HATA: geçersiz dosya adı: {path.name}")
            return 1

        version = int(match.group("version"))

        if version in seen:
            print(f"HATA: tekrar migration sürümü: {version:04d}")
            return 1

        if previous is not None and version <= previous:
            print("HATA: migration sırası bozuk.")
            return 1

        sql = path.read_text(encoding="utf-8").strip()
        if not sql:
            print(f"HATA: boş migration: {path.name}")
            return 1

        seen.add(version)
        previous = version

        print(
            f"OK {path.name} "
            f"sha256={sha256(path)[:12]} "
            f"bytes={path.stat().st_size}"
        )

    print(f"Migration dosya sayısı: {len(files)}")
    print(f"Son migration: {previous:04d}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
