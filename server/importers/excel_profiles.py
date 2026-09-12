from __future__ import annotations

import json
import re
import unicodedata
from pathlib import Path
from typing import Any

PROFILE_DIR = Path(__file__).resolve().parent / "profiles"


def normalize(value: Any) -> str:
    if value is None:
        return ""

    text = str(value).strip().lower()
    text = text.replace("ı", "i")
    text = text.replace("ş", "s")
    text = text.replace("ğ", "g")
    text = text.replace("ü", "u")
    text = text.replace("ö", "o")
    text = text.replace("ç", "c")

    text = unicodedata.normalize("NFKD", text)
    text = "".join(c for c in text if not unicodedata.combining(c))
    text = re.sub(r"[^a-z0-9]+", " ", text)
    return re.sub(r"\s+", " ", text).strip()


def load_profile(profile_id: str = "sifa_generic_v1") -> dict[str, Any]:
    path = PROFILE_DIR / f"{profile_id}.json"
    if not path.exists():
        raise FileNotFoundError(f"Profil bulunamadı: {path}")
    return json.loads(path.read_text(encoding="utf-8"))


def _alias_score(cell: str, alias: str) -> int:
    c = normalize(cell)
    a = normalize(alias)

    if not c or not a:
        return 0
    if c == a:
        return 100
    if a in c:
        return 80
    if c in a and len(c) >= 3:
        return 65

    c_words = set(c.split())
    a_words = set(a.split())
    overlap = len(c_words & a_words)
    if overlap:
        return min(60, 20 + overlap * 20)
    return 0


def detect_mapping(
    rows: list[list[Any]],
    profile: dict[str, Any] | None = None,
) -> dict[str, Any]:
    profile = profile or load_profile()
    fields = profile["fields"]
    scan_limit = int(profile.get("header_scan_rows", 40))

    best: dict[str, Any] | None = None

    for row_index, row in enumerate(rows[:scan_limit], start=1):
        matches = {}
        used_columns = set()
        total_score = 0

        for field, aliases in fields.items():
            best_cell = None

            for col_index, raw in enumerate(row, start=1):
                if col_index in used_columns:
                    continue
                cell = "" if raw is None else str(raw).strip()
                if not cell:
                    continue

                score = max(
                    (_alias_score(cell, alias) for alias in aliases),
                    default=0,
                )

                if score <= 0:
                    continue

                if best_cell is None or score > best_cell["score"]:
                    best_cell = {
                        "field": field,
                        "column": col_index,
                        "header": cell,
                        "score": score,
                    }

            if best_cell:
                matches[field] = best_cell
                used_columns.add(best_cell["column"])
                total_score += best_cell["score"]

        # Product + some quantity/movement field is much more meaningful.
        core_bonus = 0
        if "product" in matches:
            core_bonus += 100
        if any(k in matches for k in ("quantity", "outbound", "inbound")):
            core_bonus += 100
        if "date" in matches:
            core_bonus += 30

        candidate = {
            "header_row": row_index,
            "matches": matches,
            "matched_field_count": len(matches),
            "score": total_score + core_bonus,
        }

        if best is None or candidate["score"] > best["score"]:
            best = candidate

    if not best:
        return {
            "profile_id": profile["profile_id"],
            "confidence": "none",
            "header_row": None,
            "matches": {},
            "score": 0,
        }

    count = best["matched_field_count"]
    confidence = (
        "high" if count >= 5
        else "medium" if count >= 3
        else "low"
    )

    return {
        "profile_id": profile["profile_id"],
        "confidence": confidence,
        **best,
    }


def rows_from_preview(preview: list[dict[str, Any]]) -> list[list[Any]]:
    return [
        list(item.get("values") or [])
        for item in preview
    ]
