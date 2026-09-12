-- RAPOR GÖRÜNÜMLERİ
create or replace view v_rental_item_status as
select
  rr.id as rental_record_id,
  c.id as customer_id,
  c.name as customer_name,
  ca.id as address_id,
  ca.label as address_label,
  ca.full_address,
  rr.original_outbound_date,
  rr.invoice_preference,
  rr.status as rental_status,
  ri.id as rental_item_id,
  p.id as product_id,
  p.name as product_name,
  p.unit,
  ri.initial_quantity,
  coalesce(ret.returned_quantity, 0) as returned_quantity,
  ri.initial_quantity - coalesce(ret.returned_quantity, 0) as remaining_quantity,
  rate.amount as current_rate,
  rate.rate_type as current_rate_type,
  rate.effective_from as current_rate_effective_from
from rental_records rr
join customers c on c.id = rr.customer_id
left join customer_addresses ca on ca.id = rr.address_id
join rental_items ri on ri.rental_record_id = rr.id
join products p on p.id = ri.product_id
left join lateral (
  select coalesce(sum(rm.quantity), 0) as returned_quantity
  from rental_movements rm
  where rm.rental_item_id = ri.id
    and rm.movement_type = 'inbound_return'
    and rm.voided_at is null
) ret on true
left join lateral (
  select
    r.amount,
    r.rate_type,
    r.effective_from
  from rental_rates r
  where r.rental_item_id = ri.id
    and r.effective_from <= current_date
  order by r.effective_from desc, r.created_at desc
  limit 1
) rate on true
where rr.deleted_at is null
  and c.deleted_at is null;

create or replace view v_stock_summary as
select
  p.id as product_id,
  p.name as product_name,
  p.category,
  p.unit,
  p.trade_mode,
  p.stock_confidence,
  p.last_count_at,
  coalesce(sum(sm.quantity) filter (where sm.bucket = 'available'), 0) as available_quantity,
  coalesce(sum(sm.quantity) filter (where sm.bucket = 'repair'), 0) as repair_quantity,
  coalesce(sum(sm.quantity) filter (where sm.bucket = 'scrap'), 0) as scrap_quantity,
  coalesce(sum(sm.quantity) filter (where sm.bucket = 'lost'), 0) as lost_quantity
from products p
left join stock_movements sm on sm.product_id = p.id
where p.active = true
group by
  p.id,
  p.name,
  p.category,
  p.unit,
  p.trade_mode,
  p.stock_confidence,
  p.last_count_at;

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
  rbp.billed_amount,
  rbp.payment_status,
  rbp.paid_amount,
  coalesce(rbp.billed_amount, 0) - coalesce(rbp.paid_amount, 0) as balance_amount,
  rbp.row_version
from rental_billing_periods rbp
join rental_records rr on rr.id = rbp.rental_record_id
join customers c on c.id = rr.customer_id
left join customer_addresses ca on ca.id = rr.address_id
where rr.deleted_at is null
  and c.deleted_at is null;
