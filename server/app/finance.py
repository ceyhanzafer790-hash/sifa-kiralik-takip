from __future__ import annotations

from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query

from .db import db
from .security import require_admin

router = APIRouter(prefix="/finance", tags=["finance"])


def _validate_range(
    from_date: date | None,
    to_date: date | None,
) -> None:
    if from_date and to_date and from_date > to_date:
        raise HTTPException(
            status_code=400,
            detail="Başlangıç tarihi bitiş tarihinden sonra olamaz.",
        )


@router.get("/receivables")
def receivables(
    customer_id: str | None = None,
    from_date: date | None = None,
    to_date: date | None = None,
    q: str | None = Query(default=None, max_length=120),
    limit: int = Query(default=500, ge=1, le=2000),
    user=Depends(require_admin),
):
    _validate_range(from_date, to_date)

    conditions = [
        "invoice_status = 'issued'",
        "balance_amount > 0",
    ]
    params = []

    if customer_id:
        conditions.append("customer_id = %s")
        params.append(customer_id)

    if from_date:
        conditions.append("renewal_date >= %s")
        params.append(from_date)

    if to_date:
        conditions.append("renewal_date <= %s")
        params.append(to_date)

    if q and q.strip():
        value = f"%{q.strip()}%"
        conditions.append(
            """
            (
              customer_name ilike %s
              or coalesce(address_label, '') ilike %s
              or coalesce(invoice_no, '') ilike %s
            )
            """
        )
        params.extend([value, value, value])

    params.append(limit)

    with db() as (_, cur):
        cur.execute(
            f"""
            select *
            from v_billing_report
            where {" and ".join(conditions)}
            order by renewal_date asc, customer_name
            limit %s
            """,
            tuple(params),
        )
        rows = cur.fetchall()

    items = [dict(r) for r in rows]
    total = sum(float(r["balance_amount"] or 0) for r in items)

    return {
        "total_balance": total,
        "period_count": len(items),
        "items": items,
    }


@router.get("/rental-revenue-estimate")
def rental_revenue_estimate(
    customer_id: str | None = None,
    q: str | None = Query(default=None, max_length=120),
    user=Depends(require_admin),
):
    conditions = [
        "(estimated_monthly_amount > 0 or price_missing = true)"
    ]
    params = []

    if customer_id:
        conditions.append("customer_id = %s")
        params.append(customer_id)

    if q and q.strip():
        value = f"%{q.strip()}%"
        conditions.append(
            """
            (
              customer_name ilike %s
              or coalesce(address_label, '') ilike %s
              or product_name ilike %s
            )
            """
        )
        params.extend([value, value, value])

    where = " and ".join(conditions)

    with db() as (_, cur):
        cur.execute(
            f"""
            select
              customer_id,
              customer_name,
              address_id,
              address_label,
              sum(estimated_monthly_amount) as estimated_monthly_amount,
              count(*) filter (where price_missing = true) as unpriced_items,
              count(*) filter (where remaining_quantity > 0) as active_items
            from v_rental_revenue_estimate
            where {where}
            group by
              customer_id,
              customer_name,
              address_id,
              address_label
            order by estimated_monthly_amount desc, customer_name
            """,
            tuple(params),
        )
        groups = cur.fetchall()

        cur.execute(
            f"""
            select
              rental_record_id,
              customer_id,
              customer_name,
              address_id,
              address_label,
              rental_item_id,
              product_id,
              product_name,
              unit,
              remaining_quantity,
              current_rate,
              current_rate_type,
              estimated_monthly_amount,
              price_missing
            from v_rental_revenue_estimate
            where {where}
            order by
              customer_name,
              address_label nulls last,
              estimated_monthly_amount desc,
              product_name
            """,
            tuple(params),
        )
        items = cur.fetchall()

    return {
        "total_estimated_monthly": sum(
            float(g["estimated_monthly_amount"] or 0)
            for g in groups
        ),
        "unpriced_item_count": sum(
            int(g["unpriced_items"] or 0)
            for g in groups
        ),
        "groups": [dict(g) for g in groups],
        "items": [dict(i) for i in items],
        "is_invoice": False,
    }

