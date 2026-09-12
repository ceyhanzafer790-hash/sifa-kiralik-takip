from __future__ import annotations

from .db import db


DEFAULTS = {
    "maintenance_mode": False,
    "maintenance_message": None,
    "min_client_version": "0.20.0",
    "latest_client_version": "0.24.0",
    "enforce_min_client_version": False,
}


def get_runtime_settings() -> dict:
    with db() as (_, cur):
        cur.execute(
            """
            select
              maintenance_mode,
              maintenance_message,
              min_client_version,
              latest_client_version,
              enforce_min_client_version,
              updated_at
            from app_runtime_settings
            where id = 1
            """
        )
        row = cur.fetchone()

    if not row:
        return dict(DEFAULTS)

    return dict(row)


def version_tuple(value: str | None) -> tuple[int, int, int] | None:
    if not value:
        return None

    try:
        core = value.strip().split("+", 1)[0].split("-", 1)[0]
        parts = core.split(".")
        values = [int(p) for p in parts[:3]]
        while len(values) < 3:
            values.append(0)
        return tuple(values[:3])
    except Exception:
        return None


def is_version_below(
    current: str | None,
    minimum: str | None,
) -> bool:
    current_v = version_tuple(current)
    minimum_v = version_tuple(minimum)

    if current_v is None or minimum_v is None:
        return False

    return current_v < minimum_v
