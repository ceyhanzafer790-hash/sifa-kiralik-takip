create index if not exists ix_billing_open_receivables_age
  on rental_billing_periods(
    invoice_status,
    renewal_date,
    invoice_date
  )
  where invoice_status = 'issued';

create index if not exists ix_billing_open_receivables_customer
  on rental_billing_periods(
    rental_record_id,
    invoice_status,
    payment_status
  )
  where invoice_status = 'issued';


update app_runtime_settings
set latest_client_version = '0.23.0',
    updated_at = now()
where id = 1;
