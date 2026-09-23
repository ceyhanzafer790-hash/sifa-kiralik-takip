from contextlib import asynccontextmanager
from datetime import date
import json
import hashlib
from pathlib import Path
import calendar
import os
import shutil
import uuid

from fastapi import (
    Depends,
    FastAPI,
    File,
    Form,
    HTTPException,
    Query,
    UploadFile,
)
from fastapi.responses import FileResponse

from .db import db, open_pool, close_pool
from .schemas import (
    BillingPeriodCreate,
    BillingPeriodUpdate,
    BillingPeriodByDateUpdate,
    CustomerAddressCreate,
    CustomerCreate,
    InvoicePreferenceUpdate,
    LegacyImportItemCreate,
    LegacyImportMatchInput,
    LoginInput,
    RateCreate,
    RentalCreate,
    ReturnCreate,
    SaleCreate,
    StockCountCreate,
    RepairCompleteCreate,
    StockWriteOffCreate,
    AdminUserCreate,
    AdminUserRoleUpdate,
    AdminUserActiveUpdate,
    AdminUserPasswordReset,
    OpeningStockCreate,
    PurchaseCreate,
)
from .security import (
    create_token,
    create_document_download_token,
    verify_document_download_token,
    current_user,
    require_write,
    require_admin,
    hash_password,
    verify_password,
)
from .sync import ensure_new_operation, emit_sync_event
from .reports import router as reports_router
from .system_health import router as system_health_router
from .document_compliance import router as document_compliance_router
from .dashboard import router as dashboard_router
from .logging_config import configure_logging
from .request_logging import RequestLoggingMiddleware
from .client_compatibility import ClientCompatibilityMiddleware
from .app_runtime import router as app_runtime_router
from .finance import router as finance_router
from .audit import router as audit_router
from .releases import router as releases_router
from .diagnostics import router as diagnostics_router
from .readiness import router as readiness_router
from .migrate import migration_status

DOCUMENT_ROOT = Path(os.environ.get("DOCUMENT_ROOT", "/data/documents"))
IMPORT_ROOT = Path(os.environ.get("IMPORT_ROOT", "/data/import-inbox"))
DOCUMENT_ROOT.mkdir(parents=True, exist_ok=True)
IMPORT_ROOT.mkdir(parents=True, exist_ok=True)

configure_logging()


@asynccontextmanager
async def lifespan(app: FastAPI):
    open_pool()
    try:
        yield
    finally:
        close_pool()


app = FastAPI(
    title="Şifa İnşaat Kiralık Takip API",
    version="0.24.0",
    lifespan=lifespan,
)

app.add_middleware(ClientCompatibilityMiddleware)
app.add_middleware(RequestLoggingMiddleware)

app.include_router(reports_router)
app.include_router(system_health_router)
app.include_router(document_compliance_router)
app.include_router(dashboard_router)
app.include_router(app_runtime_router)
app.include_router(finance_router)
app.include_router(audit_router)
app.include_router(releases_router)
app.include_router(diagnostics_router)
app.include_router(readiness_router)

@app.get("/health")
def health():
    return {
        "status": "ok",
        "version": "0.24.0",
        "database": "postgresql",
        "storage": "self-hosted",
        "sync": "event-feed",
    }

@app.post("/auth/login")
def login(data: LoginInput):
    with db() as (_, cur):
        cur.execute(
            """
            select id, email, full_name, role, active, password_hash
            from app_users
            where lower(email) = lower(%s)
            """,
            (data.email.strip(),),
        )
        user = cur.fetchone()

    if (
        not user
        or not user["active"]
        or not verify_password(data.password, user["password_hash"])
    ):
        raise HTTPException(status_code=401, detail="E-posta veya şifre hatalı.")

    return {
        "access_token": create_token(str(user["id"])),
        "token_type": "bearer",
        "full_name": user["full_name"],
        "role": user["role"],
    }

@app.get("/me")
def me(user=Depends(current_user)):
    return dict(user)


# ---------- ADMIN / USERS ----------
@app.get("/admin/users")
def admin_users(user=Depends(require_admin)):
    with db() as (_, cur):
        cur.execute(
            '''
            select id, email, full_name, role, active, created_at
            from app_users
            order by full_name, email
            '''
        )
        return cur.fetchall()

@app.post("/admin/users")
def admin_create_user(
    data: AdminUserCreate,
    user=Depends(require_admin),
):
    if data.role not in ("admin", "staff", "viewer"):
        raise HTTPException(status_code=400, detail="Geçersiz kullanıcı rolü.")

    with db() as (conn, cur):
        cur.execute(
            '''
            insert into app_users(
                email,
                password_hash,
                full_name,
                role,
                active
            )
            values (%s, %s, %s, %s, true)
            returning id, email, full_name, role, active, created_at
            ''',
            (
                data.email.strip().lower(),
                hash_password(data.password),
                data.full_name.strip(),
                data.role,
            ),
        )
        row = cur.fetchone()

        _audit(
            cur,
            user["id"],
            "app_user",
            row["id"],
            "created",
            {
                "email": row["email"],
                "full_name": row["full_name"],
                "role": row["role"],
            },
        )
        conn.commit()
        return row

@app.patch("/admin/users/{user_id}/role")
def admin_update_role(
    user_id: str,
    data: AdminUserRoleUpdate,
    user=Depends(require_admin),
):
    if data.role not in ("admin", "staff", "viewer"):
        raise HTTPException(status_code=400, detail="Geçersiz kullanıcı rolü.")

    if str(user["id"]) == user_id and data.role != "admin":
        raise HTTPException(
            status_code=400,
            detail="Kendi yönetici rolünüzü bu ekrandan düşüremezsiniz.",
        )

    with db() as (conn, cur):
        cur.execute(
            '''
            update app_users
            set role = %s
            where id = %s
            returning id, email, full_name, role, active
            ''',
            (data.role, user_id),
        )
        row = cur.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Kullanıcı bulunamadı.")

        _audit(
            cur,
            user["id"],
            "app_user",
            user_id,
            "role_changed",
            {"role": data.role},
        )
        conn.commit()
        return row

@app.patch("/admin/users/{user_id}/active")
def admin_update_active(
    user_id: str,
    data: AdminUserActiveUpdate,
    user=Depends(require_admin),
):
    if str(user["id"]) == user_id and not data.active:
        raise HTTPException(
            status_code=400,
            detail="Kendi yönetici hesabınızı pasif yapamazsınız.",
        )

    with db() as (conn, cur):
        cur.execute(
            '''
            update app_users
            set active = %s
            where id = %s
            returning id, email, full_name, role, active
            ''',
            (data.active, user_id),
        )
        row = cur.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Kullanıcı bulunamadı.")

        _audit(
            cur,
            user["id"],
            "app_user",
            user_id,
            "active_changed",
            {"active": data.active},
        )
        conn.commit()
        return row

@app.post("/admin/users/{user_id}/reset-password")
def admin_reset_password(
    user_id: str,
    data: AdminUserPasswordReset,
    user=Depends(require_admin),
):
    with db() as (conn, cur):
        cur.execute(
            '''
            update app_users
            set password_hash = %s
            where id = %s
            returning id, email, full_name
            ''',
            (hash_password(data.new_password), user_id),
        )
        row = cur.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Kullanıcı bulunamadı.")

        _audit(
            cur,
            user["id"],
            "app_user",
            user_id,
            "password_reset",
            {"by_admin": True},
        )
        conn.commit()
        return {
            "id": row["id"],
            "email": row["email"],
            "full_name": row["full_name"],
            "password_reset": True,
        }

@app.get("/admin/migration-status")
def admin_migration_status(user=Depends(require_admin)):
    with db() as (conn, _):
        return migration_status(conn)

