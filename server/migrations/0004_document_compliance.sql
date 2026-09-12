create index if not exists ix_rental_documents_movement_type
  on rental_documents(rental_movement_id, document_type)
  where deleted_at is null;

create index if not exists ix_rental_records_status_customer
  on rental_records(status, customer_id)
  where deleted_at is null;

create or replace view v_rental_document_compliance as
select
  rr.id as rental_record_id,
  rr.customer_id,
  c.name as customer_name,
  rr.address_id,
  ca.label as address_label,
  rr.original_outbound_date,
  rr.status,
  not exists (
    select 1
    from rental_documents rd
    where rd.rental_record_id = rr.id
      and rd.document_type = 'contract'
      and rd.deleted_at is null
  ) as contract_missing,
  (
    select count(*)
    from rental_movements rm
    where rm.rental_record_id = rr.id
      and rm.movement_type = 'outbound'
      and rm.voided_at is null
      and not exists (
        select 1
        from rental_documents rd
        where rd.rental_movement_id = rm.id
          and rd.document_type = 'outbound_delivery'
          and rd.deleted_at is null
      )
  )::integer as outbound_document_missing_count,
  (
    select count(*)
    from rental_movements rm
    where rm.rental_record_id = rr.id
      and rm.movement_type = 'inbound_return'
      and rm.voided_at is null
      and not exists (
        select 1
        from rental_documents rd
        where rd.rental_movement_id = rm.id
          and rd.document_type = 'inbound_delivery'
          and rd.deleted_at is null
      )
  )::integer as inbound_document_missing_count
from rental_records rr
join customers c on c.id = rr.customer_id
left join customer_addresses ca on ca.id = rr.address_id
where rr.deleted_at is null
  and c.deleted_at is null;
