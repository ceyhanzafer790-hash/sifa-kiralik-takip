from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("manifest")
    parser.add_argument(
        "--artifact-dir",
        default=".",
        help="Build dosyalarının bulunduğu klasör.",
    )
    args = parser.parse_args()

    manifest_path = Path(args.manifest).resolve()
    artifact_dir = Path(args.artifact_dir).resolve()

    data = json.loads(
        manifest_path.read_text(encoding="utf-8")
    )

    failures = []

    for item in data.get("artifacts", []):
        path = artifact_dir / item["file_name"]

        if not path.is_file():
            failures.append(
                f"{item['file_name']}: dosya bulunamadı"
            )
            continue

        size = path.stat().st_size
        digest = sha256(path)

        if size != int(item["size_bytes"]):
            failures.append(
                f"{path.name}: boyut uyuşmuyor"
            )

        if digest.lower() != item["sha256"].lower():
            failures.append(
                f"{path.name}: SHA-256 uyuşmuyor"
            )

        if not failures:
            print(
                f"OK {item['platform']} {path.name} "
                f"sha256={digest}"
            )

    if failures:
        print("RELEASE DOĞRULAMA BAŞARISIZ")
        for failure in failures:
            print(f"- {failure}")
        return 1

    print("Bütün release artifactları manifest ile uyumlu.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
