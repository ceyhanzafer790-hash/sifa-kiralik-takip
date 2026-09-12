from __future__ import annotations

from pydantic import BaseModel, Field
from fastapi import APIRouter, Depends, HTTPException, Query

from .db import db
from .security import current_user, require_admin

router = APIRouter(prefix="/documents", tags=["documents"])


class ComplianceExceptionCreate(BaseModel):
    rental_record_id: str
    rental_movement_id: str | None = None
    document_type: str
    reason: str = Field(min_length=3, max_length=500)
    source_legacy_import_item_id: str | None = None


def _missing_items(cur, rental_id: str) -> list[dict]:
    result = []

    cur.execute(
        """
        select 1
        from rental_documents rd
        where rd.rental_record_id = %s
          and rd.document_type = 'contract'
          and rd.deleted_at is null
        """,
        (rental_id,),
    )
    has_contract = cur.fetchone() is not None

    cur.execute(
        """
        select 1
        from document_compliance_exceptions
        where rental_record_id = %s
          and rental_movement_id is null
          and document_type = 'contract'
          and active = true
        """,
        (rental_id,),
    )
    contract_excepted = cur.fetchone() is not None

    if not has_contract and not contract_excepted:
        result.append({
            "document_type": "contract",
            "movement_id": None,
            "movement_date": None,
            "label": "Kira sözleşmesi",
        })

    cur.execute(
        """
        select id, movement_type, movement_date, quantity
        from rental_movements
        where rental_record_id = %s
          and voided_at is null
          and movement_type in ('outbound', 'inbound_return')
        order by movement_date, created_at
        """,
        (rental_id,),
    )
    movements = cur.fetchall()

    for movement in movements:
        document_type = (
            "outbound_delivery"
            if movement["movement_type"] == "outbound"
            else "inbound_delivery"
        )

        cur.execute(
            """
            select 1
            from rental_documents
            where rental_movement_id = %s
              and document_type = %s
              and deleted_at is null
            """,
            (movement["id"], document_type),
        )
        has_doc = cur.fetchone() is not None

        cur.execute(
            """
            select 1
            from document_compliance_exceptions
            where rental_record_id = %s
              and rental_movement_id = %s
              and document_type = %s
              and active = true
            """,
            (
                rental_id,
                movement["id"],
                document_type,
            ),
        )
        excepted = cur.fetchone() is not None

        if has_doc or excepted:
            continue

        result.append({
            "document_type": document_type,
            "movement_id": movement["id"],
            "movement_date": movement["movement_date"],
            "quantity": movement["quantity"],
            "label": (
                "Giden sevkiyat belgesi"
                if document_type == "outbound_delivery"
                else "Gelen/iade belgesi"
            ),
        })

    return result


@router.get("/compliance")
def document_compliance(
    only_missing: bool = True,
    customer_id: str | None = None,
    limit: int = Query(default=200, ge=1, le=1000),
    user=Depends(current_user),
):
    conditions = []

    if only_missing:
        conditions.append(
            """
            (
              contract_missing = true
              or outbound_document_missing_count > 0
              or inbound_document_missing_count > 0
            )
            """
        )

    params = []
    if customer_id:
        conditions.append("customer_id = %s")
        params.append(customer_id)

    where = "where " + " and ".join(conditions) if conditions else ""
    params.append(limit)

    with db() as (_, cur):
        cur.execute(
            f"""
            select *
            from v_rental_document_compliance
            {where}
            order by
              contract_missing desc,
              outbound_document_missing_count desc,
              inbound_document_missing_count desc,
              original_outbound_date desc
            limit %s
            """,
            tuple(params),
        )
        rows = cur.fetchall()

        result = []
        for row in rows:
            d = dict(row)
            missing_items = _missing_items(
                cur,
                str(d["rental_record_id"]),
            )
            d["missing_items"] = missing_items
            d["missing_labels"] = [
                item["label"]
                for item in missing_items
            ]
            d["missing_total"] = len(missing_items)
            result.append(d)

    return result


