-- watch_progress_sync: Pro cross-device resume (spec §5.2)
create table if not exists public.watch_progress_sync (
  user_id uuid not null references auth.users(id) on delete cascade,
  content_id text not null,
  position_ms bigint not null,
  duration_ms bigint,
  updated_at timestamptz not null default now(),
  primary key (user_id, content_id)
);
alter table public.watch_progress_sync enable row level security;
create policy "watch_progress_owner_rw" on public.watch_progress_sync
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- favorites_sync: Free+Pro cloud favorites backup (spec §5.2)
create table if not exists public.favorites_sync (
  user_id uuid not null references auth.users(id) on delete cascade,
  content_id text not null,
  playlist_id text,
  added_at timestamptz not null default now(),
  primary key (user_id, content_id)
);
alter table public.favorites_sync enable row level security;
create policy "favorites_owner_rw" on public.favorites_sync
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- feature_flags: admin-controlled toggles (spec §5.2). World-readable, admin-writable only.
create table if not exists public.feature_flags (
  key text primary key,
  value jsonb not null default '{}',
  audience text not null default 'all' check (audience in ('all','free','pro','admin')),
  updated_at timestamptz not null default now()
);
alter table public.feature_flags enable row level security;
create policy "feature_flags_world_read" on public.feature_flags
  for select using (true);
-- No insert/update/delete policy for anon/authenticated → writes only via service-role.

-- admin_audit_log: every admin action (spec §5.2)
create table if not exists public.admin_audit_log (
  id bigserial primary key,
  admin_id uuid not null references auth.users(id),
  action text not null,
  target text,
  payload jsonb,
  ts timestamptz not null default now()
);
alter table public.admin_audit_log enable row level security;
-- Insert via service-role only; admins read their own audit entries.
create policy "audit_admin_read_own" on public.admin_audit_log
  for select using (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
  );
