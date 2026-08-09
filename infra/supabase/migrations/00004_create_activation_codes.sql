-- activation_codes: short-lived, maps a checkout → device (spec §5.2)
create table if not exists public.activation_codes (
  code uuid primary key default gen_random_uuid(),
  email text not null,
  device_fingerprint text not null,
  status text not null default 'pending' check (status in ('pending','used','expired')),
  revolut_order_id text,
  expires_at timestamptz not null default (now() + interval '1 hour'),
  created_at timestamptz not null default now()
);

create index if not exists activation_codes_email_idx on public.activation_codes(email);

alter table public.activation_codes enable row level security;
create policy "activation_codes_no_client_access" on public.activation_codes
  for all using (false) with check (false);
