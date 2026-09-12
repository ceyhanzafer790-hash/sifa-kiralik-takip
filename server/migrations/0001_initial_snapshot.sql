create extension if not exists pgcrypto;

create table if not exists app_users (
  id uuid primary key default gen_random_uuid(),
  email text not null unique,
  password_hash text not null,
  full_name text not null,
  role text not null default 'staff'
    check (role in ('admin','staff','viewer')),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists customers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text,
  notes text,
  deleted_at timestamptz,
  created_by uuid references app_users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  row_version bigint not null default 1
);

create table if not exists customer_addresses (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references customers(id),
  label text not null,
  full_address text,
  deleted_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists products (
  id text primary key,
  code text unique,
  name text not null,
  category text not null,
  unit text not null,
  trade_mode text not null default 'both'
    check (trade_mode in ('rental','sale','both')),
  variant text,
  package_size numeric,
  stock_confidence text not null default 'unknown'
    check (stock_confidence in ('unknown','estimated','counted')),
  last_count_at date,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

-- Şifa İnşaat başlangıç ürün kataloğu.
-- Kimlikler Flutter uygulamasıyla birebir aynıdır: p01..p48.
insert into products (id, code, name, category, unit, trade_mode)
values
  ('p01', 'p01', 'RİGA FORM PLYWOOD', 'plywood_osb', 'sheet', 'both'),
  ('p02', 'p02', 'WODEX PLYWOOD', 'plywood_osb', 'sheet', 'both'),
  ('p03', 'p03', 'PERM BİRCH PLYWOOD', 'plywood_osb', 'sheet', 'both'),
  ('p04', 'p04', '18 MM OSB', 'plywood_osb', 'sheet', 'both'),
  ('p05', 'p05', '15 MM OSB', 'plywood_osb', 'sheet', 'both'),
  ('p06', 'p06', '9 MM OSB', 'plywood_osb', 'sheet', 'both'),
  ('p07', 'p07', '11 MM OSB', 'plywood_osb', 'sheet', 'both'),
  ('p08', 'p08', 'Doka H20', 'timber_h20', 'piece', 'both'),
  ('p09', 'p09', 'Extraform H20', 'timber_h20', 'piece', 'both'),
  ('p10', 'p10', 'Form-On H20 Ahşap Kiriş', 'timber_h20', 'piece', 'both'),
  ('p11', 'p11', 'H20 Kancası', 'timber_h20', 'piece', 'both'),
  ('p12', 'p12', 'H20 Birleştirme Aparatı', 'timber_h20', 'piece', 'both'),
  ('p13', 'p13', 'H20 Ahşap Kiriş – RUS', 'timber_h20', 'piece', 'both'),
  ('p14', 'p14', 'H20 Ahşap Kiriş – M Wood', 'timber_h20', 'piece', 'both'),
  ('p15', 'p15', 'Ara Bağlantı, Nibel', 'scaffold_connection', 'piece', 'both'),
  ('p16', 'p16', 'Hareketli Kelepçe 48×48 mm', 'scaffold_connection', 'piece', 'both'),
  ('p17', 'p17', 'ALÜMİNYUM MOBİL İSKELE', 'scaffold_connection', 'set', 'rental'),
  ('p18', 'p18', 'İskele Kelepçesi Tij 12 mm', 'scaffold_connection', 'piece', 'both'),
  ('p19', 'p19', 'Asansör Kelepçesi', 'scaffold_connection', 'piece', 'both'),
  ('p20', 'p20', 'Sabit Kelepçe (Alman Tipi) 48 mm', 'scaffold_connection', 'piece', 'both'),
  ('p21', 'p21', 'VKZ – SRZ ARA BAĞLANTI 100 CM', 'scaffold_connection', 'piece', 'both'),
  ('p22', 'p22', 'Masa İskele Çerçeve 150×180 – 3 mm Boyalı', 'scaffold_connection', 'piece', 'both'),
  ('p23', 'p23', 'Masa İskele Çapraz', 'scaffold_connection', 'piece', 'both'),
  ('p24', 'p24', 'H Tipi Güvenlikli İskele', 'scaffold_connection', 'set', 'rental'),
  ('p25', 'p25', '4 YOLLU BAŞLIK 120 CM BOYALI 8 mm', 'prop_adjustment', 'piece', 'both'),
  ('p26', 'p26', 'TELESKOPİK DİKME DİREK', 'prop_adjustment', 'piece', 'rental'),
  ('p27', 'p27', 'Ayar Mili Ø 38 – 4 mm', 'prop_adjustment', 'piece', 'both'),
  ('p28', 'p28', '120 cm 48’lik Alt Ayar Mili', 'prop_adjustment', 'piece', 'both'),
  ('p29', 'p29', 'Ayar Mili Somunu', 'prop_adjustment', 'piece', 'both'),
  ('p30', 'p30', 'Teleskopik Direk Mekanizma Somun ve G Kanca', 'prop_adjustment', 'set', 'both'),
  ('p31', 'p31', 'Ayar Mili Ø 48 – 5 mm', 'prop_adjustment', 'piece', 'both'),
  ('p32', 'p32', 'Kalıp Yağı', 'formwork_tie', 'liter', 'sale'),
  ('p33', 'p33', 'TAYROT MİLİ (TEİROT MİLİ)', 'formwork_tie', 'meter', 'both'),
  ('p34', 'p34', 'KBS ÇİROZ 4 mm', 'formwork_tie', 'piece', 'both'),
  ('p35', 'p35', 'Galvaniz Kalıp Kilidi – Çiroz 4 mm', 'formwork_tie', 'piece', 'both'),
  ('p36', 'p36', 'Tie-rot Aynası (Tayrot Aynası)', 'formwork_tie', 'piece', 'both'),
  ('p37', 'p37', 'Çakmalı Dübel 12 mm', 'formwork_tie', 'piece', 'sale'),
  ('p38', 'p38', '90’lık Tierot Somunu (90’lık Tayrot Somunu)', 'formwork_tie', 'piece', 'both'),
  ('p39', 'p39', '70’lik Tie-rot Somunu (Tayrot Somunu)', 'formwork_tie', 'piece', 'both'),
  ('p40', 'p40', 'KBS Marka Kollu Çiroz Sıkma Makinesi', 'formwork_tie', 'piece', 'both'),
  ('p41', 'p41', 'Karadeniz İnşaat Vinci Trifaze Sessiz Şanzımanlı', 'elevator_crane', 'piece', 'rental'),
  ('p42', 'p42', 'Asansör Kum Kazanı', 'elevator_crane', 'piece', 'both'),
  ('p43', 'p43', 'Asansör Tuğla Sepeti', 'elevator_crane', 'piece', 'both'),
  ('p44', 'p44', 'Topraklama Şeridi Galvaniz 30×3,5 mm', 'site_materials', 'meter', 'sale'),
  ('p45', 'p45', 'Çivi – İnşaat Çivisi', 'site_materials', 'kilogram', 'sale'),
  ('p46', 'p46', 'Malzeme Sepeti / İstifleme Sepeti', 'site_materials', 'piece', 'both'),
  ('p47', 'p47', 'Bağ Teli', 'site_materials', 'kilogram', 'sale'),
  ('p48', 'p48', '60’lık Beton Vibratörü Kendinden Konvektörlü', 'site_materials', 'piece', 'rental')
on conflict (id) do update set
  code = excluded.code,
  name = excluded.name,
  category = excluded.category,
  unit = excluded.unit,
  trade_mode = excluded.trade_mode;

create table if not exists rental_records (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references customers(id),
  address_id uuid references customer_addresses(id),
  original_outbound_date date not null,
  invoice_preference text not null default 'no_invoice'
    check (invoice_preference in ('invoice_required','no_invoice')),
  status text not null default 'active'
    check (status in ('active','closed')),
  note text,
  deleted_at timestamptz,
  created_by uuid references app_users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  row_version bigint not null default 1
);

create table if not exists rental_items (
  id uuid primary key default gen_random_uuid(),
  rental_record_id uuid not null references rental_records(id),
  product_id text not null references products(id),
  initial_quantity numeric not null check (initial_quantity > 0),
  created_at timestamptz not null default now()
);

create table if not exists rental_movements (
  id uuid primary key default gen_random_uuid(),
  rental_record_id uuid not null references rental_records(id),
  rental_item_id uuid not null references rental_items(id),
  movement_type text not null
    check (movement_type in ('outbound','inbound_return')),
  quantity numeric not null check (quantity > 0),
  movement_date date not null,
  return_condition text
    check (return_condition in ('usable','repair','scrap')),
  note text,
  voided_at timestamptz,
  void_reason text,
  created_by uuid references app_users(id),
  created_at timestamptz not null default now()
);

create table if not exists rental_rates (
  id uuid primary key default gen_random_uuid(),
  rental_item_id uuid not null references rental_items(id),
  effective_from date not null,
  amount numeric not null check (amount >= 0),
  rate_type text not null default 'per_unit_monthly'
    check (rate_type in ('per_unit_monthly','fixed_monthly')),
  currency_code text not null default 'TRY',
  note text,
  created_by uuid references app_users(id),
  created_at timestamptz not null default now()
);

create table if not exists rental_documents (
  id uuid primary key default gen_random_uuid(),
  rental_record_id uuid not null references rental_records(id),
  rental_movement_id uuid references rental_movements(id),
  document_type text not null
    check (document_type in ('contract','outbound_delivery','inbound_delivery','invoice','other')),
  original_file_name text not null,
  stored_file_name text not null unique,
  mime_type text,
  size_bytes bigint,
  sha256 text,
  deleted_at timestamptz,
  uploaded_by uuid references app_users(id),
  created_at timestamptz not null default now()
);

create table if not exists audit_logs (
  id bigserial primary key,
  user_id uuid references app_users(id),
  entity_type text not null,
  entity_id text not null,
  action text not null,
  payload jsonb,
  created_at timestamptz not null default now()
);

create index if not exists ix_customers_name on customers(name);
create index if not exists ix_rental_records_customer
  on rental_records(customer_id, original_outbound_date desc);
create index if not exists ix_rental_movements_record
  on rental_movements(rental_record_id, movement_date);
create index if not exists ix_rental_rates_item
  on rental_rates(rental_item_id, effective_from desc);
create index if not exists ix_rental_documents_record
  on rental_documents(rental_record_id, created_at desc);

create table if not exists rental_billing_periods (
  id uuid primary key default gen_random_uuid(),
  rental_record_id uuid not null references rental_records(id),
  renewal_date date not null,
  invoice_status text not null default 'not_required'
    check (invoice_status in ('not_required','pending','issued')),
  invoice_date date,
  invoice_no text,
  payment_due_date date,
  billed_amount numeric,
  payment_status text not null default 'pending'
    check (payment_status in ('pending','partial','paid')),
  paid_amount numeric,
  quantity_rate_snapshot jsonb not null default '[]'::jsonb,
  row_version bigint not null default 1,
  created_at timestamptz not null default now(),
  unique (rental_record_id, renewal_date)
);

-- İstemci offline kuyruğunun aynı işlemi iki kez uygulamasını engellemek için.
create table if not exists client_operations (
  operation_id uuid primary key,
  user_id uuid references app_users(id),
  operation_type text not null,
  created_at timestamptz not null default now()
);

create index if not exists ix_rental_billing_renewal
  on rental_billing_periods(renewal_date, invoice_status);

-- Cihazlar arası artımlı senkronizasyon akışı.
create table if not exists sync_events (
  seq bigserial primary key,
  entity_type text not null,
  entity_id text not null,
  action text not null,
  payload jsonb,
  created_at timestamptz not null default now()
);

create index if not exists ix_sync_events_seq on sync_events(seq);

-- Eski sözleşme, sevkiyat tablosu, Excel ve diğer belgeler önce buraya alınır.
-- Emin olunmayan belge yanlış müşteriye bağlanmaz, "pending_match" kalır.
create table if not exists legacy_import_items (
  id uuid primary key default gen_random_uuid(),
  source_file_name text not null,
  source_path text,
  source_sha256 text,
  parser_json jsonb,
  source_kind text not null
    check (source_kind in (
      'contract',
      'delivery_table',
      'excel',
      'invoice',
      'other'
    )),
  detected_customer_name text,
  detected_date date,
  matched_customer_id uuid references customers(id),
  matched_rental_record_id uuid references rental_records(id),
  import_status text not null default 'pending_match'
    check (import_status in (
      'pending_match',
      'matched',
      'imported',
      'skipped',
      'needs_review'
    )),
  notes text,
  created_by uuid references app_users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists ix_legacy_import_status
  on legacy_import_items(import_status, created_at);

create unique index if not exists ux_legacy_import_source_sha256
  on legacy_import_items(source_sha256)
  where source_sha256 is not null;

-- SATIŞLAR
create table if not exists sales (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references customers(id),
  sale_date date not null,
  note text,
  status text not null default 'completed'
    check (status in ('completed','voided')),
  voided_at timestamptz,
  void_reason text,
  created_by uuid references app_users(id),
  created_at timestamptz not null default now()
);

create table if not exists sale_items (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references sales(id),
  product_id text not null references products(id),
  quantity numeric not null check (quantity > 0),
  unit_price numeric not null check (unit_price >= 0),
  line_total numeric generated always as (quantity * unit_price) stored,
  created_at timestamptz not null default now()
);

create index if not exists ix_sales_customer_date
  on sales(customer_id, sale_date desc);

-- STOK HAREKETLERİ
-- quantity depo kovasındaki değişimdir. Eksi çıkış, artı giriş.
create table if not exists stock_movements (
  id uuid primary key default gen_random_uuid(),
  product_id text not null references products(id),
  bucket text not null default 'available'
    check (bucket in ('available','repair','scrap','lost')),
  movement_type text not null
    check (movement_type in (
      'opening',
      'purchase',
      'rental_out',
      'rental_return',
      'sale',
      'repair_in',
      'repair_out',
      'scrap',
      'lost',
      'count_adjustment'
    )),
  quantity numeric not null,
  movement_date date not null,
  source_type text,
  source_id uuid,
  note text,
  created_by uuid references app_users(id),
  created_at timestamptz not null default now()
);

create index if not exists ix_stock_movements_product_date
  on stock_movements(product_id, movement_date, created_at);

-- FİZİKSEL SAYIM
create table if not exists stock_count_sessions (
  id uuid primary key default gen_random_uuid(),
  counted_at date not null,
  note text,
  status text not null default 'completed'
    check (status in ('completed','voided')),
  created_by uuid references app_users(id),
  created_at timestamptz not null default now()
);

create table if not exists stock_count_items (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references stock_count_sessions(id),
  product_id text not null references products(id),
  ledger_quantity numeric not null,
  counted_quantity numeric not null check (counted_quantity >= 0),
  adjustment_quantity numeric not null,
  package_count numeric,
  loose_quantity numeric,
  created_at timestamptz not null default now()
);

create index if not exists ix_stock_count_items_product
  on stock_count_items(product_id, created_at desc);

create unique index if not exists ux_app_users_email_lower on app_users(lower(email));


-- SATIN ALMALAR
create table if not exists purchases (
  id uuid primary key default gen_random_uuid(),
  supplier_name text,
  purchase_date date not null,
  invoice_no text,
  note text,
  created_by uuid references app_users(id),
  created_at timestamptz not null default now()
);

create table if not exists purchase_items (
  id uuid primary key default gen_random_uuid(),
  purchase_id uuid not null references purchases(id),
  product_id text not null references products(id),
  quantity numeric not null check (quantity > 0),
  unit_cost numeric,
  created_at timestamptz not null default now()
);

create index if not exists ix_purchases_date
  on purchases(purchase_date desc);

create unique index if not exists ux_rental_documents_sha256 on rental_documents(rental_record_id, sha256) where sha256 is not null and deleted_at is null;

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

create index if not exists ix_audit_logs_created_at
  on audit_logs(created_at desc);

create index if not exists ix_audit_logs_user_created
  on audit_logs(user_id, created_at desc);

create index if not exists ix_audit_logs_entity_created
  on audit_logs(entity_type, entity_id, created_at desc);

create index if not exists ix_audit_logs_action_created
  on audit_logs(action, created_at desc);

create table if not exists app_releases (
  id uuid primary key default gen_random_uuid(),
  version text not null,
  platform text not null
    check (platform in ('android', 'windows', 'ios')),
  file_name text not null,
  sha256 text not null
    check (length(sha256) = 64),
  size_bytes bigint not null check (size_bytes >= 0),
  download_path text,
  release_notes text,
  mandatory boolean not null default false,
  active boolean not null default true,
  created_by uuid references app_users(id),
  created_at timestamptz not null default now(),
  unique(version, platform, file_name)
);

create index if not exists ix_app_releases_platform_version
  on app_releases(platform, created_at desc)
  where active = true;

update app_runtime_settings
set latest_client_version = '0.22.0',
    updated_at = now()
where id = 1;

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
