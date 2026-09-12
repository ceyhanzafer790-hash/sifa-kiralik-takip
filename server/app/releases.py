from __future__ import annotations

from pydantic import BaseModel, Field
from fastapi import APIRouter, Depends, HTTPException, Query

from .db import db
from .security import require_admin

router = APIRouter(tags=["releases"])


def _public_download_path(value: str | None) -> str | None:
    if not value:
        return None

    value = value.strip()

    if value.startswith("https://") or value.startswith("http://"):
        return value

    if value.startswith("/downloads/"):
        return value

    # Never expose a local server filesystem path in the public manifest.
    return None



class ReleaseCreate(BaseModel):
    version: str = Field(min_length=1, max_length=30)
    platform: str
    file_name: str = Field(min_length=1, max_length=255)
    sha256: str = Field(min_length=64, max_length=64)
    size_bytes: int = Field(ge=0)
    download_path: str | None = Field(default=None, max_length=500)
    release_notes: str | None = Field(default=None, max_length=4000)
    mandatory: bool = False


@router.get("/app/release-manifest")
def release_manifest(
    platform: str | None = Query(default=None),
):
    conditions = ["active = true"]
    params = []

    if platform:
        conditions.append("platform = %s")
        params.append(platform)

    with db() as (_, cur):
        cur.execute(
            f"""
            select
              id,
              version,
              platform,
              file_name,
              sha256,
              size_bytes,
              download_path,
              release_notes,
              mandatory,
              created_at
            from app_releases
            where {" and ".join(conditions)}
            order by created_at desc
            """,
            tuple(params),
        )
        rows = cur.fetchall()

    artifacts = []
    for row in rows:
        item = dict(row)
        item["download_path"] = _public_download_path(
            item.get("download_path")
        )
        artifacts.append(item)

    return {
        "artifacts": artifacts,
    }


@router.get("/admin/releases")
def admin_releases(
    include_inactive: bool = False,
    user=Depends(require_admin),
):
    where = "" if include_inactive else "where active = true"

    with db() as (_, cur):
        cur.execute(
            f"""
            select *
            from app_releases
            {where}
            order by created_at desc
            """
        )
        return cur.fetchall()


@router.post("/admin/releases")
def create_release(
    data: ReleaseCreate,
    user=Depends(require_admin),
):
    if data.platform not in ("android", "windows", "ios"):
        raise HTTPException(
            status_code=400,
            detail="Platform android, windows veya ios olmalı.",
        )

    digest = data.sha256.lower().strip()
    if any(c not in "0123456789abcdef" for c in digest):
        raise HTTPException(
            status_code=400,
            detail="SHA-256 hexadecimal olmalı.",
        )

    with db() as (conn, cur):
        cur.execute(
            """
            insert into app_releases(
              version,
              platform,
              file_name,
              sha256,
              size_bytes,
              download_path,
              release_notes,
              mandatory,
              created_by
            )
            values (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            returning *
            """,
            (
                data.version,
                data.platform,
                data.file_name,
                digest,
                data.size_bytes,
                data.download_path,
                data.release_notes,
                data.mandatory,
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
            values (%s, 'app_release', %s, 'created', %s)
            """,
            (
                user["id"],
                str(row["id"]),
                {
                    "version": data.version,
                    "platform": data.platform,
                    "file_name": data.file_name,
                    "sha256": digest,
                    "size_bytes": data.size_bytes,
                },
            ),
        )
        conn.commit()

    return row


@router.post("/admin/releases/{release_id}/deactivate")
def deactivate_release(
    release_id: str,
    user=Depends(require_admin),
):
    with db() as (conn, cur):
        cur.execute(
            """
            update app_releases
            set active = false
            where id = %s and active = true
            returning *
            """,
            (release_id,),
        )
        row = cur.fetchone()

        if not row:
            raise HTTPException(
                status_code=404,
                detail="Aktif sürüm paketi bulunamadı.",
            )

        cur.execute(
            """
            insert into audit_logs(
              user_id,
              entity_type,
              entity_id,
              action,
              payload
            )
            values (%s, 'app_release', %s, 'deactivated', null)
            """,
            (user["id"], release_id),
        )
        conn.commit()

    return row
