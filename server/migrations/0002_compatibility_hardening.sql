-- Eski geliştirme sürümlerinden gelen bir DB varsa eksik kolonları güvenle tamamlar.

alter table if exists customers
  add column if not exists row_version bigint not null default 1;

alter table if exists rental_records
  add column if not exists row_version bigint not null default 1;

alter table if exists rental_billing_periods
  add column if not exists quantity_rate_snapshot jsonb not null default '[]'::jsonb;

alter table if exists rental_billing_periods
  add column if not exists row_version bigint not null default 1;

alter table if exists rental_documents
  add column if not exists sha256 text;

alter table if exists products
  add column if not exists stock_confidence text not null default 'unknown';

alter table if exists products
  add column if not exists last_count_at date;

alter table if exists legacy_import_items
  add column if not exists source_path text;

alter table if exists legacy_import_items
  add column if not exists source_sha256 text;

alter table if exists legacy_import_items
  add column if not exists parser_json jsonb;

create unique index if not exists ux_rental_documents_sha256
  on rental_documents(rental_record_id, sha256)
  where sha256 is not null and deleted_at is null;

create unique index if not exists ux_legacy_import_source_sha256
  on legacy_import_items(source_sha256)
  where source_sha256 is not null;
