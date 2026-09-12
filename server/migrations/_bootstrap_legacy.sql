-- Bu dosya normal migration değildir.
-- Sadece migration sistemi ilk kez eski bir Şifa veritabanına eklenirken çalışır.
-- Yeni boş veritabanında çalıştırılmaz.

alter table if exists customers
  add column if not exists deleted_at timestamptz;

alter table if exists customers
  add column if not exists updated_at timestamptz not null default now();

alter table if exists customers
  add column if not exists row_version bigint not null default 1;

alter table if exists rental_records
  add column if not exists deleted_at timestamptz;

alter table if exists rental_records
  add column if not exists updated_at timestamptz not null default now();

alter table if exists rental_records
  add column if not exists row_version bigint not null default 1;

alter table if exists rental_documents
  add column if not exists sha256 text;

alter table if exists products
  add column if not exists stock_confidence text not null default 'unknown';

alter table if exists products
  add column if not exists last_count_at date;

alter table if exists rental_billing_periods
  add column if not exists quantity_rate_snapshot jsonb not null default '[]'::jsonb;

alter table if exists rental_billing_periods
  add column if not exists row_version bigint not null default 1;

alter table if exists legacy_import_items
  add column if not exists source_path text;

alter table if exists legacy_import_items
  add column if not exists source_sha256 text;

alter table if exists legacy_import_items
  add column if not exists parser_json jsonb;
