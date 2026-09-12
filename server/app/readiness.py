from __future__ import annotations

import os
from pathlib import Path

from fastapi import APIRouter, Depends

from .db import db
from .migrate import migration_status
from .runtime_settings import get_runtime_settings
from .security import require_admin
from .system_health import _backup_status

router = APIRouter(prefix="/admin", tags=["readiness"])

CURRENT_VERSION = "0.24.0"


def _item(
    code: str,
    title: str,
    status: str,
    detail: str,
) -> dict:
    return {
        "code": code,
        "title": title,
        "status": status,
        "detail": detail,
    }


@router.get("/production-readiness")
def production_readiness(user=Depends(require_admin)):
    items = []

    jwt_secret = os.environ.get("JWT_SECRET", "")
    items.append(
        _item(
            "jwt_secret",
            "JWT güvenlik anahtarı",
            "pass" if len(jwt_secret) >= 32 else "fail",
            (
                "En az 32 karakter güvenli anahtar mevcut."
                if len(jwt_secret) >= 32
                else "JWT_SECRET en az 32 karakter olmalı."
            ),
        )
    )

    document_root = Path(
        os.environ.get("DOCUMENT_ROOT", "/data/documents")
    )
    log_root = Path(
        os.environ.get("LOG_ROOT", "/data/logs")
    )

    for code, title, path in (
        ("document_storage", "Belge deposu", document_root),
        ("log_storage", "Log deposu", log_root),
    ):
        writable = (
            path.exists()
            and path.is_dir()
            and os.access(path, os.W_OK)
        )
        items.append(
            _item(
                code,
                title,
                "pass" if writable else "fail",
                (
                    f"Yazılabilir: {path}"
                    if writable
                    else f"Klasör yok veya yazılamıyor: {path}"
                ),
            )
        )

    backup = _backup_status()
    backup_level = backup.get("level")
    items.append(
        _item(
            "backup",
            "Yerel + OneDrive yedek",
            (
                "pass"
                if backup_level == "ok"
                else "warn"
                if backup_level == "warning"
                else "fail"
            ),
            (
                "Yerel: "
                f"{backup.get('local_backup_age_hours')} saat • "
                "OneDrive: "
                f"{backup.get('cloud_backup_age_hours')} saat"
            ),
        )
    )

    with db() as (conn, cur):
        migrations = migration_status(conn)
        pending = migrations.get("pending") or []
        checksum_errors = (
            migrations.get("checksum_errors") or []
        )

        items.append(
            _item(
                "migrations",
                "Veritabanı migration",
                (
                    "pass"
                    if not pending and not checksum_errors
                    else "fail"
                ),
                (
                    "Migration zinciri güncel."
                    if not pending and not checksum_errors
                    else (
                        f"{len(pending)} bekleyen • "
                        f"{len(checksum_errors)} checksum hatası"
                    )
                ),
            )
        )

        cur.execute(
            """
            select count(*) as count
            from app_users
            where role = 'admin'
              and active = true
            """
        )
        admins = int(cur.fetchone()["count"])

        items.append(
            _item(
                "active_admin",
                "Aktif Admin hesabı",
                "pass" if admins >= 1 else "fail",
                f"{admins} aktif Admin hesabı.",
            )
        )

        required_platforms = [
            value.strip().lower()
            for value in os.environ.get(
                "REQUIRED_RELEASE_PLATFORMS",
                "android,windows,ios",
            ).split(",")
            if value.strip()
        ]

        cur.execute(
            """
            select platform, count(*) as count
            from app_releases
            where active = true
              and download_path is not null
              and length(sha256) = 64
              and size_bytes > 0
            group by platform
            """
        )
        release_counts = {
            row["platform"]: int(row["count"])
            for row in cur.fetchall()
        }

        for platform in required_platforms:
            count = release_counts.get(platform, 0)
            items.append(
                _item(
                    f"release_{platform}",
                    f"{platform.upper()} release paketi",
                    "pass" if count > 0 else "fail",
                    (
                        f"{count} aktif hash + public indirme yolu bulunan paket kaydı."
                        if count > 0
                        else "Henüz gerçek build paketi kayıtlı değil."
                    ),
                )
            )

    runtime = get_runtime_settings()

    latest = str(
        runtime.get("latest_client_version") or ""
    )
    items.append(
        _item(
            "runtime_version",
            "Sunucu istemci sürüm bilgisi",
            "pass" if latest == CURRENT_VERSION else "warn",
            (
                f"latest_client_version={latest or '-'} • "
                f"sunucu={CURRENT_VERSION}"
            ),
        )
    )

    enforcement = bool(
        runtime.get("enforce_min_client_version")
    )
    items.append(
        _item(
            "min_version_enforcement",
            "Minimum sürüm koruması",
            "pass" if enforcement else "warn",
            (
                "Eski istemciler sunucuda engelleniyor."
                if enforcement
                else (
                    "Koruma henüz zorunlu değil. "
                    "Tüm cihazlar güncellendikten sonra açılmalı."
                )
            ),
        )
    )

    failures = sum(
        1 for item in items if item["status"] == "fail"
    )
    warnings = sum(
        1 for item in items if item["status"] == "warn"
    )

    return {
        "version": CURRENT_VERSION,
        "ready": failures == 0,
        "failure_count": failures,
        "warning_count": warnings,
        "items": items,
    }
