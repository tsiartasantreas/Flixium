# iFlixify IPTV — Install & Setup

This is the single doc for bringing the Phase 0 foundation online. Follow top to bottom.

---

## 0. Prerequisites (already on this machine)
- Flutter 3.44.8 (stable) at `/Applications/Flutter`
- Node 26, git 2.55, Wasmer CLI 7.2.1, Docker (unused for backend)
- Supabase CLI — install if missing: `brew install supabase/tap/supabase`

## 1. Supabase Cloud project (manual, ~5 min)
1. Go to https://supabase.com → **New Project**.
2. Name: **`iFlixify IPTV`**. Set a strong DB password (save it). Pick your region. **Create**.
3. Once provisioned, open **Project Settings → API** and collect:
   - **Project URL** (e.g. `https://abcd1234.supabase.co`)
   - **anon / public key**
   - **service_role key** (keep secret — never goes in the app)
   - **Project ref** (the `abcd1234` in the URL, also in Settings → API)

## 2. Apply the schema (CLI)
```bash
cd /Users/andreastsiartas/Documents/iFlixify IPTV/infra/supabase
supabase login
supabase link --project-ref <PROJECT_REF>
supabase db push                 # applies migrations/00001..00005
```
Verify in **Supabase Studio → Table Editor**: `profiles`, `licenses`, `devices`, `activation_codes`, `watch_progress_sync`, `favorites_sync`, `feature_flags`, `admin_audit_log` all exist.

## 3. Make yourself the admin (Studio)
The `auth.users` seed insert is fiddly; do this in the dashboard instead:
1. **Supabase Studio → Authentication → Users → Add user**. Enter your email + a password. Confirm the user.
2. **Table Editor → profiles** → find your row → set `is_admin = true`, `tier = 'pro'`. (Save.)
3. **SQL Editor** → run:
   ```sql
   insert into public.licenses (email, status, source, amount, activated_at)
   values ('YOUR_EMAIL@example.com', 'active', 'manual', 8.99, now())
   on conflict do nothing;
   ```
   Replace with your email.

## 4. Create the Wasmer Edge app
```bash
cd /Users/andreastsiartas/Documents/iFlixify IPTV/edge
# Replace YOUR_WASMER_USERNAME in app.yaml with your Wasmer username first.
wasmer login
wasmer app create --owner <YOUR_WASMER_USERNAME> --name iflixify-edge
```
Note the app URL Wasmer assigns (e.g. `https://iflixify-edge-<user>.wasmer.app`).

## 5. Set Wasmer secrets (for P0 only `GITHUB_REPO`; more added in P4)
```bash
wasmer app secret create GITHUB_REPO=andreastsiartas/iFlixify-IPTV --app-id <APP_ID>
```
(Get `<APP_ID>` from `wasmer app list` or the deploy output.)

## 6. Deploy the edge app
```bash
cd edge
wasmer deploy
```
Smoke-test:
```bash
curl -I https://iflixify-edge-<user>.wasmer.app/dl/latest
# Expect: HTTP/2 302  (or 404 if no releases yet — that's fine in P0)
```
⚠️ If `wasmer deploy` rewrites `app.yaml` into something invalid (wasmer#6803), `git checkout edge/app.yaml` and redeploy.

## 7. Generate a release keystore (for signed APKs)
```bash
keytool -genkey -v -keystore iflixify-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias iflixify
```
Save the `.jks` somewhere private. Add these GitHub repo secrets (Settings → Secrets → Actions):
- `RELEASE_KEYSTORE_BASE64` = `base64 -i iflixify-release.jks | pbcopy` output
- `RELEASE_STORE_PASSWORD`, `RELEASE_KEY_PASSWORD`, `RELEASE_KEY_ALIAS` = `iflixify`

Until you do this, `release.yml` uploads **unsigned** APKs with a warning.

## 8. First release + sideload test
```bash
git tag v0.1.0
git push origin v0.1.0
```
Watch the **Release** workflow on GitHub. When it's green, a GitHub Release exists with two APKs.
On your Fire TV / Android TV:
1. Install the **Downloader** app.
2. Open Downloader → **Settings** → enable **Install unknown apps** for Downloader.
3. In Downloader's URL bar, type:
   ```
   https://iflixify-edge-<user>.wasmer.app/dl/latest
   ```
4. The APK downloads → install → open iFlixify IPTV.

## 9. (Optional, once) Claim a short Downloader code
The Downloader app's short codes are operated by AFTVnews, not us. To claim one:
1. On your TV, open Downloader → **Browser** → navigate to `go.aftvnews.com`.
2. Search/claim your preferred code (e.g. `iptv` if available).
3. Set its target URL to `https://iflixify-edge-<user>.wasmer.app/dl/latest`.
4. From then on, typing that code in Downloader resolves to the latest APK.

## 10. Flutter local dev
```bash
cd app
flutter run \
  --dart-define=SUPABASE_URL=<URL> \
  --dart-define=SUPABASE_ANON_KEY=<ANON_KEY> \
  -d <device-id>
```
For TV: enable USB debugging on the stick, `adb connect <IP>:5555`, then `flutter run -d <tv-id>`.
