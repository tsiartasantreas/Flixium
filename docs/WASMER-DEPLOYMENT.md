# iFlixify IPTV — Wasmer Edge Deployment Guide

This guide covers deploying the iFlixify IPTV edge functions (licensing API + `/dl/latest` APK redirect) to Wasmer Edge, and connecting them to the Supabase backend and Revolut payment gateway.

---

## Prerequisites

- **Wasmer CLI** installed: `curl https://get.wasmer.io -sSfL | sh`
- **Wasmer account** at https://wasmer.io (username: `tsiartasantreas`)
- **Supabase project** "iFlixify IPTV" active (project ref: `zosckkklctvrsjqjmyiv`)
- **Revolut Business** account with Merchant API enabled
- **GitHub repo** `tsiartasantreas/iFlixify-IPTV` with the APK releases

---

## Step 1: Authenticate with Wasmer

```bash
wasmer login
```
Opens your browser → authorize the CLI → the device code is shown in terminal.

Verify:
```bash
wasmer whoami
# → tsiartasantreas
```

---

## Step 2: Create the Edge App

### Option A: From the js-worker template (recommended for first deploy)
```bash
mkdir /tmp/iflixify-edge-init && cd /tmp/iflixify-edge-init
wasmer app create --template=js-worker --owner tsiartasantreas --name iflixify-edge
```
This creates the correct `app.yaml` and `src/index.js` structure for the Wasmer Edge JS runtime.

### Option B: From the existing edge/ directory
```bash
cd edge/
wasmer deploy --build-remote
```
Uses the `app.yaml` and `src/index.js` from the repo. The `--build-remote` flag tells Wasmer to detect the runtime (Node.js/QuickJS) and build remotely.

---

## Step 3: Set Secrets

Set the required environment variables as Wasmer secrets:

```bash
# GitHub repo for the /dl/latest redirect handler
wasmer app secret create GITHUB_REPO tsiartasantreas/iFlixify-IPTV --app iflixify-edge

# Supabase (Phase 4 — licensing backend)
wasmer app secret create SUPABASE_URL https://zosckkklctvrsjqjmyiv.supabase.co --app iflixify-edge
wasmer app secret create SUPABASE_SERVICE_ROLE_KEY <SERVICE_ROLE_KEY> --app iflixify-edge

# Revolut (Phase 4 — payment gateway)
wasmer app secret create REVOLUT_API_KEY <REVOLUT_API_KEY> --app iflixify-edge
wasmer app secret create REVOLUT_WEBHOOK_SECRET <WEBHOOK_SECRET> --app iflixify-edge

# Admin panel session
wasmer app secret create ADMIN_SESSION_SECRET <SESSION_SECRET> --app iflixify-edge
```

> **Note:** Secrets are not committed to the repo. They are set via the CLI and stored in the Wasmer secrets vault. Reference them in `app.yaml` as `${SECRET_NAME}`.

---

## Step 4: Deploy

```bash
cd edge/
wasmer deploy --build-remote
```

Expected output:
```
✔ App iflixify-edge (tsiartasantreas) deployed successfully.
Live:    https://iflixify-edge.wasmer.app
```

---

## Step 5: Verify the Deployment

### Test the `/dl/latest` redirect
```bash
curl -I https://iflixify-edge.wasmer.app/dl/latest
# Expect: HTTP/2 302 → redirects to the latest APK asset on GitHub Releases
```

### Test the edge app info
```bash
wasmer app get iflixify-edge
```

---

## Step 6: Auto-deploy via Git Push (optional)

To enable automatic deploys on every push to `main`:

1. Go to https://wasmer.io/apps/tsiartasantreas/iflixify-edge
2. Connect the GitHub repo `tsiartasantreas/iFlixify-IPTV`
3. Set the deploy branch to `main`
4. On every push to `main`, Wasmer will automatically rebuild and deploy

---

## Troubleshooting

### 500 Internal Server Error

The Wasmer Edge JS runtime (`edgejs-quickjs`) may have issues with certain JavaScript patterns. If you see 500:

1. **Check logs:** `wasmer app logs iflixify-edge`
2. **Minimal test:** Replace `src/index.js` with:
   ```javascript
   addEventListener("fetch", (fetchEvent) => {
     fetchEvent.respondWith(new Response("ok"));
   });
   ```
   Redeploy with `wasmer deploy --build-remote`. If this works, the issue is in the handler logic.

3. **EdgeJS runtime note:** The Wasmer Edge JS runtime uses QuickJS (not Node.js). Some Node.js APIs may not be available. The `addEventListener("fetch", ...)` pattern is the documented way to handle requests.

### Secrets not appearing in the app

After setting secrets, you must redeploy:
```bash
wasmer deploy --build-remote
```

### Deployment hangs on "Waiting for new deployment"

Press `Ctrl+C` to stop waiting. The deployment is likely already live at the URL shown.

---

## Architecture Reference

```
┌─────────────────────────────────────────────────────┐
│  WASMER EDGE APP (iflixify-edge)                       │
│  ├── /dl/latest → 302 → GitHub Release APK           │
│  ├── /api/checkout → Revolut payment (Phase 4)       │
│  ├── /api/webhook → Revolut webhook (Phase 4)        │
│  ├── /api/verify-device → license check (Phase 4)    │
│  ├── /api/admin/* → Admin Panel API (Phase 4)        │
│  └── Admin Panel SPA (Phase 4)                        │
│                                                      │
│  Secrets:                                            │
│  ├── GITHUB_REPO (for /dl/latest)                    │
│  ├── SUPABASE_URL + SERVICE_ROLE_KEY (Phase 4)       │
│  ├── REVOLUT_API_KEY + WEBHOOK_SECRET (Phase 4)     │
│  └── ADMIN_SESSION_SECRET (Phase 4)                  │
└─────────────────────────────────────────────────────┘
```

---

## Current Status

| Component | Status | Notes |
|---|---|---|
| `/dl/latest` redirect | ⚠️ WIP | EdgeJS QuickJS runtime 500s; `addEventListener("fetch", ...)` pattern may need investigation. Template's own `process.env` handler also 500s. |
| Supabase schema | ✅ Done | 5 migrations applied to `zosckkklctvrsjqjmyiv` (iFlixify IPTV). |
| GitHub Release | ✅ Done | `v0.1.0-alpha` with APK: https://github.com/tsiartasantreas/iFlixify-IPTV/releases |
| CI/CD | ✅ Done | `ci.yml` green; `release.yml` has YAML trigger issue (triggers on push to main, not tags). |
| Licensing API | 🔲 Phase 4 | Checkout, webhook, verify-device endpoints. |
| Admin Panel | 🔜 Phase 4 | Next.js SPA with user/subscription management. |

---

## Known Issues

1. **`release.yml` triggers on push to main instead of tags only.** The YAML `on: push: tags: - 'v*'` should work but GitHub Actions shows it triggering on `push` to `main`. Investigate YAML encoding or re-create the workflow file.

2. **EdgeJS 500 error.** The Wasmer Edge JS runtime (`edgejs-quickjs`) returns 500 even for the template's own `process.env` handler. This needs investigation into the EdgeJS runtime's supported APIs. The `/dl/latest` redirect is non-blocking — users can install via the direct GitHub URL as a fallback.

3. **Flutter APK build locally blocked.** JVM/Gradle network fault prevents `flutter build apk` locally. CI builds successfully. Use CI artifacts for releases.
