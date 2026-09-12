from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Depends, Query

from .db import db
from .security import require_admin

router = APIRouter(prefix="/audit", tags=["audit"])


@router.get("")
def audit_list(
    limit: int = Query(default=100, ge=1, le=500),
    offset: int = Query(default=0, ge=0, le=1000000),
    user_id: str | None = None,
    entity_type: str | None = None,
    entity_id: str | None = None,
    action: str | None = None,
    from_at: datetime | None = None,
    to_at: datetime | None = None,
    q: str | None = Query(default=None, max_length=120),
    user=Depends(require_admin),
):
    conditions = []
    params = []

    if user_id:
        conditions.append("a.user_id = %s")
        params.append(user_id)

    if entity_type:
        conditions.append("a.entity_type = %s")
        params.append(entity_type)

    if entity_id:
        conditions.append("a.entity_id = %s")
        params.append(entity_id)

    if action:
        conditions.append("a.action = %s")
        params.append(action)

    if from_at:
        conditions.append("a.created_at >= %s")
        params.append(from_at)

    if to_at:
        conditions.append("a.created_at <= %s")
        params.append(to_at)

    if q and q.strip():
        value = f"%{q.strip()}%"
        conditions.append(
            """
            (
              coalesce(u.full_name, '') ilike %s
              or coalesce(u.email, '') ilike %s
              or a.entity_type ilike %s
              or a.entity_id ilike %s
              or a.action ilike %s
              or coalesce(a.payload::text, '') ilike %s
            )
            """
        )
        params.extend([value] * 6)

    where = "where " + " and ".join(conditions) if conditions else ""

    with db() as (_, cur):
        cur.execute(
            f"""
            select count(*) as count
            from audit_logs a
            left join app_users u on u.id = a.user_id
            {where}
            """,
            tuple(params),
        )
        total = int(cur.fetchone()["count"])

        query_params = [*params, limit, offset]
        cur.execute(
            f"""
            select
              a.id,
              a.user_id,
              a.entity_type,
              a.entity_id,
              a.action,
              a.payload,
              a.created_at,
              u.full_name as user_name,
              u.email as user_email
            from audit_logs a
            left join app_users u on u.id = a.user_id
            {where}
            order by a.created_at desc, a.id desc
            limit %s
            offset %s
            """,
            tuple(query_params),
        )
        items = cur.fetchall()

    return {
        "total": total,
        "limit": limit,
        "offset": offset,
        "items": items,
    }


@router.get("/facets")
def audit_facets(user=Depends(require_admin)):
    with db() as (_, cur):
        cur.execute(
            """
            select distinct entity_type
            from audit_logs
            order by entity_type
            """
        )
        entity_types = [
            row["entity_type"]
            for row in cur.fetchall()
        ]

        cur.execute(
            """
            select distinct action
            from audit_logs
            order by action
            """
        )
        actions = [
            row["action"]
            for row in cur.fetchall()
        ]

        cur.execute(
            """
            select id, full_name, email
            from app_users
            order by full_name, email
            """
        )
        users = cur.fetchall()

    return {
        "entity_types": entity_types,
        "actions": actions,
        "users": users,
    }


@router.get("/{audit_id}/navigation")
def audit_navigation(
    audit_id: str,
    user=Depends(require_admin),
):
    with db() as (_, cur):
        cur.execute(
            """
            select id, entity_type, entity_id, payload
            from audit_logs
            where id = %s
            """,
            (audit_id,),
        )
        audit = cur.fetchone()

        if not audit:
            return {
                "target": "none",
                "customer_id": None,
                "rental_record_id": None,
            }

        entity_type = audit["entity_type"]
        entity_id = audit["entity_id"]
        payload = audit["payload"] or {}

        customer_id = (
            payload.get("customer_id")
            if isinstance(payload, dict)
            else None
        )
        rental_id = (
            payload.get("rental_record_id")
            if isinstance(payload, dict)
            else None
        )

        if entity_type == "customer":
            customer_id = entity_id

        elif entity_type == "rental_record":
            rental_id = entity_id

        elif entity_type == "rental_billing_period":
            cur.execute(
                """
                select rental_record_id
                from rental_billing_periods
                where id::text = %s
                """,
                (entity_id,),
            )
            row = cur.fetchone()
            if row:
                rental_id = str(row["rental_record_id"])

        elif entity_type == "rental_rate":
            cur.execute(
                """
                select ri.rental_record_id
                from rental_rates rr
                join rental_items ri
                  on ri.id = rr.rental_item_id
                where rr.id::text = %s
                """,
                (entity_id,),
            )
            row = cur.fetchone()
            if row:
                rental_id = str(row["rental_record_id"])

        elif entity_type == "rental_document":
            cur.execute(
                """
                select rental_record_id
                from rental_documents
                where id::text = %s
                """,
                (entity_id,),
            )
            row = cur.fetchone()
            if row:
                rental_id = str(row["rental_record_id"])

        elif entity_type == "rental_movement":
            cur.execute(
                """
                select rental_record_id
                from rental_movements
                where id::text = %s
                """,
                (entity_id,),
            )
            row = cur.fetchone()
            if row:
                rental_id = str(row["rental_record_id"])

        elif entity_type == "document_compliance_exception":
            cur.execute(
                """
                select rental_record_id
                from document_compliance_exceptions
                where id::text = %s
                """,
                (entity_id,),
            )
            row = cur.fetchone()
            if row:
                rental_id = str(row["rental_record_id"])

        elif entity_type == "sale":
            cur.execute(
                """
                select customer_id
                from sales
                where id::text = %s
                """,
                (entity_id,),
            )
            row = cur.fetchone()
            if row:
                customer_id = str(row["customer_id"])

        if rental_id:
            cur.execute(
                """
                select customer_id
                from rental_records
                where id::text = %s
                  and deleted_at is null
                """,
                (str(rental_id),),
            )
            row = cur.fetchone()

            if row:
                customer_id = str(row["customer_id"])
                return {
                    "target": "rental",
                    "customer_id": customer_id,
                    "rental_record_id": str(rental_id),
                }

        if customer_id:
            cur.execute(
                """
                select 1
                from customers
                where id::text = %s
                  and deleted_at is null
                """,
                (str(customer_id),),
            )
            if cur.fetchone():
                return {
                    "target": "customer",
                    "customer_id": str(customer_id),
                    "rental_record_id": None,
                }

    return {
        "target": "none",
        "customer_id": None,
        "rental_record_id": None,
    }
