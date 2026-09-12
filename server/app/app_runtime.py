from __future__ import annotations

from pydantic import BaseModel, Field
from fastapi import APIRouter, Depends

from .client_compatibility import invalidate_runtime_cache
from .db import db
from .runtime_settings import get_runtime_settings
from .security import require_admin

router = APIRouter(tags=["app-runtime"])


class RuntimeSettingsUpdate(BaseModel):
    maintenance_mode: bool
    maintenance_message: str | None = Field(
        default=None,
        max_length=500,
    )
    min_client_version: str = Field(min_length=1, max_length=30)
    latest_client_version: str = Field(min_length=1, max_length=30)
    enforce_min_client_version: bool = False


@router.get("/app/status")
def app_status():
    settings = get_runtime_settings()
    return {
        "maintenance_mode": settings["maintenance_mode"],
        "maintenance_message": settings["maintenance_message"],
        "min_client_version": settings["min_client_version"],
        "latest_client_version": settings["latest_client_version"],
        "enforce_min_client_version": settings[
            "enforce_min_client_version"
        ],
    }


@router.patch("/admin/app-status")
def update_app_status(
    data: RuntimeSettingsUpdate,
    user=Depends(require_admin),
):
    with db() as (conn, cur):
        cur.execute(
            """
            insert into app_runtime_settings(
              id,
              maintenance_mode,
              maintenance_message,
              min_client_version,
              latest_client_version,
              enforce_min_client_version,
              updated_by,
              updated_at
            )
            values (1, %s, %s, %s, %s, %s, %s, now())
            on conflict (id) do update set
              maintenance_mode = excluded.maintenance_mode,
              maintenance_message = excluded.maintenance_message,
              min_client_version = excluded.min_client_version,
              latest_client_version = excluded.latest_client_version,
              enforce_min_client_version =
                excluded.enforce_min_client_version,
              updated_by = excluded.updated_by,
              updated_at = now()
            returning
              maintenance_mode,
              maintenance_message,
              min_client_version,
              latest_client_version,
              enforce_min_client_version,
              updated_at
            """,
            (
                data.maintenance_mode,
                data.maintenance_message,
                data.min_client_version,
                data.latest_client_version,
                data.enforce_min_client_version,
                user["id"],
            ),
        )
        row = cur.fetchone()

        cur.execute(
            """
            insert into audit_logs(
              user_id,
              entity_type,
              entity_id,
              action,
              payload
            )
            values (%s, 'app_runtime_settings', '1', 'updated', %s)
            """,
            (
                user["id"],
                {
                    "maintenance_mode": data.maintenance_mode,
                    "min_client_version": data.min_client_version,
                    "latest_client_version": data.latest_client_version,
                    "enforce_min_client_version":
                        data.enforce_min_client_version,
                },
            ),
        )
        conn.commit()

    invalidate_runtime_cache()
    return dict(row)
