from __future__ import annotations

import io
import json
import os
import platform
import sys
import zipfile
from datetime import datetime, timezone
from pathlib import Path

from fastapi import APIRouter, Depends
from fastapi.responses import Response

from .db import db, pool
from .migrate import migration_status
from .runtime_settings import get_runtime_settings
from .security import require_admin

router = APIRouter(prefix="/admin", tags=["diagnostics"])

SAFE_LOG_KEYS = {
    "timestamp",
    "level",
    "logger",
    "message",
    "request_id",
    "method",
    "path",
    "status_code",
    "duration_ms",
}


def _safe_recent_logs(limit: int = 300) -> list[dict]:
    log_root = Path(
        os.environ.get(
            "LOG_ROOT",
            "/data/logs",
        )
    )
    path = log_root / "sifa-api.jsonl"

    if not path.exists():
        return []

    lines = path.read_text(
        encoding="utf-8",
        errors="replace",
    ).splitlines()[-limit:]

    result = []

    for line in lines:
        try:
            raw = json.loads(line)
        except Exception:
            continue

        safe = {
            key: raw.get(key)
            for key in SAFE_LOG_KEYS
            if key in raw
        }

        # Only warnings/errors are useful in a support bundle.
        if str(safe.get("level", "")).upper() in {
            "WARNING",
            "ERROR",
            "CRITICAL",
        }:
            result.append(safe)

    return result


def _database_summary() -> dict:
    with db() as (conn, cur):
        cur.execute(
            """
            select
              current_database() as name,
              pg_database_size(current_database()) as size_bytes,
              now() as checked_at
            """
        )
        database = dict(cur.fetchone())

        cur.execute(
            """
            select
              (select count(*) from app_users) as users,
              (
                select count(*)
                from customers
                where deleted_at is null
              ) as customers,
              (
                select count(*)
                from rental_records
                where deleted_at is null
              ) as rentals,
              (
                select count(*)
                from rental_documents
                where deleted_at is null
              ) as documents
            """
        )
        counts = dict(cur.fetchone())

        migrations = migration_status(conn)

    return {
        "database": database,
        "counts": counts,
        "migrations": migrations,
    }


@router.get("/diagnostics-bundle")
def diagnostics_bundle(user=Depends(require_admin)):
    runtime = get_runtime_settings()

    try:
        pool_stats = pool.get_stats()
    except Exception:
        pool_stats = {}

    diagnostics = {
        "product": "Şifa İnşaat Kiralık Takip",
        "app_version": "0.24.0",
        "created_at": datetime.now(
            timezone.utc
        ).astimezone().isoformat(),
        "python": sys.version.split()[0],
        "platform": platform.platform(),
        "runtime": {
            "maintenance_mode":
                runtime.get("maintenance_mode"),
            "min_client_version":
                runtime.get("min_client_version"),
            "latest_client_version":
                runtime.get("latest_client_version"),
            "enforce_min_client_version":
                runtime.get("enforce_min_client_version"),
        },
        "db_pool": pool_stats,
        **_database_summary(),
        "security_note": (
            "Bu pakette DATABASE_URL, JWT, parola, Authorization, "
            "belge içeriği ve istemci IP bilgisi bulunmaz."
        ),
    }

    recent_errors = _safe_recent_logs()

    memory = io.BytesIO()

    with zipfile.ZipFile(
        memory,
        "w",
        compression=zipfile.ZIP_DEFLATED,
    ) as z:
        z.writestr(
            "diagnostics.json",
            json.dumps(
                diagnostics,
                ensure_ascii=False,
                indent=2,
                default=str,
            ),
        )
        z.writestr(
            "recent_errors.json",
            json.dumps(
                recent_errors,
                ensure_ascii=False,
                indent=2,
                default=str,
            ),
        )
        z.writestr(
            "README.txt",
            (
                "ŞİFA İNŞAAT KİRALIK TAKİP TEŞHİS PAKETİ\n\n"
                "İçerik:\n"
                "- diagnostics.json: sürüm, migration, DB boyutu ve sayısal özet\n"
                "- recent_errors.json: temizlenmiş son WARNING/ERROR kayıtları\n\n"
                "Bilerek dahil edilmez:\n"
                "- DATABASE_URL\n"
                "- JWT / Authorization\n"
                "- parolalar\n"
                "- belge içerikleri\n"
                "- istemci IP adresleri\n"
            ),
        )

    content = memory.getvalue()

    return Response(
        content=content,
        media_type="application/zip",
        headers={
            "Content-Disposition":
                'attachment; filename="sifa_diagnostics.zip"',
            "X-Diagnostics-Contains-Secrets": "false",
        },
    )
