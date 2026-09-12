alter table rental_billing_periods
  add column if not exists payment_due_date date;

create index if not exists ix_billing_payment_due_open
  on rental_billing_periods(payment_due_date, invoice_status, payment_status)
  where invoice_status = 'issued'
    and payment_due_date is not null;

create or replace view v_billing_report as
select
  rbp.id as billing_period_id,
  rbp.rental_record_id,
  c.id as customer_id,
  c.name as customer_name,
  ca.label as address_label,
  rr.original_outbound_date,
  rbp.renewal_date,
  rr.invoice_preference,
  rbp.invoice_status,
  rbp.invoice_date,
  rbp.invoice_no,
  rbp.payment_due_date,
  rbp.billed_amount,
  rbp.payment_status,
  rbp.paid_amount,
  coalesce(rbp.billed_amount, 0) - coalesce(rbp.paid_amount, 0)
    as balance_amount,
  rbp.row_version
from rental_billing_periods rbp
join rental_records rr on rr.id = rbp.rental_record_id
join customers c on c.id = rr.customer_id
left join customer_addresses ca on ca.id = rr.address_id
where rr.deleted_at is null
  and c.deleted_at is null;

update app_runtime_settings
set latest_client_version = '0.24.0',
    updated_at = now()
where id = 1;
