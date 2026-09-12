from __future__ import annotations

import argparse
import json
from pathlib import Path

from legacy_parser import parse_file

SUPPORTED = {".xlsx", ".xlsm"}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "path",
        help="Bir Excel dosyası veya Excel klasörü",
    )
    args = parser.parse_args()

    target = Path(args.path).resolve()
    if not target.exists():
        raise SystemExit(f"Bulunamadı: {target}")

    if target.is_file():
        files = [target]
    else:
        files = [
            p for p in target.rglob("*")
            if p.is_file()
            and p.suffix.lower() in SUPPORTED
            and not p.name.startswith("~$")
        ]

    summary = []
    for path in files:
        result = parse_file(path)
        excel = result.get("excel") or {}

        suggestions = []
        for sheet in excel.get("sheets", []):
            suggestions.append({
                "sheet": sheet.get("name"),
                "mapping": sheet.get("mapping_suggestion"),
            })

        summary.append({
            "file": path.name,
            "detected_customer_name":
                result.get("detected_customer_name"),
            "detected_date": result.get("detected_date"),
            "suggestions": suggestions,
        })

    print(json.dumps(summary, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
