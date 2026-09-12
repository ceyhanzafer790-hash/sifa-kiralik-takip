from __future__ import annotations

import argparse
import json
import os
import urllib.error
import urllib.request
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-url", required=True)
    parser.add_argument("--manifest", required=True)
    parser.add_argument(
        "--download-base",
        default=None,
        help=(
            "Opsiyonel public download kökü. "
            "Örn: https://download.sifains.com/releases/0.23.0"
        ),
    )
    args = parser.parse_args()

    token = os.environ.get("SIFA_ADMIN_TOKEN")
    if not token:
        raise SystemExit(
            "SIFA_ADMIN_TOKEN ortam değişkeni tanımlı değil."
        )

    manifest = json.loads(
        Path(args.manifest).read_text(encoding="utf-8")
    )

    base_url = args.base_url.rstrip("/")

    for item in manifest.get("artifacts", []):
        download_path = None
        if args.download_base:
            download_path = (
                args.download_base.rstrip("/")
                + "/"
                + item["file_name"]
            )

        payload = {
            "version": item["version"],
            "platform": item["platform"],
            "file_name": item["file_name"],
            "sha256": item["sha256"],
            "size_bytes": item["size_bytes"],
            "download_path": download_path,
            "release_notes": None,
            "mandatory": False,
        }

        request = urllib.request.Request(
            base_url + "/admin/releases",
            data=json.dumps(payload).encode("utf-8"),
            headers={
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json",
                "X-App-Version": item["version"],
            },
            method="POST",
        )

        try:
            with urllib.request.urlopen(
                request,
                timeout=20,
            ) as response:
                body = response.read().decode("utf-8")
                print(
                    f"OK {item['platform']} "
                    f"{item['file_name']} "
                    f"HTTP {response.status}"
                )
                if body:
                    print(body)
        except urllib.error.HTTPError as exc:
            body = exc.read().decode(
                "utf-8",
                errors="replace",
            )
            print(
                f"HATA {item['platform']} "
                f"{item['file_name']} "
                f"HTTP {exc.code}: {body}"
            )
            return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
