-- profiles: 1:1 with auth.users (spec §5.2)
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  display_name text,
  is_admin boolean not null default false,
  tier text not null default 'anonymous' check (tier in ('anonymous','free','pro')),
  created_at timestamptz not null default now()
);

-- Auto-create a profile row whenever a new auth.user is created.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, email)
  values (new.id, coalesce(new.email, ''))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- RLS
alter table public.profiles enable row level security;

-- A user can read their own profile.
create policy "profiles_select_own" on public.profiles
  for select using (auth.uid() = id);

-- A user can update their own display_name only (NOT tier or is_admin).
create policy "profiles_update_own_displayname" on public.profiles
  for update using (auth.uid() = id)
  with check (auth.uid() = id);

-- Lock tier and is_admin at the column level so even the owner can't self-promote.
revoke update (tier, is_admin) on public.profiles from authenticated, anon;
