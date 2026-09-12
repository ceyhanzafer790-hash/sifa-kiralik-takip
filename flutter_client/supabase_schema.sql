-- ESKI / KULLANILMAYAN v0.5 REFERANSI.
-- v0.24 Supabase kullanmaz. Bu dosyayi güncel kurulumda çalıştırmayın.
-- Güncel veritabanı migrationları: ../server/migrations/0001..0009

-- Şifa İnşaat Kiralık Malzeme Takibi
-- v0.5 - temiz kurulum şeması
-- Bu dosya yeni Supabase projesinde tek seferde uygulanmak üzere hazırlanmıştır.

create extension if not exists "pgcrypto";

-- PERSONEL PROFİLLERİ
create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  role text not null default 'staff'
    check (role in ('admin', 'staff', 'viewer')),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

-- MÜŞTERİLER
create table if not exists customers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text,
  notes text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create table if not exists customer_addresses (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references customers(id) on delete cascade,
  label text not null,
  full_address text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

-- ÜRÜNLER
-- Ürün kimlikleri p01..p48 şeklinde sabit tutulur; mobil uygulama kataloğuyla birebir eşleşir.
create table if not exists products (
  id text primary key,
  name text not null,
  category text not null,
  unit text not null,
  trade_mode text not null default 'both'
    check (trade_mode in ('rental', 'sale', 'both')),
  variant text,
  pack_size numeric,
  stock_confidence text not null default 'unknown'
    check (stock_confidence in ('unknown', 'estimated', 'counted')),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

insert into products (id, name, category, unit, trade_mode)
values
  ('p01', 'RİGA FORM PLYWOOD', 'plywood_osb', 'sheet', 'both'),
  ('p02', 'WODEX PLYWOOD', 'plywood_osb', 'sheet', 'both'),
  ('p03', 'PERM BİRCH PLYWOOD', 'plywood_osb', 'sheet', 'both'),
  ('p04', '18 MM OSB', 'plywood_osb', 'sheet', 'both'),
  ('p05', '15 MM OSB', 'plywood_osb', 'sheet', 'both'),
  ('p06', '9 MM OSB', 'plywood_osb', 'sheet', 'both'),
  ('p07', '11 MM OSB', 'plywood_osb', 'sheet', 'both'),
  ('p08', 'Doka H20', 'timber_h20', 'piece', 'both'),
  ('p09', 'Extraform H20', 'timber_h20', 'piece', 'both'),
  ('p10', 'Form-On H20 Ahşap Kiriş', 'timber_h20', 'piece', 'both'),
  ('p11', 'H20 Kancası', 'timber_h20', 'piece', 'both'),
  ('p12', 'H20 Birleştirme Aparatı', 'timber_h20', 'piece', 'both'),
  ('p13', 'H20 Ahşap Kiriş – RUS', 'timber_h20', 'piece', 'both'),
  ('p14', 'H20 Ahşap Kiriş – M Wood', 'timber_h20', 'piece', 'both'),
  ('p15', 'Ara Bağlantı, Nibel', 'scaffold_connection', 'piece', 'both'),
  ('p16', 'Hareketli Kelepçe 48×48 mm', 'scaffold_connection', 'piece', 'both'),
  ('p17', 'ALÜMİNYUM MOBİL İSKELE', 'scaffold_connection', 'set', 'rental'),
  ('p18', 'İskele Kelepçesi Tij 12 mm', 'scaffold_connection', 'piece', 'both'),
  ('p19', 'Asansör Kelepçesi', 'scaffold_connection', 'piece', 'both'),
  ('p20', 'Sabit Kelepçe (Alman Tipi) 48 mm', 'scaffold_connection', 'piece', 'both'),
  ('p21', 'VKZ – SRZ ARA BAĞLANTI 100 CM', 'scaffold_connection', 'piece', 'both'),
  ('p22', 'Masa İskele Çerçeve 150×180 – 3 mm Boyalı', 'scaffold_connection', 'piece', 'both'),
  ('p23', 'Masa İskele Çapraz', 'scaffold_connection', 'piece', 'both'),
  ('p24', 'H Tipi Güvenlikli İskele', 'scaffold_connection', 'set', 'rental'),
  ('p25', '4 YOLLU BAŞLIK 120 CM BOYALI 8 mm', 'prop_adjustment', 'piece', 'both'),
  ('p26', 'TELESKOPİK DİKME DİREK', 'prop_adjustment', 'piece', 'rental'),
  ('p27', 'Ayar Mili Ø 38 – 4 mm', 'prop_adjustment', 'piece', 'both'),
  ('p28', '120 cm 48’lik Alt Ayar Mili', 'prop_adjustment', 'piece', 'both'),
  ('p29', 'Ayar Mili Somunu', 'prop_adjustment', 'piece', 'both'),
  ('p30', 'Teleskopik Direk Mekanizma Somun ve G Kanca', 'prop_adjustment', 'set', 'both'),
  ('p31', 'Ayar Mili Ø 48 – 5 mm', 'prop_adjustment', 'piece', 'both'),
  ('p32', 'Kalıp Yağı', 'formwork_tie', 'liter', 'sale'),
  ('p33', 'TAYROT MİLİ (TEİROT MİLİ)', 'formwork_tie', 'meter', 'both'),
  ('p34', 'KBS ÇİROZ 4 mm', 'formwork_tie', 'piece', 'both'),
  ('p35', 'Galvaniz Kalıp Kilidi – Çiroz 4 mm', 'formwork_tie', 'piece', 'both'),
  ('p36', 'Tie-rot Aynası (Tayrot Aynası)', 'formwork_tie', 'piece', 'both'),
  ('p37', 'Çakmalı Dübel 12 mm', 'formwork_tie', 'piece', 'sale'),
  ('p38', '90’lık Tierot Somunu (90’lık Tayrot Somunu)', 'formwork_tie', 'piece', 'both'),
  ('p39', '70’lik Tie-rot Somunu (Tayrot Somunu)', 'formwork_tie', 'piece', 'both'),
  ('p40', 'KBS Marka Kollu Çiroz Sıkma Makinesi', 'formwork_tie', 'piece', 'both'),
  ('p41', 'Karadeniz İnşaat Vinci Trifaze Sessiz Şanzımanlı', 'elevator_crane', 'piece', 'rental'),
  ('p42', 'Asansör Kum Kazanı', 'elevator_crane', 'piece', 'both'),
  ('p43', 'Asansör Tuğla Sepeti', 'elevator_crane', 'piece', 'both'),
  ('p44', 'Topraklama Şeridi Galvaniz 30×3,5 mm', 'site_materials', 'meter', 'sale'),
  ('p45', 'Çivi – İnşaat Çivisi', 'site_materials', 'kilogram', 'sale'),
  ('p46', 'Malzeme Sepeti / İstifleme Sepeti', 'site_materials', 'piece', 'both'),
  ('p47', 'Bağ Teli', 'site_materials', 'kilogram', 'sale'),
  ('p48', '60’lık Beton Vibratörü Kendinden Konvektörlü', 'site_materials', 'piece', 'rental')
on conflict (id) do update set
  name = excluded.name,
  category = excluded.category,
  unit = excluded.unit,
  trade_mode = excluded.trade_mode;

-- KİRALAMA TAKİBİ
create table if not exists rental_records (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references customers(id),
  address_id uuid references customer_addresses(id),
  original_outbound_date date not null,
  invoice_preference text not null default 'no_invoice'
    check (invoice_preference in ('invoice_required', 'no_invoice')),
  note text,
  status text not null default 'active'
    check (status in ('active', 'closed')),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create table if not exists rental_record_items (
  id uuid primary key default gen_random_uuid(),
  rental_record_id uuid not null references rental_records(id) on delete cascade,
  product_id text not null references products(id),
  initial_quantity numeric not null check (initial_quantity > 0),
  created_at timestamptz not null default now(),
  unique (rental_record_id, product_id)
);

create table if not exists rental_movements (
  id uuid primary key default gen_random_uuid(),
  rental_record_id uuid not null references rental_records(id) on delete cascade,
  product_id text not null references products(id),
  movement_type text not null
    check (movement_type in ('outbound', 'inbound_return')),
  quantity numeric not null check (quantity > 0),
  movement_date date not null,
  note text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

-- FİYAT GEÇMİŞİ
create table if not exists rental_item_rates (
  id uuid primary key default gen_random_uuid(),
  rental_record_id uuid not null references rental_records(id) on delete cascade,
  product_id text not null references products(id),
  effective_from date not null,
  amount numeric not null check (amount >= 0),
  rate_type text not null default 'per_unit_monthly'
    check (rate_type in ('per_unit_monthly', 'fixed_monthly')),
  currency_code text not null default 'TRY',
  note text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

-- KİRA DÖNEMİ / FATURA / TAHSİLAT
create table if not exists rental_billing_periods (
  id uuid primary key default gen_random_uuid(),
  rental_record_id uuid not null references rental_records(id) on delete cascade,
  renewal_date date not null,
  invoice_preference text not null
    check (invoice_preference in ('invoice_required', 'no_invoice')),
  invoice_status text not null default 'not_required'
    check (invoice_status in ('not_required', 'pending', 'issued')),
  invoice_date date,
  invoice_no text,
  billed_amount numeric,
  payment_status text not null default 'pending'
    check (payment_status in ('pending', 'partial', 'paid')),
  paid_amount numeric,
  created_at timestamptz not null default now(),
  unique (rental_record_id, renewal_date)
);

-- BELGELER
create table if not exists rental_documents (
  id uuid primary key default gen_random_uuid(),
  rental_record_id uuid not null references rental_records(id) on delete cascade,
  rental_movement_id uuid references rental_movements(id) on delete set null,
  document_type text not null
    check (document_type in (
      'contract',
      'outbound_delivery',
      'inbound_delivery',
      'invoice',
      'other'
    )),
  file_name text not null,
  storage_path text not null unique,
  mime_type text,
  uploaded_by uuid references auth.users(id),
  note text,
  created_at timestamptz not null default now()
);

-- STOK HAREKETLERİ
create table if not exists stock_movements (
  id uuid primary key default gen_random_uuid(),
  product_id text not null references products(id),
  movement_type text not null,
  quantity numeric not null,
  movement_date timestamptz not null default now(),
  source_type text,
  source_id uuid,
  notes text,
  created_by uuid references auth.users(id)
);

-- AUDIT LOG
create table if not exists app_audit_logs (
  id bigint generated always as identity primary key,
  user_id uuid references auth.users(id),
  entity_type text not null,
  entity_id text not null,
  action text not null,
  payload jsonb,
  created_at timestamptz not null default now()
);

-- INDEXLER
create index if not exists ix_customers_name on customers(name);
create index if not exists ix_rental_records_customer_date
  on rental_records(customer_id, original_outbound_date desc);
create index if not exists ix_rental_movements_record_date
  on rental_movements(rental_record_id, movement_date);
create index if not exists ix_rental_item_rates_lookup
  on rental_item_rates(rental_record_id, product_id, effective_from desc);
create index if not exists ix_rental_documents_record
  on rental_documents(rental_record_id, created_at desc);
create index if not exists ix_rental_billing_due_invoice
  on rental_billing_periods(renewal_date, invoice_status);

-- STORAGE
insert into storage.buckets (id, name, public)
values ('rental-documents', 'rental-documents', false)
on conflict (id) do nothing;

-- RLS
alter table profiles enable row level security;
alter table customers enable row level security;
alter table customer_addresses enable row level security;
alter table products enable row level security;
alter table rental_records enable row level security;
alter table rental_record_items enable row level security;
alter table rental_movements enable row level security;
alter table rental_item_rates enable row level security;
alter table rental_billing_periods enable row level security;
alter table rental_documents enable row level security;
alter table stock_movements enable row level security;
alter table app_audit_logs enable row level security;

-- Yardımcı rol fonksiyonu
create or replace function public.current_app_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select role from public.profiles where id = auth.uid() and active = true),
    'viewer'
  );
$$;

-- Okuma: giriş yapan aktif herkes
create policy "profiles self read"
on profiles for select to authenticated
using (id = auth.uid() or public.current_app_role() = 'admin');

create policy "customers read"
on customers for select to authenticated using (true);
create policy "addresses read"
on customer_addresses for select to authenticated using (true);
create policy "products read"
on products for select to authenticated using (true);
create policy "rental records read"
on rental_records for select to authenticated using (true);
create policy "rental items read"
on rental_record_items for select to authenticated using (true);
create policy "rental movements read"
on rental_movements for select to authenticated using (true);
create policy "rental rates read"
on rental_item_rates for select to authenticated using (true);
create policy "billing read"
on rental_billing_periods for select to authenticated using (true);
create policy "documents read"
on rental_documents for select to authenticated using (true);
create policy "stock read"
on stock_movements for select to authenticated using (true);
create policy "audit read admin"
on app_audit_logs for select to authenticated
using (public.current_app_role() = 'admin');

-- Yazma: admin + staff
create policy "customers write"
on customers for all to authenticated
using (public.current_app_role() in ('admin','staff'))
with check (public.current_app_role() in ('admin','staff'));

create policy "addresses write"
on customer_addresses for all to authenticated
using (public.current_app_role() in ('admin','staff'))
with check (public.current_app_role() in ('admin','staff'));

create policy "rental records write"
on rental_records for all to authenticated
using (public.current_app_role() in ('admin','staff'))
with check (public.current_app_role() in ('admin','staff'));

create policy "rental items write"
on rental_record_items for all to authenticated
using (public.current_app_role() in ('admin','staff'))
with check (public.current_app_role() in ('admin','staff'));

create policy "rental movements write"
on rental_movements for all to authenticated
using (public.current_app_role() in ('admin','staff'))
with check (public.current_app_role() in ('admin','staff'));

create policy "rental rates write"
on rental_item_rates for all to authenticated
using (public.current_app_role() in ('admin','staff'))
with check (public.current_app_role() in ('admin','staff'));

create policy "billing write"
on rental_billing_periods for all to authenticated
using (public.current_app_role() in ('admin','staff'))
with check (public.current_app_role() in ('admin','staff'));

create policy "documents write"
on rental_documents for all to authenticated
using (public.current_app_role() in ('admin','staff'))
with check (public.current_app_role() in ('admin','staff'));

create policy "stock write"
on stock_movements for all to authenticated
using (public.current_app_role() in ('admin','staff'))
with check (public.current_app_role() in ('admin','staff'));

create policy "audit insert"
on app_audit_logs for insert to authenticated
with check (auth.uid() = user_id);

-- Ürün katalog değişikliği sadece admin
create policy "products admin write"
on products for all to authenticated
using (public.current_app_role() = 'admin')
with check (public.current_app_role() = 'admin');

-- Profil yönetimi sadece admin
create policy "profiles admin write"
on profiles for all to authenticated
using (public.current_app_role() = 'admin')
with check (public.current_app_role() = 'admin');

-- Storage: giriş yapanlar okuyabilir; admin/staff yükleyebilir.
create policy "rental docs storage read"
on storage.objects for select to authenticated
using (bucket_id = 'rental-documents');

create policy "rental docs storage insert"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'rental-documents'
  and public.current_app_role() in ('admin','staff')
);

create policy "rental docs storage update"
on storage.objects for update to authenticated
using (
  bucket_id = 'rental-documents'
  and public.current_app_role() in ('admin','staff')
)
with check (
  bucket_id = 'rental-documents'
  and public.current_app_role() in ('admin','staff')
);

create policy "rental docs storage delete"
on storage.objects for delete to authenticated
using (
  bucket_id = 'rental-documents'
  and public.current_app_role() = 'admin'
);

-- REALTIME için tabloları publication'a ekle.
do $$
begin
  alter publication supabase_realtime add table customers;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table rental_records;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table rental_movements;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table rental_item_rates;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table rental_documents;
exception when duplicate_object then null;
end $$;

-- İlk admin kullanıcısı oluşturulduktan sonra kendi UUID'siyle şu komut çalıştırılır:
-- insert into profiles (id, full_name, role) values ('AUTH_USER_UUID', 'Zafer', 'admin');