# ---------- BACKUP HEALTH ----------
@app.get("/admin/backup-status")
def backup_status(user=Depends(require_admin)):
    status_path = Path(
        os.environ.get(
            "BACKUP_STATUS_FILE",
            "/backup-status/backup_status.json",
        )
    )

    if not status_path.exists():
        return {
            "status": "not_yet_run",
            "local_backup_ok": False,
            "cloud_backup_ok": False,
            "message": "Henüz yedek durum dosyası oluşmamış.",
        }

    try:
        with status_path.open("r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception as exc:
        return {
            "status": "error",
            "local_backup_ok": False,
            "cloud_backup_ok": False,
            "message": str(exc),
        }

    return {
        "status": "ok",
        **data,
    }

# ---------- GLOBAL SEARCH ----------
@app.get("/search")
def global_search(
    q: str = Query(min_length=1, max_length=120),
    limit: int = Query(default=30, ge=1, le=100),
    user=Depends(current_user),
):
    term = f"%{q.strip()}%"
    with db() as (_, cur):
        cur.execute(
            """
            select id, name, phone, 'customer' as result_type
            from customers
            where deleted_at is null
              and (name ilike %s or coalesce(phone, '') ilike %s)
            order by name
            limit %s
            """,
            (term, term, limit),
        )
        customers = cur.fetchall()

        cur.execute(
            """
            select rr.id, c.id as customer_id, c.name as customer_name,
                   ca.label as address_label, rr.original_outbound_date,
                   'rental' as result_type
            from rental_records rr
            join customers c on c.id = rr.customer_id
            left join customer_addresses ca on ca.id = rr.address_id
            where rr.deleted_at is null
              and (
                c.name ilike %s
                or coalesce(ca.label, '') ilike %s
                or exists (
                  select 1 from rental_items ri
                  join products p on p.id = ri.product_id
                  where ri.rental_record_id = rr.id and p.name ilike %s
                )
              )
            order by rr.original_outbound_date desc
            limit %s
            """,
            (term, term, term, limit),
        )
        rentals = cur.fetchall()

        cur.execute(
            """
            select rd.id, rd.rental_record_id, rd.original_file_name,
                   rd.document_type, c.name as customer_name,
                   'document' as result_type
            from rental_documents rd
            join rental_records rr on rr.id = rd.rental_record_id
            join customers c on c.id = rr.customer_id
            where rd.deleted_at is null and rd.original_file_name ilike %s
            order by rd.created_at desc
            limit %s
            """,
            (term, limit),
        )
        documents = cur.fetchall()

    return {
        "query": q,
        "customers": customers,
        "rentals": rentals,
        "documents": documents,
    }

# ---------- PRODUCTS ----------
@app.get("/products")
def products(user=Depends(current_user)):
    with db() as (_, cur):
        cur.execute(
            """
            select id, code, name, category, unit, trade_mode,
                   variant, package_size, active
            from products
            where active = true
            order by category, name
            """
        )
        return cur.fetchall()

# ---------- CUSTOMERS ----------
@app.get("/customers")
def customers(user=Depends(current_user)):
    with db() as (_, cur):
        cur.execute(
            """
            select id, name, phone, notes, created_at, updated_at
            from customers
            where deleted_at is null
            order by name
            """
        )
        return cur.fetchall()


@app.get("/customers/{customer_id}")
def customer_detail_basic(
    customer_id: str,
    user=Depends(current_user),
):
    with db() as (_, cur):
        cur.execute(
            """
            select id, name, phone, notes, created_at
            from customers
            where id = %s
              and deleted_at is null
            """,
            (customer_id,),
        )
        row = cur.fetchone()

    if not row:
        raise HTTPException(
            status_code=404,
            detail="Müşteri bulunamadı.",
        )

    return row


@app.post("/customers")
def create_customer(
    data: CustomerCreate,
    user=Depends(require_write),
):
    with db() as (conn, cur):
        ensure_new_operation(
            cur,
            data.client_operation_id,
            user["id"],
            "create_customer",
        )
        cur.execute(
            """
            insert into customers(id, name, phone, notes, created_by)
            values (coalesce(%s::uuid, gen_random_uuid()), %s, %s, %s, %s)
            on conflict (id) do update set
              name = excluded.name,
              phone = excluded.phone,
              notes = excluded.notes,
              updated_at = now()
            returning id, name, phone, notes, created_at, updated_at
            """,
            (
                data.id,
                data.name.strip(),
                data.phone,
                data.notes,
                user["id"],
            ),
        )
        row = cur.fetchone()
        _audit(cur, user["id"], "customer", row["id"], "created", row)
        emit_sync_event(cur, "customer", row["id"], "created", row)
        conn.commit()
        return row

@app.get("/customers/{customer_id}/addresses")
def customer_addresses(customer_id: str, user=Depends(current_user)):
    with db() as (_, cur):
        cur.execute(
            """
            select id, customer_id, label, full_address, created_at
            from customer_addresses
            where customer_id = %s and deleted_at is null
            order by label
            """,
            (customer_id,),
        )
        return cur.fetchall()

@app.post("/customers/{customer_id}/addresses")
def create_customer_address(
    customer_id: str,
    data: CustomerAddressCreate,
    user=Depends(require_write),
):
    with db() as (conn, cur):
        ensure_new_operation(
            cur,
            data.client_operation_id,
            user["id"],
            "create_customer_address",
        )
        cur.execute(
            """
            insert into customer_addresses(id, customer_id, label, full_address)
            values (coalesce(%s::uuid, gen_random_uuid()), %s, %s, %s)
            on conflict (id) do update set
              label = excluded.label,
              full_address = excluded.full_address
            returning *
            """,
            (data.id, customer_id, data.label.strip(), data.full_address),
        )
        row = cur.fetchone()
        _audit(cur, user["id"], "customer", customer_id, "address_added", row)
        emit_sync_event(cur, "customer_address", row["id"], "created", row)
        conn.commit()
        return row

# ---------- RENTALS ----------
@app.get("/customers/{customer_id}/rentals")
def customer_rentals(customer_id: str, user=Depends(current_user)):
    with db() as (_, cur):
        cur.execute(
            """
            select
              rr.id,
              rr.customer_id,
              rr.address_id,
              rr.original_outbound_date,
              rr.invoice_preference,
              rr.status,
              rr.note,
              rr.created_at,
              rr.updated_at,
              rr.row_version,
              coalesce(
                json_agg(
                  json_build_object(
                    'id', ri.id,
                    'product_id', ri.product_id,
                    'product_name', p.name,
                    'unit', p.unit,
                    'initial_quantity', ri.initial_quantity,
                    'returned_quantity', (
                      select coalesce(sum(rm.quantity), 0)
                      from rental_movements rm
                      where rm.rental_item_id = ri.id
                        and rm.movement_type = 'inbound_return'
                        and rm.voided_at is null
                    )
                  )
                ) filter (where ri.id is not null),
                '[]'::json
              ) as items
            from rental_records rr
            left join rental_items ri on ri.rental_record_id = rr.id
            left join products p on p.id = ri.product_id
            where rr.customer_id = %s
              and rr.deleted_at is null
            group by rr.id
            order by rr.original_outbound_date desc
            """,
            (customer_id,),
        )
        return cur.fetchall()

@app.post("/rentals")
def create_rental(
    data: RentalCreate,
    user=Depends(require_write),
):
    if data.invoice_preference not in ("invoice_required", "no_invoice"):
        raise HTTPException(status_code=400, detail="Geçersiz fatura tercihi.")
    if not data.items:
        raise HTTPException(status_code=400, detail="En az bir kiralık malzeme gerekli.")

    with db() as (conn, cur):
        ensure_new_operation(
            cur,
            data.client_operation_id,
            user["id"],
            "rental_create",
        )

        cur.execute(
            """
            insert into rental_records(
                id,
                customer_id,
                address_id,
                original_outbound_date,
                invoice_preference,
                note,
                created_by
            )
            values (coalesce(%s::uuid, gen_random_uuid()), %s, %s, %s, %s, %s, %s)
            returning *
            """,
            (
                data.id,
                data.customer_id,
                data.address_id,
                data.original_outbound_date,
                data.invoice_preference,
                data.note,
                user["id"],
            ),
        )
        rental = cur.fetchone()

        created_items = []
        for item in data.items:
            if item.rate_type not in ("per_unit_monthly", "fixed_monthly"):
                raise HTTPException(status_code=400, detail="Geçersiz fiyat tipi.")

            cur.execute(
                """
                insert into rental_items(
                    id,
                    rental_record_id,
                    product_id,
                    initial_quantity
                )
                values (coalesce(%s::uuid, gen_random_uuid()), %s, %s, %s)
                returning *
                """,
                (item.id, rental["id"], item.product_id, item.quantity),
            )
            rental_item = cur.fetchone()
            created_items.append(rental_item)

            cur.execute(
                """
                insert into rental_movements(
                    id,
                    rental_record_id,
                    rental_item_id,
                    movement_type,
                    quantity,
                    movement_date,
                    created_by
                )
                values (
                    coalesce(%s::uuid, gen_random_uuid()),
                    %s, %s, 'outbound', %s, %s, %s
                )
                """,
                (
                    item.outbound_movement_id,
                    rental["id"],
                    rental_item["id"],
                    item.quantity,
                    data.original_outbound_date,
                    user["id"],
                ),
            )

            cur.execute(
                """
                insert into stock_movements(
                    product_id,
                    bucket,
                    movement_type,
                    quantity,
                    movement_date,
                    source_type,
                    source_id,
                    created_by
                )
                values (%s, 'available', 'rental_out', %s, %s, 'rental', %s, %s)
                """,
                (
                    item.product_id,
                    -item.quantity,
                    data.original_outbound_date,
                    rental["id"],
                    user["id"],
                ),
            )

            if item.first_rate_amount is not None:
                cur.execute(
                    """
                    insert into rental_rates(
                        id,
                        rental_item_id,
                        effective_from,
                        amount,
                        rate_type,
                        created_by
                    )
                    values (
                        coalesce(%s::uuid, gen_random_uuid()),
                        %s, %s, %s, %s, %s
                    )
                    """,
                    (
                        item.first_rate_id,
                        rental_item["id"],
                        data.original_outbound_date,
                        item.first_rate_amount,
                        item.rate_type,
                        user["id"],
                    ),
                )

        _audit(
            cur,
            user["id"],
            "rental_record",
            rental["id"],
            "created",
            {
                "original_outbound_date": str(data.original_outbound_date),
                "item_count": len(created_items),
            },
        )
        emit_sync_event(
            cur,
            "rental_record",
            rental["id"],
            "created",
            {"customer_id": data.customer_id},
        )
        conn.commit()
        return {
            "rental": rental,
            "items": created_items,
        }

@app.get("/rentals/{rental_id}")
def rental_detail(rental_id: str, user=Depends(current_user)):
    with db() as (_, cur):
        cur.execute(
            """
            select
              rr.*,
              c.name as customer_name,
              ca.label as address_label,
              ca.full_address
            from rental_records rr
            join customers c on c.id = rr.customer_id
            left join customer_addresses ca on ca.id = rr.address_id
            where rr.id = %s and rr.deleted_at is null
            """,
            (rental_id,),
        )
        rental = cur.fetchone()
        if not rental:
            raise HTTPException(status_code=404, detail="Kiralama Takibi bulunamadı.")

        cur.execute(
            """
            select
              ri.id,
              ri.product_id,
              p.name as product_name,
              p.unit,
              ri.initial_quantity,
              coalesce((
                select sum(rm.quantity)
                from rental_movements rm
                where rm.rental_item_id = ri.id
                  and rm.movement_type = 'inbound_return'
                  and rm.voided_at is null
              ), 0) as returned_quantity
            from rental_items ri
            join products p on p.id = ri.product_id
            where ri.rental_record_id = %s
            order by p.name
            """,
            (rental_id,),
        )
        items = cur.fetchall()

        cur.execute(
            """
            select *
            from rental_movements
            where rental_record_id = %s
              and voided_at is null
            order by movement_date desc, created_at desc
            """,
            (rental_id,),
        )
        movements = cur.fetchall()

        cur.execute(
            """
            select rrates.*, p.name as product_name, p.unit
            from rental_rates rrates
            join rental_items ri on ri.id = rrates.rental_item_id
            join products p on p.id = ri.product_id
            where ri.rental_record_id = %s
            order by rrates.effective_from desc, rrates.created_at desc
            """,
            (rental_id,),
        )
        rates = cur.fetchall()

        cur.execute(
            """
            select id, rental_movement_id, document_type,
                   original_file_name, mime_type, size_bytes, created_at
            from rental_documents
            where rental_record_id = %s
              and deleted_at is null
            order by created_at desc
            """,
            (rental_id,),
        )
        documents = cur.fetchall()

        cur.execute(
            """
            select *
            from rental_billing_periods
            where rental_record_id = %s
            order by renewal_date desc
            """,
            (rental_id,),
        )
        billing_periods = cur.fetchall()

        return {
            "rental": rental,
            "items": items,
            "movements": movements,
            "rates": rates,
            "documents": documents,
            "billing_periods": billing_periods,
        }

@app.post("/rentals/{rental_id}/returns")
def add_return(
    rental_id: str,
    data: ReturnCreate,
    user=Depends(require_write),
):
    if data.return_condition not in ("usable", "repair", "scrap"):
        raise HTTPException(status_code=400, detail="Geçersiz iade durumu.")

    with db() as (conn, cur):
        ensure_new_operation(
            cur,
            data.client_operation_id,
            user["id"],
            "return_add",
        )

        cur.execute(
            """
            select initial_quantity
            from rental_items
            where id = %s and rental_record_id = %s
            """,
            (data.rental_item_id, rental_id),
        )
        item = cur.fetchone()
        if not item:
            raise HTTPException(status_code=404, detail="Kiralık malzeme bulunamadı.")

        cur.execute(
            """
            select coalesce(sum(quantity), 0) as returned
            from rental_movements
            where rental_item_id = %s
              and movement_type = 'inbound_return'
              and voided_at is null
            """,
            (data.rental_item_id,),
        )
        returned = float(cur.fetchone()["returned"])
        remaining = float(item["initial_quantity"]) - returned
        if data.quantity > remaining:
            raise HTTPException(
                status_code=400,
                detail=f"Kirada kalan miktar {remaining}. Daha fazla iade girilemez.",
            )

        cur.execute(
            """
            insert into rental_movements(
                id,
                rental_record_id,
                rental_item_id,
                movement_type,
                quantity,
                movement_date,
                return_condition,
                note,
                created_by
            )
            values (
                coalesce(%s::uuid, gen_random_uuid()),
                %s, %s, 'inbound_return', %s, %s, %s, %s, %s
            )
            returning *
            """,
            (
                data.id,
                rental_id,
                data.rental_item_id,
                data.quantity,
                data.movement_date,
                data.return_condition,
                data.note,
                user["id"],
            ),
        )
        movement = cur.fetchone()

        cur.execute(
            """
            select product_id
            from rental_items
            where id = %s
            """,
            (data.rental_item_id,),
        )
        product_id = cur.fetchone()["product_id"]

        return_bucket = {
            "usable": "available",
            "repair": "repair",
            "scrap": "scrap",
        }[data.return_condition]

        cur.execute(
            """
            insert into stock_movements(
                product_id,
                bucket,
                movement_type,
                quantity,
                movement_date,
                source_type,
                source_id,
                note,
                created_by
            )
            values (%s, %s, 'rental_return', %s, %s, 'rental_return', %s, %s, %s)
            """,
            (
                product_id,
                return_bucket,
                data.quantity,
                data.movement_date,
                movement["id"],
                f"İade durumu: {data.return_condition}",
                user["id"],
            ),
        )

        _audit(
            cur,
            user["id"],
            "rental_record",
            rental_id,
            "return_added",
            {
                "movement_id": str(movement["id"]),
                "rental_item_id": data.rental_item_id,
                "quantity": data.quantity,
                "movement_date": str(data.movement_date),
                "return_condition": data.return_condition,
            },
        )
        emit_sync_event(
            cur,
            "rental_record",
            rental_id,
            "return_added",
            {"movement_id": str(movement["id"])},
        )
        conn.commit()
        return movement

@app.post("/rentals/{rental_id}/rates")
def add_rate(
    rental_id: str,
    data: RateCreate,
    user=Depends(require_write),
):
    if data.rate_type not in ("per_unit_monthly", "fixed_monthly"):
        raise HTTPException(status_code=400, detail="Geçersiz fiyat tipi.")

    with db() as (conn, cur):
        ensure_new_operation(
            cur,
            data.client_operation_id,
            user["id"],
            "rate_add",
        )

        cur.execute(
            """
            select 1
            from rental_items
            where id = %s and rental_record_id = %s
            """,
            (data.rental_item_id, rental_id),
        )
        if not cur.fetchone():
            raise HTTPException(status_code=404, detail="Kiralık malzeme bulunamadı.")

        cur.execute(
            """
            insert into rental_rates(
                id,
                rental_item_id,
                effective_from,
                amount,
                rate_type,
                note,
                created_by
            )
            values (
                coalesce(%s::uuid, gen_random_uuid()),
                %s, %s, %s, %s, %s, %s
            )
            returning *
            """,
            (
                data.id,
                data.rental_item_id,
                data.effective_from,
                data.amount,
                data.rate_type,
                data.note,
                user["id"],
            ),
        )
        rate = cur.fetchone()
        _audit(
            cur,
            user["id"],
            "rental_record",
            rental_id,
            "rate_added",
            {
                "rental_item_id": data.rental_item_id,
                "amount": data.amount,
                "effective_from": str(data.effective_from),
                "rate_type": data.rate_type,
            },
        )
        emit_sync_event(
            cur,
            "rental_record",
            rental_id,
            "rate_added",
            {"rate_id": str(rate["id"])},
        )
        conn.commit()
        return rate

@app.patch("/rentals/{rental_id}/invoice-preference")
def invoice_preference(
    rental_id: str,
    data: InvoicePreferenceUpdate,
    user=Depends(require_write),
):
    if data.invoice_preference not in ("invoice_required", "no_invoice"):
        raise HTTPException(status_code=400, detail="Geçersiz fatura tercihi.")

    with db() as (conn, cur):
        ensure_new_operation(
            cur,
            data.client_operation_id,
            user["id"],
            "invoice_preference_change",
        )
        cur.execute(
            """
            update rental_records
            set invoice_preference = %s,
                updated_at = now(),
                row_version = row_version + 1
            where id = %s
              and deleted_at is null
              and (%s is null or row_version = %s)
            returning id, invoice_preference, row_version
            """,
            (
                data.invoice_preference,
                rental_id,
                data.expected_version,
                data.expected_version,
            ),
        )
        row = cur.fetchone()
        if not row:
            cur.execute(
                """
                select id, invoice_preference, row_version, updated_at
                from rental_records
                where id = %s and deleted_at is null
                """,
                (rental_id,),
            )
            current = cur.fetchone()
            if current and data.expected_version is not None:
                raise HTTPException(
                    status_code=409,
                    detail={
                        "code": "row_version_conflict",
                        "message": "Kayıt başka bir cihazda değişmiş.",
                        "current_version": current["row_version"],
                        "current_record": current,
                    },
                )
            raise HTTPException(status_code=404, detail="Kiralama Takibi bulunamadı.")

        _audit(
            cur,
            user["id"],
            "rental_record",
            rental_id,
            "invoice_preference_changed",
            {"invoice_preference": data.invoice_preference},
        )
        emit_sync_event(
            cur,
            "rental_record",
            rental_id,
            "invoice_preference_changed",
            row,
        )
        conn.commit()
        return row

# ---------- BILLING ----------
@app.post("/rentals/{rental_id}/billing-periods")
def create_billing_period(
    rental_id: str,
    data: BillingPeriodCreate,
    user=Depends(require_write),
):
    with db() as (conn, cur):
        ensure_new_operation(
            cur,
            data.client_operation_id,
            user["id"],
            "billing_period_create",
        )

        cur.execute(
            """
            select original_outbound_date, invoice_preference
            from rental_records
            where id = %s and deleted_at is null
            """,
            (rental_id,),
        )
        rental = cur.fetchone()
        if not rental:
            raise HTTPException(status_code=404, detail="Kiralama Takibi bulunamadı.")

        expected_day = rental["original_outbound_date"].day
        last_day = calendar.monthrange(
            data.renewal_date.year,
            data.renewal_date.month,
        )[1]
        expected_day = min(expected_day, last_day)

        if data.renewal_date.day != expected_day:
            raise HTTPException(
                status_code=400,
                detail=f"Bu kiralamanın yenileme günü ayın {expected_day}. günü.",
            )

        billed_amount, snapshot = _calculate_period_snapshot(
            cur,
            rental_id,
            data.renewal_date,
        )

        invoice_status = (
            "pending"
            if rental["invoice_preference"] == "invoice_required"
            else "not_required"
        )

        cur.execute(
            """
            insert into rental_billing_periods(
                rental_record_id,
                renewal_date,
                invoice_status,
                billed_amount,
                quantity_rate_snapshot
            )
            values (%s, %s, %s, %s, %s)
            on conflict (rental_record_id, renewal_date)
            do update set
              billed_amount = excluded.billed_amount,
              quantity_rate_snapshot = excluded.quantity_rate_snapshot
            returning *
            """,
            (
                rental_id,
                data.renewal_date,
                invoice_status,
                billed_amount,
                snapshot,
            ),
        )
        period = cur.fetchone()

        _audit(
            cur,
            user["id"],
            "rental_billing_period",
            period["id"],
            "created_or_refreshed",
            {
                "rental_record_id": rental_id,
                "renewal_date": str(data.renewal_date),
                "billed_amount": float(billed_amount),
            },
        )
        emit_sync_event(
            cur,
            "rental_billing_period",
            period["id"],
            "upserted",
            {"rental_record_id": rental_id},
        )
        conn.commit()
        return period

@app.patch("/billing-periods/{period_id}")
def update_billing_period(
    period_id: str,
    data: BillingPeriodUpdate,
    user=Depends(require_write),
):
    allowed_invoice = {"not_required", "pending", "issued"}
    allowed_payment = {"pending", "partial", "paid"}

    if data.invoice_status and data.invoice_status not in allowed_invoice:
        raise HTTPException(status_code=400, detail="Geçersiz fatura durumu.")
    if data.payment_status and data.payment_status not in allowed_payment:
        raise HTTPException(status_code=400, detail="Geçersiz ödeme durumu.")

    with db() as (conn, cur):
        ensure_new_operation(
            cur,
            data.client_operation_id,
            user["id"],
            "billing_period_update",
        )

        cur.execute(
            """
            select *
            from rental_billing_periods
            where id = %s
            """,
            (period_id,),
        )
        existing = cur.fetchone()
        if not existing:
            raise HTTPException(status_code=404, detail="Kira dönemi bulunamadı.")

        next_invoice_status = data.invoice_status or existing["invoice_status"]
        next_invoice_date = (
            data.invoice_date
            if data.invoice_date is not None
            else existing["invoice_date"]
        )
        next_invoice_no = (
            data.invoice_no
            if data.invoice_no is not None
            else existing["invoice_no"]
        )
        next_payment_due_date = (
            data.payment_due_date
            if "payment_due_date" in data.model_fields_set
            else existing["payment_due_date"]
        )
        next_payment_status = data.payment_status or existing["payment_status"]

        if (
            next_payment_due_date is not None
            and next_invoice_status != "issued"
        ):
            raise HTTPException(
                status_code=400,
                detail="Ödeme vadesi yalnız kesilmiş faturaya girilebilir.",
            )

        if (
            next_payment_due_date is not None
            and next_invoice_date is not None
            and next_payment_due_date < next_invoice_date
        ):
            raise HTTPException(
                status_code=400,
                detail="Ödeme vadesi fatura tarihinden önce olamaz.",
            )
        next_paid_amount = (
            data.paid_amount
            if data.paid_amount is not None
            else existing["paid_amount"]
        )

        cur.execute(
            """
            update rental_billing_periods
            set invoice_status = %s,
                invoice_date = %s,
                invoice_no = %s,
                payment_due_date = %s,
                payment_status = %s,
                paid_amount = %s,
                row_version = row_version + 1
            where id = %s
              and (%s is null or row_version = %s)
            returning *
            """,
            (
                next_invoice_status,
                next_invoice_date,
                next_invoice_no,
                next_payment_due_date,
                next_payment_status,
                next_paid_amount,
                period_id,
                data.expected_version,
                data.expected_version,
            ),
        )
        row = cur.fetchone()
        if not row:
            cur.execute(
                """
                select id, rental_record_id, renewal_date, invoice_status,
                       invoice_date, invoice_no, payment_due_date,
                       payment_status, paid_amount,
                       billed_amount, row_version
                from rental_billing_periods
                where id = %s
                """,
                (period_id,),
            )
            current = cur.fetchone()
            if current and data.expected_version is not None:
                raise HTTPException(
                    status_code=409,
                    detail={
                        "code": "row_version_conflict",
                        "message": "Kira dönemi başka bir cihazda değişmiş.",
                        "current_version": current["row_version"],
                        "current_record": current,
                    },
                )
            raise HTTPException(status_code=404, detail="Kira dönemi bulunamadı.")

        _audit(
            cur,
            user["id"],
            "rental_billing_period",
            period_id,
            "updated",
            {
                "invoice_status": next_invoice_status,
                "payment_due_date": (
                    str(next_payment_due_date)
                    if next_payment_due_date is not None
                    else None
                ),
                "payment_status": next_payment_status,
                "paid_amount": next_paid_amount,
            },
        )
        emit_sync_event(
            cur,
            "rental_billing_period",
            period_id,
            "updated",
            {"rental_record_id": str(existing["rental_record_id"])},
        )
        conn.commit()
        return row


@app.patch("/rentals/{rental_id}/billing-periods/by-date/{renewal_date}")
def update_billing_period_by_date(
    rental_id: str,
    renewal_date: date,
    data: BillingPeriodByDateUpdate,
    user=Depends(require_write),
):
    allowed_invoice = {"not_required", "pending", "issued"}
    allowed_payment = {"pending", "partial", "paid"}
    if data.invoice_status and data.invoice_status not in allowed_invoice:
        raise HTTPException(status_code=400, detail="Geçersiz fatura durumu.")
    if data.payment_status and data.payment_status not in allowed_payment:
        raise HTTPException(status_code=400, detail="Geçersiz ödeme durumu.")

    with db() as (conn, cur):
        ensure_new_operation(
            cur, data.client_operation_id, user["id"], "billing_period_update_by_date"
        )
        cur.execute(
            """
            select * from rental_billing_periods
            where rental_record_id = %s and renewal_date = %s
            """,
            (rental_id, renewal_date),
        )
        existing = cur.fetchone()
        if not existing:
            raise HTTPException(status_code=404, detail="Kira dönemi bulunamadı.")

        next_invoice_status = data.invoice_status or existing["invoice_status"]
        next_invoice_date = data.invoice_date if data.invoice_date is not None else existing["invoice_date"]
        next_invoice_no = (
            data.invoice_no
            if data.invoice_no is not None
            else existing["invoice_no"]
        )
        next_payment_due_date = (
            data.payment_due_date
            if "payment_due_date" in data.model_fields_set
            else existing["payment_due_date"]
        )
        next_payment_status = data.payment_status or existing["payment_status"]

        if (
            next_payment_due_date is not None
            and next_invoice_status != "issued"
        ):
            raise HTTPException(
                status_code=400,
                detail="Ödeme vadesi yalnız kesilmiş faturaya girilebilir.",
            )

        if (
            next_payment_due_date is not None
            and next_invoice_date is not None
            and next_payment_due_date < next_invoice_date
        ):
            raise HTTPException(
                status_code=400,
                detail="Ödeme vadesi fatura tarihinden önce olamaz.",
            )
        next_paid_amount = data.paid_amount if data.paid_amount is not None else existing["paid_amount"]

        cur.execute(
            """
            update rental_billing_periods
            set invoice_status = %s,
                invoice_date = %s,
                invoice_no = %s,
                payment_due_date = %s,
                payment_status = %s,
                paid_amount = %s,
                row_version = row_version + 1
            where rental_record_id = %s
              and renewal_date = %s
              and (%s is null or row_version = %s)
            returning *
            """,
            (
                next_invoice_status, next_invoice_date, next_invoice_no,
                next_payment_due_date,
                next_payment_status, next_paid_amount,
                rental_id, renewal_date,
                data.expected_version, data.expected_version,
            ),
        )
        row = cur.fetchone()
        if not row:
            cur.execute(
                """
                select id, rental_record_id, renewal_date, invoice_status,
                       invoice_date, invoice_no, payment_due_date,
                       payment_status, paid_amount,
                       billed_amount, row_version
                from rental_billing_periods
                where rental_record_id = %s and renewal_date = %s
                """,
                (rental_id, renewal_date),
            )
            current = cur.fetchone()
            raise HTTPException(
                status_code=409,
                detail={
                    "code": "row_version_conflict",
                    "message": "Kira dönemi başka bir cihazda değişmiş.",
                    "current_version": current["row_version"] if current else None,
                    "current_record": current,
                },
            )

        _audit(
            cur, user["id"], "rental_billing_period", row["id"], "updated_by_date",
            {
                "rental_record_id": rental_id,
                "renewal_date": str(renewal_date),
                "payment_due_date": (
                    str(next_payment_due_date)
                    if next_payment_due_date is not None
                    else None
                ),
            },
        )
        emit_sync_event(
            cur, "rental_billing_period", row["id"], "updated",
            {"rental_record_id": rental_id, "renewal_date": str(renewal_date)},
        )
        conn.commit()
        return row

@app.get("/billing/reminders")
def billing_reminders(
    from_date: date = Query(...),
    to_date: date = Query(...),
    user=Depends(current_user),
):
    with db() as (_, cur):
        cur.execute(
            """
            select
              rbp.*,
              rr.customer_id,
              c.name as customer_name,
              rr.original_outbound_date,
              rr.invoice_preference
            from rental_billing_periods rbp
            join rental_records rr on rr.id = rbp.rental_record_id
            join customers c on c.id = rr.customer_id
            where rbp.renewal_date between %s and %s
            order by rbp.renewal_date, c.name
            """,
            (from_date, to_date),
        )
        return cur.fetchall()

# ---------- DOCUMENTS ----------
@app.post("/rentals/{rental_id}/documents")
def upload_document(
    rental_id: str,
    document_type: str = Form(...),
    rental_movement_id: str | None = Form(default=None),
    file: UploadFile = File(...),
    user=Depends(require_write),
):
    allowed_types = {
        "contract",
        "outbound_delivery",
        "inbound_delivery",
        "invoice",
        "other",
    }
    if document_type not in allowed_types:
        raise HTTPException(status_code=400, detail="Geçersiz belge türü.")

    extension = Path(file.filename or "").suffix.lower()
    allowed_extensions = {
        ".pdf", ".jpg", ".jpeg", ".png", ".doc", ".docx", ".xlsx"
    }
    if extension not in allowed_extensions:
        raise HTTPException(status_code=400, detail="Bu dosya türüne izin verilmiyor.")

    document_id = uuid.uuid4()
    folder = DOCUMENT_ROOT / rental_id
    folder.mkdir(parents=True, exist_ok=True)
    stored_name = f"{document_id}{extension}"
    target = folder / stored_name

    hasher = hashlib.sha256()
    with target.open("wb") as out:
        while True:
            chunk = file.file.read(1024 * 1024)
            if not chunk:
                break
            hasher.update(chunk)
            out.write(chunk)

    size_bytes = target.stat().st_size
    sha256 = hasher.hexdigest()

    with db() as (conn, cur):
        cur.execute(
            """
            select id, document_type, original_file_name, created_at
            from rental_documents
            where rental_record_id = %s
              and sha256 = %s
              and deleted_at is null
            """,
            (rental_id, sha256),
        )
        duplicate = cur.fetchone()
        if duplicate:
            target.unlink(missing_ok=True)
            return {**duplicate, "duplicate": True}

        cur.execute(
            """
            insert into rental_documents(
                id,
                rental_record_id,
                rental_movement_id,
                document_type,
                original_file_name,
                stored_file_name,
                mime_type,
                size_bytes,
                sha256,
                uploaded_by
            )
            values (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            returning id, document_type, original_file_name, created_at
            """,
            (
                document_id,
                rental_id,
                rental_movement_id,
                document_type,
                file.filename or stored_name,
                str(Path(rental_id) / stored_name),
                file.content_type,
                size_bytes,
                sha256,
                user["id"],
            ),
        )
        row = cur.fetchone()
        _audit(
            cur,
            user["id"],
            "rental_record",
            rental_id,
            "document_uploaded",
            {
                "document_id": str(document_id),
                "document_type": document_type,
                "rental_movement_id": rental_movement_id,
                "file_name": file.filename,
            },
        )
        emit_sync_event(
            cur,
            "rental_document",
            document_id,
            "created",
            {"rental_record_id": rental_id},
        )
        conn.commit()
        return row

def _document_file_response(document_id: str):
    with db() as (_, cur):
        cur.execute(
            """
            select stored_file_name, original_file_name, mime_type
            from rental_documents
            where id = %s and deleted_at is null
            """,
            (document_id,),
        )
        row = cur.fetchone()

    if not row:
        raise HTTPException(status_code=404, detail="Belge bulunamadı.")

    path = DOCUMENT_ROOT / row["stored_file_name"]
    if not path.exists():
        raise HTTPException(status_code=404, detail="Belge dosyası bulunamadı.")

    return FileResponse(
        path,
        media_type=row["mime_type"] or "application/octet-stream",
        filename=row["original_file_name"],
    )


@app.get("/documents/{document_id}/url")
def document_download_url(
    document_id: str,
    user=Depends(current_user),
):
    # Belge yoksa dış uygulamaya bozuk bir bağlantı vermeyelim.
    with db() as (_, cur):
        cur.execute(
            """
            select 1
            from rental_documents
            where id = %s and deleted_at is null
            """,
            (document_id,),
        )
        if not cur.fetchone():
            raise HTTPException(status_code=404, detail="Belge bulunamadı.")

    token = create_document_download_token(
        document_id,
        str(user["id"]),
    )
    return {
        "url": (
            f"/documents/{document_id}/signed-download"
            f"?token={token}"
        ),
        "expires_in_seconds": 300,
    }


@app.get(
    "/documents/{document_id}/signed-download",
    name="signed_download_document",
)
def signed_download_document(
    document_id: str,
    token: str = Query(...),
):
    verify_document_download_token(token, document_id)
    return _document_file_response(document_id)


@app.get("/documents/{document_id}/download")
def download_document(
    document_id: str,
    user=Depends(current_user),
):
    return _document_file_response(document_id)

# ---------- SYNC FEED ----------
@app.get("/sync/changes")
def sync_changes(
    after: int = Query(ge=0, default=0),
    limit: int = Query(ge=1, le=1000, default=250),
    user=Depends(current_user),
):
    with db() as (_, cur):
        cur.execute(
            """
            select seq, entity_type, entity_id, action, payload, created_at
            from sync_events
            where seq > %s
            order by seq
            limit %s
            """,
            (after, limit),
        )
        rows = cur.fetchall()

    return {
        "changes": rows,
        "last_seq": rows[-1]["seq"] if rows else after,
        "has_more": len(rows) == limit,
    }

# ---------- LEGACY IMPORT INBOX ----------
@app.post("/legacy-import/items")
def add_legacy_import_item(
    data: LegacyImportItemCreate,
    user=Depends(require_write),
):
    if data.source_kind not in (
        "contract",
        "delivery_table",
        "excel",
        "invoice",
        "other",
    ):
        raise HTTPException(status_code=400, detail="Geçersiz eski belge türü.")

    with db() as (conn, cur):
        cur.execute(
            """
            insert into legacy_import_items(
                source_file_name,
                source_kind,
                detected_customer_name,
                detected_date,
                notes,
                import_status,
                created_by
            )
            values (%s, %s, %s, %s, %s, 'pending_match', %s)
            returning *
            """,
            (
                data.source_file_name,
                data.source_kind,
                data.detected_customer_name,
                data.detected_date,
                data.notes,
                user["id"],
            ),
        )
        row = cur.fetchone()
        conn.commit()
        return row

@app.get("/legacy-import/items")
def list_legacy_import_items(
    status: str | None = None,
    user=Depends(current_user),
):
    with db() as (_, cur):
        if status:
            cur.execute(
                """
                select *
                from legacy_import_items
                where import_status = %s
                order by created_at
                """,
                (status,),
            )
        else:
            cur.execute(
                """
                select *
                from legacy_import_items
                order by created_at
                """
            )
        return cur.fetchall()


# ---------- SALES ----------
@app.get("/customers/{customer_id}/sales")
def customer_sales(customer_id: str, user=Depends(current_user)):
    with db() as (_, cur):
        cur.execute(
            """
            select
              s.id,
              s.sale_date,
              s.note,
              s.status,
              s.created_at,
              count(si.id) as item_count,
              coalesce(sum(si.line_total), 0) as total_amount
            from sales s
            left join sale_items si on si.sale_id = s.id
            where s.customer_id = %s
              and s.status = 'completed'
            group by s.id
            order by s.sale_date desc, s.created_at desc
            """,
            (customer_id,),
        )
        return cur.fetchall()

@app.post("/sales")
def create_sale(
    data: SaleCreate,
    user=Depends(require_write),
):
    if not data.items:
        raise HTTPException(status_code=400, detail="En az bir satış kalemi gerekli.")

    with db() as (conn, cur):
        ensure_new_operation(
            cur,
            data.client_operation_id,
            user["id"],
            "sale_create",
        )

        cur.execute(
            """
            insert into sales(id, customer_id, sale_date, note, created_by)
            values (coalesce(%s::uuid, gen_random_uuid()), %s, %s, %s, %s)
            returning *
            """,
            (
                data.id,
                data.customer_id,
                data.sale_date,
                data.note,
                user["id"],
            ),
        )
        sale = cur.fetchone()

        total = 0.0
        items = []
        for item in data.items:
            cur.execute(
                """
                select
                  p.name,
                  coalesce(
                    sum(sm.quantity) filter (where sm.bucket = 'available'),
                    0
                  ) as available
                from products p
                left join stock_movements sm on sm.product_id = p.id
                where p.id = %s
                group by p.id, p.name
                """,
                (item.product_id,),
            )
            stock = cur.fetchone()
            if stock is None:
                raise HTTPException(
                    status_code=400,
                    detail="Satış malzemesi bulunamadı.",
                )

            available = float(stock["available"])
            requested = float(item.quantity)
            if requested > available:
                raise HTTPException(
                    status_code=409,
                    detail={
                        "code": "insufficient_stock",
                        "product_id": str(item.product_id),
                        "product_name": stock["name"],
                        "available": available,
                        "requested": requested,
                        "message": (
                            f"{stock['name']} için kullanılabilir stok yetersiz. "
                            f"Mevcut: {available}, istenen: {requested}."
                        ),
                    },
                )

            cur.execute(
                """
                insert into sale_items(
                    sale_id,
                    product_id,
                    quantity,
                    unit_price
                )
                values (%s, %s, %s, %s)
                returning *
                """,
                (
                    sale["id"],
                    item.product_id,
                    item.quantity,
                    item.unit_price,
                ),
            )
            row = cur.fetchone()
            items.append(row)
            total += float(row["line_total"])

            cur.execute(
                """
                insert into stock_movements(
                    product_id,
                    bucket,
                    movement_type,
                    quantity,
                    movement_date,
                    source_type,
                    source_id,
                    created_by
                )
                values (%s, 'available', 'sale', %s, %s, 'sale', %s, %s)
                """,
                (
                    item.product_id,
                    -item.quantity,
                    data.sale_date,
                    sale["id"],
                    user["id"],
                ),
            )

        _audit(
            cur,
            user["id"],
            "sale",
            sale["id"],
            "created",
            {
                "customer_id": data.customer_id,
                "total_amount": total,
                "item_count": len(items),
            },
        )
        emit_sync_event(
            cur,
            "sale",
            sale["id"],
            "created",
            {
                "customer_id": data.customer_id,
                "total_amount": total,
            },
        )
        conn.commit()

        return {
            "sale": sale,
            "items": items,
            "total_amount": total,
        }

# ---------- STOCK ----------

@app.post("/stock/opening")
def opening_stock(
    data: OpeningStockCreate,
    user=Depends(require_write),
):
    with db() as (conn, cur):
        ensure_new_operation(
            cur,
            data.client_operation_id,
            user["id"],
            "opening_stock",
        )

        cur.execute(
            '''
            select count(*) as count
            from stock_movements
            where product_id = %s
            ''',
            (data.product_id,),
        )
        movement_count = int(cur.fetchone()["count"])
        if movement_count > 0:
            raise HTTPException(
                status_code=400,
                detail=(
                    "Bu malzemede daha önce stok hareketi var. "
                    "Açılış stoğu yerine fiziksel sayım/düzeltme kullanın."
                ),
            )

        cur.execute(
            '''
            insert into stock_movements(
                product_id,
                bucket,
                movement_type,
                quantity,
                movement_date,
                source_type,
                note,
                created_by
            )
            values (%s, 'available', 'opening', %s, %s, 'opening', %s, %s)
            returning *
            ''',
            (
                data.product_id,
                data.quantity,
                data.movement_date,
                data.note,
                user["id"],
            ),
        )
        row = cur.fetchone()

        cur.execute(
            '''
            update products
            set stock_confidence = 'estimated'
            where id = %s
              and stock_confidence = 'unknown'
            ''',
            (data.product_id,),
        )

        _audit(
            cur,
            user["id"],
            "stock",
            data.product_id,
            "opening_stock_created",
            {
                "quantity": data.quantity,
                "movement_date": str(data.movement_date),
            },
        )
        emit_sync_event(
            cur,
            "stock",
            data.product_id,
            "opening_stock_created",
            {"quantity": data.quantity},
        )
        conn.commit()
        return row

@app.post("/purchases")
def create_purchase(
    data: PurchaseCreate,
    user=Depends(require_write),
):
    if not data.items:
        raise HTTPException(
            status_code=400,
            detail="En az bir satın alma kalemi gerekli.",
        )

    with db() as (conn, cur):
        ensure_new_operation(
            cur,
            data.client_operation_id,
            user["id"],
            "purchase_create",
        )

        cur.execute(
            '''
            insert into purchases(
                supplier_name,
                purchase_date,
                invoice_no,
                note,
                created_by
            )
            values (%s, %s, %s, %s, %s)
            returning *
            ''',
            (
                data.supplier_name,
                data.purchase_date,
                data.invoice_no,
                data.note,
                user["id"],
            ),
        )
        purchase = cur.fetchone()

        items = []
        for item in data.items:
            cur.execute(
                '''
                insert into purchase_items(
                    purchase_id,
                    product_id,
                    quantity,
                    unit_cost
                )
                values (%s, %s, %s, %s)
                returning *
                ''',
                (
                    purchase["id"],
                    item.product_id,
                    item.quantity,
                    item.unit_cost,
                ),
            )
            pitem = cur.fetchone()
            items.append(pitem)

            cur.execute(
                '''
                insert into stock_movements(
                    product_id,
                    bucket,
                    movement_type,
                    quantity,
                    movement_date,
                    source_type,
                    source_id,
                    note,
                    created_by
                )
                values (
                    %s,
                    'available',
                    'purchase',
                    %s,
                    %s,
                    'purchase',
                    %s,
                    %s,
                    %s
                )
                ''',
                (
                    item.product_id,
                    item.quantity,
                    data.purchase_date,
                    purchase["id"],
                    data.note,
                    user["id"],
                ),
            )

            cur.execute(
                '''
                update products
                set stock_confidence = case
                  when stock_confidence = 'unknown' then 'estimated'
                  else stock_confidence
                end
                where id = %s
                ''',
                (item.product_id,),
            )

        _audit(
            cur,
            user["id"],
            "purchase",
            purchase["id"],
            "created",
            {
                "supplier_name": data.supplier_name,
                "purchase_date": str(data.purchase_date),
                "item_count": len(items),
            },
        )
        emit_sync_event(
            cur,
            "purchase",
            purchase["id"],
            "created",
            {"item_count": len(items)},
        )
        conn.commit()

        return {
            "purchase": purchase,
            "items": items,
        }



@app.post("/stock/repair-complete")
def repair_complete(
    data: RepairCompleteCreate,
    user=Depends(require_write),
):
    with db() as (conn, cur):
        ensure_new_operation(
            cur,
            data.client_operation_id,
            user["id"],
            "repair_complete",
        )

        cur.execute(
            """
            select coalesce(sum(quantity), 0) as repair_qty
            from stock_movements
            where product_id = %s
              and bucket = 'repair'
              and movement_date <= %s
            """,
            (data.product_id, data.movement_date),
        )
        available_repair = float(cur.fetchone()["repair_qty"])

        if data.quantity > available_repair:
            raise HTTPException(
                status_code=400,
                detail=f"Tamirlik stok {available_repair}. Daha fazlası çıkarılamaz.",
            )

        # repair bucket decreases
        cur.execute(
            """
            insert into stock_movements(
                product_id, bucket, movement_type, quantity,
                movement_date, source_type, note, created_by
            )
            values (%s, 'repair', 'repair_out', %s, %s, 'repair_complete', %s, %s)
            """,
            (
                data.product_id,
                -data.quantity,
                data.movement_date,
                data.note,
                user["id"],
            ),
        )

        # available bucket increases
        cur.execute(
            """
            insert into stock_movements(
                product_id, bucket, movement_type, quantity,
                movement_date, source_type, note, created_by
            )
            values (%s, 'available', 'repair_in', %s, %s, 'repair_complete', %s, %s)
            """,
            (
                data.product_id,
                data.quantity,
                data.movement_date,
                data.note,
                user["id"],
            ),
        )

        _audit(
            cur,
            user["id"],
            "stock",
            data.product_id,
            "repair_completed",
            {
                "quantity": data.quantity,
                "movement_date": str(data.movement_date),
            },
        )
        emit_sync_event(
            cur,
            "stock",
            data.product_id,
            "repair_completed",
            {"quantity": data.quantity},
        )
        conn.commit()

        return {
            "product_id": data.product_id,
            "quantity": data.quantity,
            "from": "repair",
            "to": "available",
        }

@app.post("/stock/write-off")
def stock_write_off(
    data: StockWriteOffCreate,
    user=Depends(require_write),
):
    if data.reason not in ("scrap", "lost"):
        raise HTTPException(
            status_code=400,
            detail="Silme nedeni scrap veya lost olmalı.",
        )
    if data.source_bucket not in ("available", "repair"):
        raise HTTPException(
            status_code=400,
            detail="Kaynak stok available veya repair olmalı.",
        )

    with db() as (conn, cur):
        ensure_new_operation(
            cur,
            data.client_operation_id,
            user["id"],
            "stock_write_off",
        )

        cur.execute(
            """
            select coalesce(sum(quantity), 0) as qty
            from stock_movements
            where product_id = %s
              and bucket = %s
              and movement_date <= %s
            """,
            (
                data.product_id,
                data.source_bucket,
                data.movement_date,
            ),
        )
        source_qty = float(cur.fetchone()["qty"])

        if data.quantity > source_qty:
            raise HTTPException(
                status_code=400,
                detail=f"Kaynak stok {source_qty}. Daha fazlası düşülemez.",
            )

        # Remove from source bucket
        source_type = (
            "scrap"
            if data.reason == "scrap"
            else "lost"
        )
        cur.execute(
            """
            insert into stock_movements(
                product_id, bucket, movement_type, quantity,
                movement_date, source_type, note, created_by
            )
            values (%s, %s, %s, %s, %s, 'write_off', %s, %s)
            """,
            (
                data.product_id,
                data.source_bucket,
                source_type,
                -data.quantity,
                data.movement_date,
                data.note,
                user["id"],
            ),
        )

        # Add informational total to destination bucket.
        destination_bucket = data.reason
        cur.execute(
            """
            insert into stock_movements(
                product_id, bucket, movement_type, quantity,
                movement_date, source_type, note, created_by
            )
            values (%s, %s, %s, %s, %s, 'write_off', %s, %s)
            """,
            (
                data.product_id,
                destination_bucket,
                source_type,
                data.quantity,
                data.movement_date,
                data.note,
                user["id"],
            ),
        )

        _audit(
            cur,
            user["id"],
            "stock",
            data.product_id,
            "write_off",
            {
                "reason": data.reason,
                "quantity": data.quantity,
                "source_bucket": data.source_bucket,
                "movement_date": str(data.movement_date),
            },
        )
        emit_sync_event(
            cur,
            "stock",
            data.product_id,
            "write_off",
            {
                "reason": data.reason,
                "quantity": data.quantity,
            },
        )
        conn.commit()

        return {
            "product_id": data.product_id,
            "reason": data.reason,
            "quantity": data.quantity,
            "from": data.source_bucket,
            "to": destination_bucket,
        }


@app.get("/stock/summary")
def stock_summary(user=Depends(current_user)):
    with db() as (_, cur):
        cur.execute(
            """
            select
              product_id,
              product_name,
              category,
              unit,
              trade_mode,
              stock_confidence,
              last_count_at,
              available_quantity,
              repair_quantity,
              scrap_quantity,
              lost_quantity
            from v_stock_summary
            order by product_name
            """
        )
        rows = cur.fetchall()

    return [
        {
            "product_id": str(row["product_id"]),
            "product_name": row["product_name"],
            "category": row["category"],
            "unit": row["unit"],
            "trade_mode": row["trade_mode"],
            "available": row["available_quantity"],
            "repair": row["repair_quantity"],
            "scrap": row["scrap_quantity"],
            "lost": row["lost_quantity"],
            "last_count": row["last_count_at"],
            "confidence": row["stock_confidence"] or (
                "counted" if row["last_count_at"] else "estimated"
            ),
        }
        for row in rows
    ]


@app.get("/stock/products/{product_id}/summary")
def stock_product_summary(product_id: str, user=Depends(current_user)):
    with db() as (_, cur):
        cur.execute(
            """
            select
              coalesce(sum(quantity) filter (where bucket = 'available'), 0)
                as available,
              coalesce(sum(quantity) filter (where bucket = 'repair'), 0)
                as repair,
              coalesce(sum(quantity) filter (where bucket = 'scrap'), 0)
                as scrap,
              coalesce(sum(quantity) filter (where bucket = 'lost'), 0)
                as lost
            from stock_movements
            where product_id = %s
            """,
            (product_id,),
        )
        totals = cur.fetchone()

        cur.execute(
            """
            select
              sci.counted_quantity,
              sci.ledger_quantity,
              sci.adjustment_quantity,
              scs.counted_at
            from stock_count_items sci
            join stock_count_sessions scs on scs.id = sci.session_id
            where sci.product_id = %s
              and scs.status = 'completed'
            order by scs.counted_at desc, sci.created_at desc
            limit 1
            """,
            (product_id,),
        )
        last_count = cur.fetchone()

    return {
        "product_id": product_id,
        "available": totals["available"],
        "repair": totals["repair"],
        "scrap": totals["scrap"],
        "lost": totals["lost"],
        "last_count": last_count,
        "confidence": "counted" if last_count else "estimated",
    }

@app.post("/stock/counts")
def create_stock_count(
    data: StockCountCreate,
    user=Depends(require_write),
):
    if not data.items:
        raise HTTPException(status_code=400, detail="En az bir sayım kalemi gerekli.")

    with db() as (conn, cur):
        ensure_new_operation(
            cur,
            data.client_operation_id,
            user["id"],
            "stock_count_create",
        )

        cur.execute(
            """
            insert into stock_count_sessions(
                counted_at,
                note,
                created_by
            )
            values (%s, %s, %s)
            returning *
            """,
            (
                data.counted_at,
                data.note,
                user["id"],
            ),
        )
        session = cur.fetchone()

        results = []
        for item in data.items:
            cur.execute(
                """
                select coalesce(sum(quantity), 0) as ledger_quantity
                from stock_movements
                where product_id = %s
                  and bucket = 'available'
                  and movement_date <= %s
                """,
                (item.product_id, data.counted_at),
            )
            ledger = float(cur.fetchone()["ledger_quantity"])
            counted = float(item.counted_quantity)
            adjustment = counted - ledger

            cur.execute(
                """
                insert into stock_count_items(
                    session_id,
                    product_id,
                    ledger_quantity,
                    counted_quantity,
                    adjustment_quantity,
                    package_count,
                    loose_quantity
                )
                values (%s, %s, %s, %s, %s, %s, %s)
                returning *
                """,
                (
                    session["id"],
                    item.product_id,
                    ledger,
                    counted,
                    adjustment,
                    item.package_count,
                    item.loose_quantity,
                ),
            )
            row = cur.fetchone()
            results.append(row)

            cur.execute(
                """
                update products
                set stock_confidence = 'counted',
                    last_count_at = %s
                where id = %s
                """,
                (data.counted_at, item.product_id),
            )

            if adjustment != 0:
                cur.execute(
                    """
                    insert into stock_movements(
                        product_id,
                        bucket,
                        movement_type,
                        quantity,
                        movement_date,
                        source_type,
                        source_id,
                        note,
                        created_by
                    )
                    values (
                      %s,
                      'available',
                      'count_adjustment',
                      %s,
                      %s,
                      'stock_count',
                      %s,
                      'Fiziksel sayım düzeltmesi',
                      %s
                    )
                    """,
                    (
                        item.product_id,
                        adjustment,
                        data.counted_at,
                        session["id"],
                        user["id"],
                    ),
                )

        _audit(
            cur,
            user["id"],
            "stock_count",
            session["id"],
            "created",
            {
                "counted_at": str(data.counted_at),
                "item_count": len(results),
            },
        )
        emit_sync_event(
            cur,
            "stock_count",
            session["id"],
            "created",
            {"counted_at": str(data.counted_at)},
        )
        conn.commit()

        return {
            "session": session,
            "items": results,
        }



@app.get("/legacy-import/items/{item_id}")
def legacy_import_item_detail(
    item_id: str,
    user=Depends(current_user),
):
    with db() as (_, cur):
        cur.execute(
            """
            select *
            from legacy_import_items
            where id = %s
            """,
            (item_id,),
        )
        row = cur.fetchone()

    if not row:
        raise HTTPException(
            status_code=404,
            detail="Eski veri aktarım kaydı bulunamadı.",
        )
    return row

@app.patch("/legacy-import/items/{item_id}/match")
def match_legacy_import_item(
    item_id: str,
    data: LegacyImportMatchInput,
    user=Depends(require_write),
):
    if data.import_status not in (
        "pending_match", "matched", "imported", "skipped", "needs_review"
    ):
        raise HTTPException(status_code=400, detail="Geçersiz aktarım durumu.")

    if data.rental_record_id and not data.customer_id:
        raise HTTPException(
            status_code=400,
            detail="Kiralama eşleştirmesi için müşteri de seçilmelidir.",
        )

    with db() as (conn, cur):
        if data.rental_record_id:
            cur.execute(
                """
                select 1 from rental_records
                where id = %s and customer_id = %s
                """,
                (data.rental_record_id, data.customer_id),
            )
            if not cur.fetchone():
                raise HTTPException(
                    status_code=400,
                    detail="Seçilen Kiralama Takibi bu müşteriye ait değil.",
                )

        cur.execute(
            """
            update legacy_import_items
            set matched_customer_id = %s,
                matched_rental_record_id = %s,
                import_status = %s,
                notes = coalesce(%s, notes),
                updated_at = now()
            where id = %s
            returning *
            """,
            (data.customer_id, data.rental_record_id, data.import_status, data.notes, item_id),
        )
        row = cur.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Eski veri aktarım kaydı bulunamadı.")

        _audit(
            cur, user["id"], "legacy_import_item", item_id, "matched",
            {
                "customer_id": data.customer_id,
                "rental_record_id": data.rental_record_id,
                "import_status": data.import_status,
            },
        )
        conn.commit()
        return row

# ---------- HELPERS ----------

def _next_renewal(original_outbound_date: date, today: date) -> date:
    target_day = original_outbound_date.day

    def safe_date(year: int, month: int):
        last_day = calendar.monthrange(year, month)[1]
        return date(year, month, min(target_day, last_day))

    candidate = safe_date(today.year, today.month)
    if candidate < today:
        if today.month == 12:
            candidate = safe_date(today.year + 1, 1)
        else:
            candidate = safe_date(today.year, today.month + 1)
    return candidate

def _calculate_period_snapshot(cur, rental_id: str, renewal_date: date):
    """
    Billing snapshot rule:
    - Quantity = initial quantity - all returns dated on/before renewal date.
    - Rate = latest rate effective on/before renewal date.
    - fixed_monthly rate is charged once for that item.
    - per_unit_monthly rate = remaining quantity * unit rate.
    The snapshot is stored so later returns or price changes do not rewrite history.
    """
    cur.execute(
        """
        select
          ri.id,
          ri.product_id,
          p.name as product_name,
          p.unit,
          ri.initial_quantity
        from rental_items ri
        join products p on p.id = ri.product_id
        where ri.rental_record_id = %s
        order by p.name
        """,
        (rental_id,),
    )
    items = cur.fetchall()

    snapshot = []
    total = 0.0

    for item in items:
        cur.execute(
            """
            select coalesce(sum(quantity), 0) as returned
            from rental_movements
            where rental_item_id = %s
              and movement_type = 'inbound_return'
              and movement_date <= %s
              and voided_at is null
            """,
            (item["id"], renewal_date),
        )
        returned = float(cur.fetchone()["returned"])
        remaining = max(float(item["initial_quantity"]) - returned, 0.0)

        cur.execute(
            """
            select amount, rate_type, effective_from
            from rental_rates
            where rental_item_id = %s
              and effective_from <= %s
            order by effective_from desc, created_at desc
            limit 1
            """,
            (item["id"], renewal_date),
        )
        rate = cur.fetchone()

        line_amount = 0.0
        if rate:
            rate_amount = float(rate["amount"])
            if rate["rate_type"] == "fixed_monthly":
                line_amount = rate_amount if remaining > 0 else 0.0
            else:
                line_amount = remaining * rate_amount
        else:
            rate_amount = None

        total += line_amount
        snapshot.append(
            {
                "rental_item_id": str(item["id"]),
                "product_id": str(item["product_id"]),
                "product_name": item["product_name"],
                "unit": item["unit"],
                "remaining_quantity": remaining,
                "rate_amount": rate_amount,
                "rate_type": rate["rate_type"] if rate else None,
                "rate_effective_from": (
                    str(rate["effective_from"]) if rate else None
                ),
                "line_amount": line_amount,
            }
        )

    return total, snapshot

def _audit(cur, user_id, entity_type, entity_id, action, payload):
    cur.execute(
        """
        insert into audit_logs(user_id, entity_type, entity_id, action, payload)
        values (%s, %s, %s, %s, %s)
        """,
        (user_id, entity_type, str(entity_id), action, payload),
    )
