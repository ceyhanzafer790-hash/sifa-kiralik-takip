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
