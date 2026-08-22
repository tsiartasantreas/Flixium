-- 00006: Pro cross-device playlist backup + device license extension packs
--
-- SECURITY NOTE (playlists_sync): the url / username / password columns
-- store CLIENT-SIDE ENCRYPTED strings, never plaintext. The app encrypts
-- credentials with EncryptionService (AES-256-CBC, key derived from a fixed
-- app secret + the user's Supabase user ID) BEFORE upload, and decrypts
-- AFTER download with the same user-scoped key. Because the key is scoped to
-- the Supabase user ID, only the owning user's devices can decrypt the
-- credentials, and plaintext never transits or rests in Supabase.

-- playlists_sync: Pro cross-device playlist backup
create table if not exists public.playlists_sync (
  user_id uuid not null references auth.users(id) on delete cascade,
  playlist_id text not null,
  name text not null,
  url text not null,
  username text,
  password text,
  playlist_type text not null default 'xtream',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, playlist_id)
);
alter table public.playlists_sync enable row level security;
drop policy if exists "playlists_sync_owner_rw" on public.playlists_sync;
create policy "playlists_sync_owner_rw" on public.playlists_sync
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- device_license_extensions: additional device packs ($3.99 per +5)
create table if not exists public.device_license_extensions (
  id uuid not null default gen_random_uuid() primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  additional_devices int not null default 5,
  source text not null default 'revolut',
  amount numeric not null default 3.99,
  created_at timestamptz not null default now()
);
alter table public.device_license_extensions enable row level security;
drop policy if exists "device_ext_owner_read" on public.device_license_extensions;
create policy "device_ext_owner_read" on public.device_license_extensions
  for select using (auth.uid() = user_id);
-- writes via service-role only (edge function on payment webhook)
