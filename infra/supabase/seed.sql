-- Seed: your admin profile + a test Pro license.
-- Replace YOUR_ADMIN_EMAIL below with the email you'll sign in with.
-- Re-run manually after applying migrations: `supabase db execute < seed.sql`

-- 1. Create the admin auth user (magic-link / password set by you in Studio).
--    This insert requires the auth.admin API; run it from Supabase Studio SQL editor
--    if your CLI service-role isn't handy. Placeholder email — CHANGE IT.
insert into auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at, aud, role, instance_id, app_metadata, user_metadata)
values (
  '00000000-0000-0000-0000-000000000001',
  'YOUR_ADMIN_EMAIL@example.com',
  '', -- set a real password in Studio; this is a placeholder
  now(), now(), now(),
  'authenticated', 'authenticated',
  '00000000-0000-0000-0000-000000000000',
  '{}'::jsonb, '{}'::jsonb
) on conflict (id) do nothing;

-- 2. Promote that user's profile to admin + pro.
insert into public.profiles (id, email, is_admin, tier)
values ('00000000-0000-0000-0000-000000000001', 'YOUR_ADMIN_EMAIL@example.com', true, 'pro')
on conflict (id) do update set is_admin = true, tier = 'pro';

-- 3. A test Pro license for the admin email.
insert into public.licenses (email, status, source, amount, activated_at)
values ('YOUR_ADMIN_EMAIL@example.com', 'active', 'manual', 8.99, now())
on conflict do nothing;

-- 4. A default feature flag.
insert into public.feature_flags (key, value, audience)
values ('show_upgrade_prompts', 'true'::jsonb, 'all')
on conflict (key) do nothing;
