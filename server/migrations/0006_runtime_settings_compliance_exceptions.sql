create table if not exists app_runtime_settings (
  id smallint primary key default 1
    check (id = 1),
  maintenance_mode boolean not null default false,
  maintenance_message text,
  min_client_version text not null default '0.20.0',
  latest_client_version text not null default '0.21.0',
  enforce_min_client_version boolean not null default false,
  updated_by uuid references app_users(id),
  updated_at timestamptz not null default now()
);

insert into app_runtime_settings(
  id,
  maintenance_mode,
  maintenance_message,
  min_client_version,
  latest_client_version,
  enforce_min_client_version
)
values (
  1,
  false,
  null,
  '0.20.0',
  '0.21.0',
  false
)
on conflict (id) do nothing;

create table if not exists document_compliance_exceptions (
  id uuid primary key default gen_random_uuid(),
  rental_record_id uuid not null references rental_records(id),
  rental_movement_id uuid references rental_movements(id),
  document_type text not null
    check (document_type in (
      'contract',
      'outbound_delivery',
      'inbound_delivery'
    )),
  reason text not null,
  source_legacy_import_item_id uuid references legacy_import_items(id),
  active boolean not null default true,
  created_by uuid not null references app_users(id),
  created_at timestamptz not null default now(),
  revoked_by uuid references app_users(id),
  revoked_at timestamptz
);

create unique index if not exists ux_document_compliance_exception_active
  on document_compliance_exceptions(
    rental_record_id,
    coalesce(rental_movement_id, '00000000-0000-0000-0000-000000000000'::uuid),
    document_type
  )
  where active = true;

create index if not exists ix_document_compliance_exception_rental
  on document_compliance_exceptions(rental_record_id, active);

create or replace view v_rental_document_compliance as
select
  rr.id as rental_record_id,
  rr.customer_id,
  c.name as customer_name,
  rr.address_id,
  ca.label as address_label,
  rr.original_outbound_date,
  rr.status,
  (
    not exists (
      select 1
      from rental_documents rd
      where rd.rental_record_id = rr.id
        and rd.document_type = 'contract'
        and rd.deleted_at is null
    )
    and not exists (
      select 1
      from document_compliance_exceptions dce
      where dce.rental_record_id = rr.id
        and dce.rental_movement_id is null
        and dce.document_type = 'contract'
        and dce.active = true
    )
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
      and not exists (
        select 1
        from document_compliance_exceptions dce
        where dce.rental_record_id = rr.id
          and dce.rental_movement_id = rm.id
          and dce.document_type = 'outbound_delivery'
          and dce.active = true
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
      and not exists (
        select 1
        from document_compliance_exceptions dce
        where dce.rental_record_id = rr.id
          and dce.rental_movement_id = rm.id
          and dce.document_type = 'inbound_delivery'
          and dce.active = true
      )
  )::integer as inbound_document_missing_count
from rental_records rr
join customers c on c.id = rr.customer_id
left join customer_addresses ca on ca.id = rr.address_id
where rr.deleted_at is null
  and c.deleted_at is null;