@router.get("/compliance/exceptions")
def compliance_exceptions(
    rental_record_id: str | None = None,
    active_only: bool = True,
    user=Depends(require_admin),
):
    conditions = []
    params = []

    if rental_record_id:
        conditions.append("dce.rental_record_id = %s")
        params.append(rental_record_id)
    if active_only:
        conditions.append("dce.active = true")

    where = "where " + " and ".join(conditions) if conditions else ""

    with db() as (_, cur):
        cur.execute(
            f"""
            select
              dce.*,
              u.full_name as created_by_name,
              ru.full_name as revoked_by_name
            from document_compliance_exceptions dce
            join app_users u on u.id = dce.created_by
            left join app_users ru on ru.id = dce.revoked_by
            {where}
            order by dce.created_at desc
            """,
            tuple(params),
        )
        return cur.fetchall()


@router.post("/compliance/exceptions")
def create_compliance_exception(
    data: ComplianceExceptionCreate,
    user=Depends(require_admin),
):
    if data.document_type not in (
        "contract",
        "outbound_delivery",
        "inbound_delivery",
    ):
        raise HTTPException(
            status_code=400,
            detail="Geçersiz belge türü.",
        )

    if data.document_type == "contract" and data.rental_movement_id:
        raise HTTPException(
            status_code=400,
            detail="Kira sözleşmesi hareket ID'sine bağlanmaz.",
        )

    if (
        data.document_type != "contract"
        and not data.rental_movement_id
    ):
        raise HTTPException(
            status_code=400,
            detail="Sevkiyat/iade istisnası için hareket seçilmelidir.",
        )

    with db() as (conn, cur):
        cur.execute(
            """
            select 1
            from rental_records
            where id = %s and deleted_at is null
            """,
            (data.rental_record_id,),
        )
        if not cur.fetchone():
            raise HTTPException(
                status_code=404,
                detail="Kiralama Takibi bulunamadı.",
            )

        if data.rental_movement_id:
            cur.execute(
                """
                select movement_type
                from rental_movements
                where id = %s
                  and rental_record_id = %s
                  and voided_at is null
                """,
                (
                    data.rental_movement_id,
                    data.rental_record_id,
                ),
            )
            movement = cur.fetchone()
            if not movement:
                raise HTTPException(
                    status_code=400,
                    detail="Hareket bu Kiralama Takibi kaydına ait değil.",
                )

            expected = (
                "outbound"
                if data.document_type == "outbound_delivery"
                else "inbound_return"
            )
            if movement["movement_type"] != expected:
                raise HTTPException(
                    status_code=400,
                    detail="Belge türü ile hareket türü uyuşmuyor.",
                )

        try:
            cur.execute(
                """
                insert into document_compliance_exceptions(
                  rental_record_id,
                  rental_movement_id,
                  document_type,
                  reason,
                  source_legacy_import_item_id,
                  created_by
                )
                values (%s, %s, %s, %s, %s, %s)
                returning *
                """,
                (
                    data.rental_record_id,
                    data.rental_movement_id,
                    data.document_type,
                    data.reason,
                    data.source_legacy_import_item_id,
                    user["id"],
                ),
            )
            row = cur.fetchone()
        except Exception as exc:
            conn.rollback()
            if "ux_document_compliance_exception_active" in str(exc):
                raise HTTPException(
                    status_code=409,
                    detail="Bu belge için zaten aktif bir istisna var.",
                )
            raise

        cur.execute(
            """
            insert into audit_logs(
              user_id,
              entity_type,
              entity_id,
              action,
              payload
            )
            values (%s, 'document_compliance_exception', %s, 'created', %s)
            """,
            (
                user["id"],
                str(row["id"]),
                {
                    "rental_record_id": data.rental_record_id,
                    "rental_movement_id": data.rental_movement_id,
                    "document_type": data.document_type,
                    "reason": data.reason,
                },
            ),
        )
        conn.commit()
        return row


@router.post("/compliance/exceptions/{exception_id}/revoke")
def revoke_compliance_exception(
    exception_id: str,
    user=Depends(require_admin),
):
    with db() as (conn, cur):
        cur.execute(
            """
            update document_compliance_exceptions
            set active = false,
                revoked_by = %s,
                revoked_at = now()
            where id = %s
              and active = true
            returning *
            """,
            (user["id"], exception_id),
        )
        row = cur.fetchone()

        if not row:
            raise HTTPException(
                status_code=404,
                detail="Aktif istisna bulunamadı.",
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
            values (%s, 'document_compliance_exception', %s, 'revoked', null)
            """,
            (user["id"], exception_id),
        )
        conn.commit()
        return row
