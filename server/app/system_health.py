from __future__ import annotations

import json
import os
import shutil
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from fastapi import APIRouter, Depends

from .db import db, pool, db_query_stats
from .migrate import migration_status
from .security import require_admin

router = APIRouter(prefix="/admin", tags=["admin-system"])

STARTED_AT = time.time()


def _iso_from_timestamp(timestamp: float) -> str:
    return datetime.fromtimestamp(
        timestamp,
        tz=timezone.utc,
    ).astimezone().isoformat()


def _age_hours(value: str | None) -> float | None:
    if not value:
        return None
    try:
        dt = datetime.fromisoformat(value)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        now = datetime.now(timezone.utc)
        return round(
            (now - dt.astimezone(timezone.utc)).total_seconds() / 3600,
            2,
        )
    except Exception:
        return None


def _disk(path: Path) -> dict[str, Any]:
    path.mkdir(parents=True, exist_ok=True)
    usage = shutil.disk_usage(path)
    free_percent = (
        round((usage.free / usage.total) * 100, 2)
        if usage.total
        else 0
    )

    if usage.free < 5 * 1024**3 or free_percent < 10:
        level = "critical"
    elif usage.free < 10 * 1024**3 or free_percent < 20:
        level = "warning"
    else:
        level = "ok"

    return {
        "path": str(path),
        "total_bytes": usage.total,
        "used_bytes": usage.used,
        "free_bytes": usage.free,
        "free_percent": free_percent,
        "level": level,
    }


def _backup_status() -> dict[str, Any]:
    status_path = Path(
        os.environ.get(
            "BACKUP_STATUS_FILE",
            "/backup-status/backup_status.json",
        )
    )

    if not status_path.exists():
        return {
            "level": "critical",
            "message": "Henüz yedek durum dosyası yok.",
            "local_backup_age_hours": None,
            "cloud_backup_age_hours": None,
        }

    try:
        data = json.loads(
            status_path.read_text(encoding="utf-8")
        )
    except Exception as exc:
        return {
            "level": "critical",
            "message": f"Yedek durum dosyası okunamadı: {exc}",
            "local_backup_age_hours": None,
            "cloud_backup_age_hours": None,
        }

    local_age = _age_hours(data.get("local_backup_at"))
    cloud_age = _age_hours(data.get("cloud_backup_at"))

    # Local target ~6 hours, cloud target nightly.
    if local_age is None or local_age > 24:
        level = "critical"
    elif cloud_age is None or cloud_age > 72:
        level = "critical"
    elif local_age > 12 or cloud_age > 36:
        level = "warning"
    else:
        level = "ok"

    return {
        "level": level,
        "local_backup_age_hours": local_age,
        "cloud_backup_age_hours": cloud_age,
        "local_backup_at": data.get("local_backup_at"),
        "cloud_backup_at": data.get("cloud_backup_at"),
        "disaster_export_at": data.get("disaster_export_at"),
    }


@router.get("/system-health")
def system_health(user=Depends(require_admin)):
    document_root = Path(
        os.environ.get(
            "DOCUMENT_ROOT",
            "/data/documents",
        )
    )
    import_root = Path(
        os.environ.get(
            "IMPORT_ROOT",
            "/data/import-inbox",
        )
    )
    log_root = Path(
        os.environ.get(
            "LOG_ROOT",
            "/data/logs",
        )
    )

    with db() as (conn, cur):
        cur.execute("select now() as now, current_database() as db")
        db_ping = cur.fetchone()

        cur.execute(
            """
            select pg_database_size(current_database()) as bytes
            """
        )
        database_size = int(cur.fetchone()["bytes"])

        cur.execute(
            """
            select
              count(*) filter (where active = true) as active_users,
              count(*) as total_users
            from app_users
            """
        )
        users = cur.fetchone()

        cur.execute(
            """
            select
              count(*) filter (
                where status = 'active'
                  and deleted_at is null
              ) as active_rentals,
              count(*) filter (
                where deleted_at is null
              ) as total_rentals
            from rental_records
            """
        )
        rentals = cur.fetchone()

        cur.execute(
            """
            select
              coalesce(sum(size_bytes), 0) as bytes,
              count(*) as files
            from rental_documents
            where deleted_at is null
            """
        )
        documents = cur.fetchone()

        migrations = migration_status(conn)

    disk = _disk(document_root)
    import_disk = _disk(import_root)
    log_disk = _disk(log_root)
    backup = _backup_status()

    try:
        pool_stats = pool.get_stats()
    except Exception:
        pool_stats = {}

    pending_migrations = len(migrations.get("pending") or [])
    checksum_errors = len(
        migrations.get("checksum_errors") or []
    )

    if (
        checksum_errors
        or disk["level"] == "critical"
        or import_disk["level"] == "critical"
        or log_disk["level"] == "critical"
        or backup["level"] == "critical"
    ):
        overall = "critical"
    elif (
        pending_migrations
        or disk["level"] == "warning"
        or import_disk["level"] == "warning"
        or log_disk["level"] == "warning"
        or backup["level"] == "warning"
    ):
        overall = "warning"
    else:
        overall = "ok"

    return {
        "overall": overall,
        "checked_at": db_ping["now"],
        "api_uptime_seconds": int(time.time() - STARTED_AT),
        "database": {
            "status": "ok",
            "name": db_ping["db"],
            "size_bytes": database_size,
            "pool": pool_stats,
            "query_timing": db_query_stats(),
        },
        "storage": {
            "documents": disk,
            "import_inbox": import_disk,
            "logs": log_disk,
            "document_file_count": int(documents["files"]),
            "document_registered_bytes": int(documents["bytes"]),
        },
        "backup": backup,
        "migrations": migrations,
        "usage": {
            "active_users": int(users["active_users"]),
            "total_users": int(users["total_users"]),
            "active_rentals": int(rentals["active_rentals"]),
            "total_rentals": int(rentals["total_rentals"]),
        },
    }
