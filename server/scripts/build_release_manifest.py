from __future__ import annotations

import argparse
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", required=True)
    parser.add_argument(
        "--artifact",
        action="append",
        required=True,
        help="platform:path örn. android:/build/app.apk",
    )
    parser.add_argument(
        "--output",
        default="release-manifest.json",
    )
    args = parser.parse_args()

    artifacts = []

    for raw in args.artifact:
        if ":" not in raw:
            raise SystemExit(
                "--artifact platform:path biçiminde olmalı."
            )

        platform, path_raw = raw.split(":", 1)
        platform = platform.strip().lower()
        path = Path(path_raw).expanduser().resolve()

        if platform not in ("android", "windows", "ios"):
            raise SystemExit(
                f"Geçersiz platform: {platform}"
            )

        if not path.is_file():
            raise SystemExit(
                f"Artifact bulunamadı: {path}"
            )

        artifacts.append({
            "version": args.version,
            "platform": platform,
            "file_name": path.name,
            "size_bytes": path.stat().st_size,
            "sha256": sha256(path),
        })

    manifest = {
        "product": "Şifa İnşaat Kiralık Takip",
        "version": args.version,
        "created_at": datetime.now(
            timezone.utc
        ).astimezone().isoformat(),
        "artifacts": artifacts,
    }

    output = Path(args.output).resolve()
    output.write_text(
        json.dumps(
            manifest,
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )

    print(output)
    for item in artifacts:
        print(
            f"{item['platform']}: "
            f"{item['file_name']} "
            f"{item['size_bytes']} bytes "
            f"sha256={item['sha256']}"
        )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
