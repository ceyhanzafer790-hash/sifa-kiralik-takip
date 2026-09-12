from __future__ import annotations

import argparse
import json
import os
import shutil
from pathlib import Path

import psycopg
from psycopg.rows import dict_row

from legacy_parser import parse_file

SUPPORTED = {
    ".xlsx", ".xlsm",
    ".pdf",
    ".jpg", ".jpeg", ".png",
    ".doc", ".docx",
}

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", help="Eski dosyaların bulunduğu klasör")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Veritabanına yazmadan tespitleri ekrana bas",
    )
    args = parser.parse_args()

    source = Path(args.source).resolve()
    if not source.is_dir():
        raise SystemExit(f"Klasör bulunamadı: {source}")

    import_root = Path(
        os.environ.get("IMPORT_ROOT", "/data/import-inbox")
    ).resolve()
    raw_root = import_root / "raw"

    files = [
        p for p in source.rglob("*")
        if p.is_file()
        and p.suffix.lower() in SUPPORTED
        and not p.name.startswith("~$")
    ]

    print(f"Bulunan desteklenen dosya: {len(files)}")

    if args.dry_run:
        for path in files:
            print(json.dumps(
                parse_file(path),
                ensure_ascii=False,
            ))
        return 0

    database_url = os.environ.get("DATABASE_URL")
    if not database_url:
        raise SystemExit("DATABASE_URL ortam değişkeni gerekli.")

    raw_root.mkdir(parents=True, exist_ok=True)

    inserted = 0
    skipped = 0

    with psycopg.connect(database_url, row_factory=dict_row) as conn:
        with conn.cursor() as cur:
            for path in files:
                info = parse_file(path)
                digest = info["sha256"]
                ext = path.suffix.lower()
                stored = raw_root / f"{digest}{ext}"

                if not stored.exists():
                    shutil.copy2(path, stored)

                cur.execute(
                    """
                    insert into legacy_import_items(
                        source_file_name,
                        source_path,
                        source_sha256,
                        parser_json,
                        source_kind,
                        detected_customer_name,
                        detected_date,
                        import_status
                    )
                    values (%s, %s, %s, %s, %s, %s, %s, 'pending_match')
                    on conflict do nothing
                    returning id
                    """,
                    (
                        path.name,
                        str(stored),
                        digest,
                        json.dumps(info, ensure_ascii=False),
                        info["source_kind"],
                        info.get("detected_customer_name"),
                        info.get("detected_date"),
                    ),
                )
                if cur.fetchone():
                    inserted += 1
                else:
                    skipped += 1

        conn.commit()

    print(f"Staging'e yeni eklenen: {inserted}")
    print(f"Hash nedeniyle atlanan tekrar dosya: {skipped}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
