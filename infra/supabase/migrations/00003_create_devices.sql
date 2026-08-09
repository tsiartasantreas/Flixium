-- devices: up to 5 active per license (spec §5.2, §9.4)
-- The 5-cap is enforced in the Wasmer register-device function, not here.
create table if not exists public.devices (
  id uuid primary key default gen_random_uuid(),
  license_id uuid not null references public.licenses(id) on delete cascade,
  email text not null,
  fingerprint text not null,
  name text,
  platform text,
  last_seen timestamptz not null default now(),
  revoked boolean not null default false,
  created_at timestamptz not null default now(),
  unique (license_id, fingerprint)
);

create index if not exists devices_license_idx on public.devices(license_id);

alter table public.devices enable row level security;
create policy "devices_no_client_access" on public.devices
  for all using (false) with check (false);
