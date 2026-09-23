from __future__ import annotations

import calendar
from datetime import date, timedelta

from fastapi import APIRouter, Depends, Query

from .db import db
from .security import current_user

router = APIRouter(prefix="/dashboard", tags=["dashboard"])


def _safe_month_date(source_day: int, year: int, month: int) -> date:
    last_day = calendar.monthrange(year, month)[1]
    return date(year, month, min(source_day, last_day))


def _next_renewal(original_outbound_date: date, today: date) -> date:
    day = original_outbound_date.day
    candidate = _safe_month_date(day, today.year, today.month)

    if candidate < today:
        if today.month == 12:
            candidate = _safe_month_date(day, today.year + 1, 1)
        else:
            candidate = _safe_month_date(day, today.year, today.month + 1)

    return candidate


@router.get("/summary")
def dashboard_summary(
    today: date = Query(...),
    days: int = Query(default=30, ge=1, le=90),
    user=Depends(current_user),
):
    end = today + timedelta(days=days)
    renewals = []

    with db() as (_, cur):
        cur.execute(
            """
            select
              rr.id,
              rr.customer_id,
              c.name as customer_name,
              ca.label as address_label,
              rr.original_outbound_date,
              rr.invoice_preference
            from rental_records rr
            join customers c on c.id = rr.customer_id
            left join customer_addresses ca on ca.id = rr.address_id
            where rr.deleted_at is null
              and rr.status = 'active'
              and c.deleted_at is null
            order by c.name, rr.original_outbound_date
            """
        )
        rentals = cur.fetchall()

        for rental in rentals:
            renewal = _next_renewal(
                rental["original_outbound_date"],
                today,
            )
            if renewal > end:
                continue

            cur.execute(
                """
                select
                  id,
                  invoice_status,
                  payment_status,
                  billed_amount,
                  paid_amount
                from rental_billing_periods
                where rental_record_id = %s
                  and renewal_date = %s
                """,
                (rental["id"], renewal),
            )
            billing = cur.fetchone()

            renewals.append(
                {
                    "rental_record_id": rental["id"],
                    "customer_id": rental["customer_id"],
                    "customer_name": rental["customer_name"],
                    "address_label": rental["address_label"],
                    "renewal_date": renewal,
                    "invoice_preference": rental["invoice_preference"],
                    "invoice_status": (
                        billing["invoice_status"] if billing else None
                    ),
                    "payment_status": (
                        billing["payment_status"] if billing else None
                    ),
                    "billed_amount": (
                        billing["billed_amount"] if billing else None
                    ),
                    "paid_amount": (
                        billing["paid_amount"] if billing else None
                    ),
                    "days_until": (renewal - today).days,
                }
            )

        cur.execute(
            """
            select
              coalesce(sum(estimated_monthly_amount), 0) as total,
              count(*) filter (where price_missing = true) as price_missing
            from v_rental_revenue_estimate
            where estimated_monthly_amount > 0
               or price_missing = true
            """
        )
        estimate = cur.fetchone()

        cur.execute(
            """
            select count(*) as count
            from v_rental_revenue_estimate
            where coalesce(remaining_quantity, 0) > 0
            """
        )
        active_items = int(cur.fetchone()["count"])

        cur.execute(
            """
            select count(*) as count
            from rental_movements
            where voided_at is null
              and movement_date = %s
            """,
            (today,),
        )
        today_movements = int(cur.fetchone()["count"])

        cur.execute(
            """
            select
              coalesce(
                sum(
                  greatest(
                    coalesce(billed_amount, 0)
                    - coalesce(paid_amount, 0),
                    0
                  )
                ),
                0
              ) as balance,
              count(*) filter (
                where greatest(
                  coalesce(billed_amount, 0)
                  - coalesce(paid_amount, 0),
                  0
                ) > 0
              ) as count
            from rental_billing_periods
            where invoice_status = 'issued'
            """
        )
        receivable = cur.fetchone()

        cur.execute(
            """
            select
              coalesce(
                sum(
                  greatest(
                    coalesce(billed_amount, 0)
                    - coalesce(paid_amount, 0),
                    0
                  )
                ),
                0
              ) as balance,
              count(*) filter (
                where greatest(
                  coalesce(billed_amount, 0)
                  - coalesce(paid_amount, 0),
                  0
                ) > 0
              ) as count
            from rental_billing_periods
            where invoice_status = 'issued'
              and coalesce(invoice_date, renewal_date)
                  <= %s - interval '31 days'
            """,
            (today,),
        )
        aged_receivable = cur.fetchone()

        cur.execute(
            """
            select
              coalesce(
                sum(
                  greatest(
                    coalesce(billed_amount, 0)
                    - coalesce(paid_amount, 0),
                    0
                  )
                ),
                0
              ) as balance,
              count(*) filter (
                where greatest(
                  coalesce(billed_amount, 0)
                  - coalesce(paid_amount, 0),
                  0
                ) > 0
              ) as count
            from rental_billing_periods
            where invoice_status = 'issued'
              and payment_due_date is not null
              and payment_due_date < %s
            """,
            (today,),
        )
        overdue_receivable = cur.fetchone()

        cur.execute(
            """
            select count(*) as count
            from rental_billing_periods
            where invoice_status = 'issued'
              and greatest(
                coalesce(billed_amount, 0)
                - coalesce(paid_amount, 0),
                0
              ) > 0
              and payment_due_date is null
            """
        )
        missing_due_date = int(cur.fetchone()["count"])

        cur.execute(
            """
            select
              count(*) as rental_count,
              coalesce(sum(missing_total), 0) as missing_total
            from (
              select
                rental_record_id,
                (
                  (case when contract_missing then 1 else 0 end)
                  + outbound_document_missing_count
                  + inbound_document_missing_count
                ) as missing_total
              from v_rental_document_compliance
              where contract_missing = true
                 or outbound_document_missing_count > 0
                 or inbound_document_missing_count > 0
            ) x
            """
        )
        documents = cur.fetchone()

        cur.execute(
            """
            select count(*) as count
            from legacy_import_items
            where import_status in ('pending_match','needs_review')
            """
        )
        import_pending = int(cur.fetchone()["count"])

        cur.execute(
            """
            select count(*) as count
            from products
            where active = true
              and stock_confidence = 'unknown'
            """
        )
        unknown_stock = int(cur.fetchone()["count"])

        cur.execute(
            """
            select count(*) as count
            from customers
            where deleted_at is null
            """
        )
        customer_count = int(cur.fetchone()["count"])

    invoice_due = [
        r for r in renewals
        if r["invoice_preference"] == "invoice_required"
        and r["invoice_status"] != "issued"
    ]

    can_view_financials = user["role"] == "admin"

    return {
        "today": today,
        "financials_visible": can_view_financials,
        "window_days": days,
        "active_rental_count": len(rentals),
        "active_rental_item_count": active_items,
        "today_movement_count": today_movements,
        "renewals": renewals,
        "renewal_due_today_count": sum(
            1 for r in renewals if r["days_until"] == 0
        ),
        "renewal_next_3_days_count": sum(
            1 for r in renewals if 0 <= r["days_until"] <= 3
        ),
        "invoice_reminder_count": len(invoice_due),
        "invoice_due_today_count": sum(
            1 for r in invoice_due if r["days_until"] == 0
        ),
        "estimated_monthly_rental_revenue": (
            float(estimate["total"] or 0)
            if can_view_financials
            else None
        ),
        "estimated_revenue_unpriced_item_count": (
            int(estimate["price_missing"] or 0)
            if can_view_financials
            else None
        ),
        "estimated_revenue_is_invoice": False,
        "issued_receivable_balance": (
            float(receivable["balance"] or 0)
            if can_view_financials
            else None
        ),
        "issued_receivable_count": (
            int(receivable["count"] or 0)
            if can_view_financials
            else None
        ),
        "aged_31_plus_receivable_balance": (
            float(aged_receivable["balance"] or 0)
            if can_view_financials
            else None
        ),
        "aged_31_plus_receivable_count": (
            int(aged_receivable["count"] or 0)
            if can_view_financials
            else None
        ),
        "overdue_receivable_balance": (
            float(overdue_receivable["balance"] or 0)
            if can_view_financials
            else None
        ),
        "overdue_receivable_count": (
            int(overdue_receivable["count"] or 0)
            if can_view_financials
            else None
        ),
        "open_invoice_missing_due_date_count": (
            missing_due_date
            if can_view_financials
            else None
        ),
        "missing_document_rental_count": int(
            documents["rental_count"] or 0
        ),
        "missing_document_count": int(
            documents["missing_total"] or 0
        ),
        "legacy_import_pending": import_pending,
        "unknown_stock_product_count": unknown_stock,
        "customer_count": customer_count,
    }