@router.get("/receivables/aging")
def receivable_aging(
    as_of: date = Query(...),
    customer_id: str | None = None,
    q: str | None = Query(default=None, max_length=120),
    user=Depends(require_admin),
):
    conditions = [
        "invoice_status = 'issued'",
        "balance_amount > 0",
        "coalesce(invoice_date, renewal_date) <= %s",
    ]
    params = [as_of]

    if customer_id:
        conditions.append("customer_id = %s")
        params.append(customer_id)

    if q and q.strip():
        value = f"%{q.strip()}%"
        conditions.append(
            """
            (
              customer_name ilike %s
              or coalesce(address_label, '') ilike %s
              or coalesce(invoice_no, '') ilike %s
            )
            """
        )
        params.extend([value, value, value])

    where = " and ".join(conditions)

    with db() as (_, cur):
        cur.execute(
            f"""
            select
              *,
              greatest(
                %s - coalesce(invoice_date, renewal_date),
                0
              )::integer as age_days
            from v_billing_report
            where {where}
            order by
              age_days desc,
              renewal_date asc,
              customer_name
            """,
            tuple([as_of, *params]),
        )
        rows = [dict(r) for r in cur.fetchall()]

    buckets = {
        "0_30": {
            "label": "0-30 gün",
            "count": 0,
            "balance": 0.0,
        },
        "31_60": {
            "label": "31-60 gün",
            "count": 0,
            "balance": 0.0,
        },
        "61_plus": {
            "label": "61+ gün",
            "count": 0,
            "balance": 0.0,
        },
    }

    for row in rows:
        age = int(row["age_days"] or 0)
        balance = float(row["balance_amount"] or 0)

        if age <= 30:
            key = "0_30"
        elif age <= 60:
            key = "31_60"
        else:
            key = "61_plus"

        row["aging_bucket"] = key
        buckets[key]["count"] += 1
        buckets[key]["balance"] += balance

    return {
        "as_of": as_of,
        "total_balance": sum(
            float(r["balance_amount"] or 0)
            for r in rows
        ),
        "total_count": len(rows),
        "aged_31_plus_balance": (
            buckets["31_60"]["balance"]
            + buckets["61_plus"]["balance"]
        ),
        "aged_31_plus_count": (
            buckets["31_60"]["count"]
            + buckets["61_plus"]["count"]
        ),
        "buckets": buckets,
        "items": rows,
    }


@router.get("/receivables/overdue")
def overdue_receivables(
    as_of: date = Query(...),
    customer_id: str | None = None,
    q: str | None = Query(default=None, max_length=120),
    user=Depends(require_admin),
):
    conditions = [
        "invoice_status = 'issued'",
        "balance_amount > 0",
        "payment_due_date is not null",
        "payment_due_date < %s",
    ]
    params = [as_of]

    if customer_id:
        conditions.append("customer_id = %s")
        params.append(customer_id)

    if q and q.strip():
        value = f"%{q.strip()}%"
        conditions.append(
            """
            (
              customer_name ilike %s
              or coalesce(address_label, '') ilike %s
              or coalesce(invoice_no, '') ilike %s
            )
            """
        )
        params.extend([value, value, value])

    where = " and ".join(conditions)

    with db() as (_, cur):
        cur.execute(
            f"""
            select
              *,
              (%s - payment_due_date)::integer as overdue_days
            from v_billing_report
            where {where}
            order by overdue_days desc, customer_name
            """,
            tuple([as_of, *params]),
        )
        rows = [dict(r) for r in cur.fetchall()]

        cur.execute(
            """
            select count(*) as count
            from v_billing_report
            where invoice_status = 'issued'
              and balance_amount > 0
              and payment_due_date is null
            """
        )
        due_date_missing_count = int(cur.fetchone()["count"])

    buckets = {
        "1_30": {"label": "1-30 gün gecikmiş", "count": 0, "balance": 0.0},
        "31_60": {"label": "31-60 gün gecikmiş", "count": 0, "balance": 0.0},
        "61_plus": {"label": "61+ gün gecikmiş", "count": 0, "balance": 0.0},
    }

    for row in rows:
        days = int(row["overdue_days"] or 0)
        balance = float(row["balance_amount"] or 0)

        if days <= 30:
            key = "1_30"
        elif days <= 60:
            key = "31_60"
        else:
            key = "61_plus"

        row["overdue_bucket"] = key
        buckets[key]["count"] += 1
        buckets[key]["balance"] += balance

    return {
        "as_of": as_of,
        "total_overdue_balance": sum(
            float(r["balance_amount"] or 0)
            for r in rows
        ),
        "total_overdue_count": len(rows),
        "due_date_missing_open_invoice_count": due_date_missing_count,
        "buckets": buckets,
        "items": rows,
    }
