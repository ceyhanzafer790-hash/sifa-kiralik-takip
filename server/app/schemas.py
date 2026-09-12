from datetime import date
from pydantic import BaseModel, Field

class LoginInput(BaseModel):
    email: str
    password: str

class CustomerCreate(BaseModel):
    id: str | None = None
    name: str = Field(min_length=1)
    phone: str | None = None
    notes: str | None = None
    client_operation_id: str | None = None

class CustomerAddressCreate(BaseModel):
    id: str | None = None
    label: str = Field(min_length=1)
    full_address: str | None = None
    client_operation_id: str | None = None

class RentalItemCreate(BaseModel):
    id: str | None = None
    outbound_movement_id: str | None = None
    first_rate_id: str | None = None
    product_id: str
    quantity: float = Field(gt=0)
    first_rate_amount: float | None = Field(default=None, ge=0)
    rate_type: str = "per_unit_monthly"

class RentalCreate(BaseModel):
    id: str | None = None
    customer_id: str
    address_id: str | None = None
    original_outbound_date: date
    invoice_preference: str = "no_invoice"
    note: str | None = None
    items: list[RentalItemCreate]
    client_operation_id: str | None = None

class ReturnCreate(BaseModel):
    id: str | None = None
    rental_item_id: str
    quantity: float = Field(gt=0)
    movement_date: date
    return_condition: str = "usable"
    note: str | None = None
    client_operation_id: str | None = None

class RateCreate(BaseModel):
    id: str | None = None
    rental_item_id: str
    effective_from: date
    amount: float = Field(ge=0)
    rate_type: str = "per_unit_monthly"
    note: str | None = None
    client_operation_id: str | None = None

class InvoicePreferenceUpdate(BaseModel):
    invoice_preference: str
    expected_version: int | None = None
    client_operation_id: str | None = None

class BillingPeriodCreate(BaseModel):
    renewal_date: date
    client_operation_id: str | None = None

class BillingPeriodUpdate(BaseModel):
    invoice_status: str | None = None
    expected_version: int | None = None
    invoice_date: date | None = None
    invoice_no: str | None = None
    payment_due_date: date | None = None
    payment_status: str | None = None
    paid_amount: float | None = Field(default=None, ge=0)
    client_operation_id: str | None = None

class LegacyImportItemCreate(BaseModel):
    source_file_name: str
    source_kind: str
    detected_customer_name: str | None = None
    detected_date: date | None = None
    notes: str | None = None


class SaleItemCreate(BaseModel):
    product_id: str
    quantity: float = Field(gt=0)
    unit_price: float = Field(ge=0)

class SaleCreate(BaseModel):
    id: str | None = None
    customer_id: str
    sale_date: date
    note: str | None = None
    items: list[SaleItemCreate]
    client_operation_id: str | None = None

class StockCountItemCreate(BaseModel):
    product_id: str
    counted_quantity: float = Field(ge=0)
    package_count: float | None = Field(default=None, ge=0)
    loose_quantity: float | None = Field(default=None, ge=0)

class StockCountCreate(BaseModel):
    counted_at: date
    note: str | None = None
    items: list[StockCountItemCreate]
    client_operation_id: str | None = None


class RepairCompleteCreate(BaseModel):
    product_id: str
    quantity: float = Field(gt=0)
    movement_date: date
    note: str | None = None
    client_operation_id: str | None = None

class StockWriteOffCreate(BaseModel):
    product_id: str
    quantity: float = Field(gt=0)
    movement_date: date
    reason: str
    source_bucket: str = "available"
    note: str | None = None
    client_operation_id: str | None = None


class AdminUserCreate(BaseModel):
    email: str
    password: str = Field(min_length=8)
    full_name: str = Field(min_length=1)
    role: str = "staff"

class AdminUserRoleUpdate(BaseModel):
    role: str

class AdminUserActiveUpdate(BaseModel):
    active: bool

class AdminUserPasswordReset(BaseModel):
    new_password: str = Field(min_length=8)


class OpeningStockCreate(BaseModel):
    product_id: str
    quantity: float = Field(ge=0)
    movement_date: date
    note: str | None = None
    client_operation_id: str | None = None

class PurchaseItemCreate(BaseModel):
    product_id: str
    quantity: float = Field(gt=0)
    unit_cost: float | None = Field(default=None, ge=0)

class PurchaseCreate(BaseModel):
    supplier_name: str | None = None
    purchase_date: date
    invoice_no: str | None = None
    note: str | None = None
    items: list[PurchaseItemCreate]
    client_operation_id: str | None = None


class LegacyImportMatchInput(BaseModel):
    customer_id: str | None = None
    rental_record_id: str | None = None
    import_status: str = "matched"
    notes: str | None = None


class BillingPeriodByDateUpdate(BaseModel):
    invoice_status: str | None = None
    invoice_date: date | None = None
    invoice_no: str | None = None
    payment_due_date: date | None = None
    payment_status: str | None = None
    paid_amount: float | None = Field(default=None, ge=0)
    expected_version: int | None = None
    client_operation_id: str | None = None
