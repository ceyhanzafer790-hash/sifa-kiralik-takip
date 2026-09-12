create index if not exists ix_rental_rates_item_effective
  on rental_rates(rental_item_id, effective_from desc, created_at desc);

create index if not exists ix_rental_movements_item_type_date
  on rental_movements(rental_item_id, movement_type, movement_date)
  where voided_at is null;

create index if not exists ix_billing_invoice_payment_date
  on rental_billing_periods(invoice_status, payment_status, renewal_date);

create or replace view v_rental_revenue_estimate as
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
  current_rate_effective_from,
  case
    when rental_status <> 'active' then 0::numeric
    when remaining_quantity <= 0 then 0::numeric
    when current_rate is null then 0::numeric
    when current_rate_type = 'fixed_monthly' then current_rate
    else remaining_quantity * current_rate
  end as estimated_monthly_amount,
  (
    rental_status = 'active'
    and remaining_quantity > 0
    and current_rate is null
  ) as price_missing
from v_rental_item_status;
