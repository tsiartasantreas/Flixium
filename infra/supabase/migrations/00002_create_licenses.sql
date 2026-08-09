-- licenses: one active row per email (email IS the license key) (spec §5.2)
create table if not exists public.licenses (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  status text not null check (status in ('pending','active','revoked')),
  source text not null check (source in ('revolut','manual')),
  amount numeric(10,2) not null default 8.99,
  revolut_order_id text,
  created_at timestamptz not null default now(),
  activated_at timestamptz,
  revoked_at timestamptz,
  revoked_reason text
);

create index if not exists licenses_email_idx on public.licenses(email);
create index if not exists licenses_status_idx on public.licenses(status);

-- NO client access: all reads/writes go through Wasmer functions (service-role).
alter table public.licenses enable row level security;
create policy "licenses_no_client_access" on public.licenses
  for all using (false) with check (false);
