# Flixium — Design Specification

**Status:** Draft for review · **Date:** 2026-08-09 · **Supersedes:** preliminary plan v3 (approved)

> A Netflix-style IPTV player for Android phone / Android TV / Fire TV, sideloaded via the Downloader app. Supports M3U playlists (VOD movies & series, Live TV + EPG, Catch-up TV, Radio, favorites). Four user classes. Free + Pro tiers ($8.99 once-off lifetime, email-keyed, 5 devices). Developer Admin Panel for managing users and subscriptions.

---

## Table of Contents
1. [Goals & Non-Goals](#1-goals--non-goals)
2. [User Classes](#2-user-classes)
3. [Stack](#3-stack)
4. [Architecture](#4-architecture)
5. [Data Model](#5-data-model)
6. [Netflix Design System](#6-netflix-design-system)
7. [Feature Matrix](#7-feature-matrix)
8. [Screen Inventory](#8-screen-inventory)
9. [Licensing & Payment Flow](#9-licensing--payment-flow)
9A. [Content Recommendation Engine](#9a-content-recommendation-engine)
10. [Admin Panel](#10-admin-panel)
11. [Edge Deployment (Wasmer)](#11-edge-deployment-wasmer)
11A. [APK Release Distribution & Downloader Code](#11a-apk-release-distribution--downloader-code)
12. [Dev Environment & Install](#12-dev-environment--install)
13. [Security](#13-security)
14. [Observability](#14-observability)
15. [Risks](#15-risks)
16. [Phased Roadmap](#16-phased-roadmap)
17. [Open Questions / Deferred](#17-open-questions--deferred)

---

## 1. Goals & Non-Goals

### Goals
- **Netflix fidelity.** The app's look, feel, layout, motion, and interaction patterns must be a near pixel-for-pixel replica of the Netflix app — on both phone and TV. The **only** permitted visual deviation is a **slight color palette shift** (background stays near-black; Netflix red `#E50914` → Flixium accent). Per-screen acceptance gate: indistinguishable from Netflix reference when viewed side-by-side, except the accent.
- **Multi-source IPTV.** Import and manage M3U playlists from multiple providers; parse VOD (movies/series), Live TV (with XMLTV EPG), Catch-up TV, and Radio streams.
- **TV-first.** Phone, Android TV, and Fire TV from a single codebase, TV-aware from day 1 (D-pad focus, 10-foot sizing, left-rail nav).
- **Content recommendation engine.** Netflix-style personalized rows: "Because you watched X", "Trending", "Continue Watching" (Pro), and per-genre suggestions. Starts content-based (M3U groups + watch history), evolves toward collaborative as the user base grows. See §9A.
- **APK release distribution via GitHub + Downloader code.** Every release produces a signed APK published to GitHub Releases, resolvable through a short Downloader-app code so you (and your users) can sideload it onto a TV by typing one code. See §11A.
- **Four user classes** with clear entitlement boundaries.
- **Self-serve Pro activation** via Revolut ($8.99 once-off, email-keyed, 5 devices).
- **Admin Panel** for the developer to manage users, subscriptions, devices, feature flags, and view revenue.

### Non-Goals (v1)
- iOS, Apple TV, Roku.
- Server-side transcoding.
- Parental-control PINs (defer).
- Netflix trailer/preview autoplay engine (v1 uses static hero backdrops).
- Local Docker — we use Supabase Cloud only (per decision).

### Legal guardrail
Clone **UX/layout only**. Never use Netflix trademarks (wordmark, "N" logo), copyrighted artwork, or proprietary font (Netflix Sans). The accent color shift is both brand identity and legal differentiation. Final brand name locked before P0 implementation — provisional name "Flixium" is used throughout this spec.

---

## 2. User Classes

| Class | Auth | Entitlement tier | Key capabilities |
|---|---|---|---|
| **Anonymous** | None (device-only) | `anonymous` | 1 playlist, local-only data, no sync, no Continue Watching, no multi-user. App is fully usable within Free limits without signing in. |
| **Registered — Free** | Email (Supabase Auth) | `free` | Everything anonymous + account identity, cloud favorites backup, upgradeable to Pro. |
| **Registered — Pro** | Email + active license | `pro` | Everything Free + multiple playlists, multiple user profiles, Continue Watching / Up Next, cross-device sync (up to 5 devices). |
| **Admin** (you) | Email + `is_admin = true` | `pro` + admin | Everything Pro + full Admin Panel access (users, subscriptions, devices, revenue, feature flags, audit log). |

**Upgrade path:** anonymous → registered-free → registered-pro (via Revolut $8.99 checkout). The `is_admin` flag is set manually in Supabase Studio for your email only — there is no self-serve admin signup.

**Downgrade semantics:** if a Pro license is revoked (via Admin Panel) or fails verification past the grace period (see §9), the user reverts to Free; Pro-only data (extra playlists, profiles, sync rows beyond the Free allowance) is retained locally but becomes read-only / hidden until Pro is restored. Nothing is silently deleted.

---

## 3. Stack

| Layer | Choice | Notes |
|---|---|---|
| App framework | **Flutter** | Single codebase → phone + Android TV + Fire TV. TV-aware from day 1. One sideloaded APK. |
| Player / audio | **`media_kit`** (libmpv backend) | HLS, MPEG-DASH, awkward containers/protocols common in real IPTV. Same pipeline drives Radio (audio-only surface). |
| On-device DB | **Drift** (SQLite) | Reactive streams for UI; stores playlists, parsed catalog, EPG cache, favorites, watch progress, profiles. |
| M3U parsing | **`dart_m3u_filter`** + custom helpers | `#EXTINF`, `#EXTGRP`, catchup attributes (`catchup`, `catchup-source`, etc.). |
| EPG parsing | Custom XMLTV parser | `<channel>` + `<programme>` elements; TTL-cached in Drift. |
| UI kit | Custom Netflix-clone design system (Flutter widgets) + `flutter_animate` for motion | NOT generic Material. See §6. |
| Database / Auth / schema web UI | **Supabase Cloud** (project "Flixium") | Postgres + Auth + Storage + **Supabase Studio** (the in-cloud web UI for schema editing). Single source of truth for app, payments, admin. No local Docker. |
| Edge compute | **Wasmer Edge** (free tier) | ONE app co-hosts the Admin Panel SPA and the Payment/Licensing API. |
| Admin Panel UI | **Next.js** (static export) | React, Netflix-dark themed; follows Wasmer's React Static Site guide. |
| Payments | **Revolut Merchant API** | Order object + signed webhook → once-off $8.99. Hosted checkout (no app-store billing). |
| Distribution | **GitHub Releases + Downloader shortcode** | CI builds signed APKs. |

**Installed locally (verified):** Flutter (`/Applications/Flutter`), Node v26.5.0, Docker 29.6.2, Wasmer CLI 7.2.1, git 2.55.0.
**Needs install:** Supabase CLI (brew install supabase/tap/supabase).

---

## 4. Architecture

### 4.1 Element connection diagram

```
                          ┌──────── SUPABASE CLOUD ────────┐
                          │  project "Flixium"          │
                          │  Postgres · Auth · Storage      │
                          │  Supabase Studio (schema web UI)│
                          │  Row-Level Security policies    │
                          └───────▲────────────▲────────▲──┘
                                  │            │        │
            (HTTPS + JWT + RLS)   │            │        │ (service-role,
                                  │            │        │  server-side only)
  ┌────────────────────┐          │            │        │
  │ 1. FLUTTER APP     │──────────┘            │        │
  │ phone / Android TV │  (anon key, JWT)      │        │
  │ Fire TV sideloaded │ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─┤        │
  │ • Netflix-clone UI │                       │        │
  │ • media_kit player │                       │        │
  │ • Drift local DB   │                       │        │
  │ • entitlement      │                       │        │
  └─────────┬──────────┘                       │        │
            │ checkout / verify                  │        │
            ▼                                   │        │
  ┌─────────────────────────────────────────────┴──┐    │
  │ 4. WASMER EDGE APP  (single app.yaml deploy)    │    │
  │  ┌─────────────────┐  ┌──────────────────────┐ │    │
  │  │ ADMIN PANEL SPA │  │ PAYMENT/LICENSING API│ │    │
  │  │ Next.js static  │  │ • POST /checkout     │ │────┘
  │  │ • users         │  │ • POST /webhook      │ │
  │  │ • subscriptions │  │   (Revolut signed)   │ │
  │  │ • devices       │  │ • POST /verify-device│ │
  │  │ • revenue       │  │ • POST /revoke       │ │
  │  │ • feature flags │  │ • POST /admin/*      │ │
  │  │ • audit log     │  │                      │ │
  │  └─────────────────┘  └──────────────────────┘ │
  │  ┌─────────────────────────────────────────────┐ │
  │  │ /dl/latest  → 302 → latest GitHub Release APK│ │
  │  │ (Downloader-code target, see §11A)           │ │
  │  └─────────────────────────────────────────────┘ │
  │  secrets: SUPABASE_SERVICE_ROLE, REVOLUT_API_KEY,  │
  │  REVOLUT_WEBHOOK_SECRET, ADMIN_SESSION_SECRET       │
  └─────────────────────┬──────────────────────────────┘
                        │
            ┌───────────┴──────────────┐
            │ REVOLUT MERCHANT API      │
            │ • Order ($8.99)           │
            │ • hosted checkout (browser│
            │ • signed webhook → Wasmer │
            └──────────────────────────┘
```

### 4.2 Component responsibilities

1. **Flutter app** — all UI (Netflix clone), playback, local persistence (Drift), M3U/EPG parsing. Reads its entitlement from Supabase (auth user + `profiles.tier` + `licenses` row). Calls Wasmer functions only for checkout initiation and periodic device verification.
2. **Supabase "Flixium"** — single source of truth. Postgres tables, Auth (email), Storage, RLS policies, and Supabase Studio (web UI for schema editing + manual data inspection). Zero local Docker.
3. **Wasmer Edge app** — one deployment that serves (a) the Admin Panel SPA, (b) the payment + licensing API functions, and (c) the `/dl/latest` redirect that resolves to the newest GitHub Release APK (the target of the Downloader code, §11A). Holds the Supabase service-role key, Revolut API key, and webhook secret — server-side only, never shipped to the app.
4. **Revolut Merchant API** — creates the $8.99 Order, hosts the browser checkout, fires the signed webhook to the Wasmer `/webhook` endpoint.

### 4.3 Key data flows

**Activation (anonymous → Pro):**
```
1. App → POST /api/checkout { email, device_fingerprint }
2. Wasmer → Revolut Create Order ($8.99) → returns checkout URL
3. Wasmer → inserts pending activation_codes row { code, email, fp, status }
4. App opens checkout URL in browser → user pays → Revolut
5. Revolut → POST /api/webhook (signed) → Wasmer verifies signature, idempotent
6. Wasmer → upsert license(email, status=active), register device if <5 active
7. App polls POST /api/verify-device → returns entitlement=pro
8. App flips UI to Pro, unlocks features
```

**Admin manages a user:**
```
1. You → Admin Panel login (Supabase Auth, is_admin check)
2. Panel → Wasmer /api/admin/* (service-role) → reads/updates Supabase
3. You click "Revoke license" → Wasmer updates license.status = revoked
4. That user's next app launch → /verify-device returns revoked → downgrades to Free
5. admin_audit_log records the action
```

**Continue Watching (Pro, cross-device):**
```
1. App plays an episode → writes watch_progress to Drift (local)
2. App pushes to Supabase watch_progress_sync (Pro only, RLS-scoped)
3. Other device, same Pro account → pulls watch_progress_sync on sync
4. "Continue Watching" row populated on that device
```

### 4.4 Sync model (Pro)
- **Conflict policy (v1: last-write-wins)** keyed on `(user_id, content_id)` with `updated_at` timestamp. Simple, deterministic, sufficient for single-user-multi-device. Richer merge (e.g. resume-from-furthest position) deferred — see §17.
- **Sync surfaces:** `watch_progress_sync`, `favorites_sync`. Playlist source URLs are per-device (they may contain provider credentials); only the favorites and progress cross-sync.

---

## 5. Data Model

Full DDL lives in versioned migrations under `infra/supabase/migrations/`, edited via Supabase Studio.

### 5.1 On-device (Drift / SQLite)
| Table | Purpose | Pro-only? |
|---|---|---|
| `playlists` | M3U sources (id, name, url, type, last_synced_at) | multi = Pro |
| `channels` | Parsed live channels (id, playlist_id, name, logo, url, group, catchup attrs) | no |
| `vod_items` | Movies + standalone VOD (id, playlist_id, title, poster, url, group) | no |
| `series` | Series groupings (id, playlist_id, title, poster) | no |
| `episodes` | Episodes under a series (id, series_id, season, episode, title, url, thumbnail) | no |
| `radio_stations` | Radio entries (id, playlist_id, name, logo, url) | no |
| `epg_programmes` | XMLTV EPG cache (channel_id, start, stop, title, desc; TTL-indexed) | no |
| `favorites` | Local favorites list (content_id, type, added_at) | no |
| `watch_progress` | Resume positions (content_id, position_ms, duration_ms, updated_at) | Pro to *use* |
| `user_profiles` | Local profiles for multi-user (Pro) | Pro |

### 5.2 Supabase Postgres (RLS-protected)

```sql
-- profiles: 1:1 with auth.users
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  display_name text,
  is_admin boolean not null default false,
  tier text not null default 'anonymous' check (tier in ('anonymous','free','pro')),
  created_at timestamptz not null default now()
);

-- licenses: one active row per email (email is the license key)
create table licenses (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  status text not null check (status in ('pending','active','revoked')),
  source text not null check (source in ('revolut','manual')),
  amount numeric(10,2) default 8.99,
  revolut_order_id text,
  created_at timestamptz not null default now(),
  activated_at timestamptz,
  revoked_at timestamptz,
  revoked_reason text
);

-- devices: up to 5 active per license
create table devices (
  id uuid primary key default gen_random_uuid(),
  license_id uuid not null references licenses(id) on delete cascade,
  email text not null,
  fingerprint text not null,
  name text,
  platform text,
  last_seen timestamptz not null default now(),
  revoked boolean not null default false,
  created_at timestamptz not null default now(),
  unique (license_id, fingerprint)
);

-- activation_codes: short-lived, maps checkout → device
create table activation_codes (
  code uuid primary key default gen_random_uuid(),
  email text not null,
  device_fingerprint text not null,
  status text not null default 'pending' check (status in ('pending','used','expired')),
  revolut_order_id text,
  expires_at timestamptz not null default (now() + interval '1 hour'),
  created_at timestamptz not null default now()
);

-- watch_progress_sync: Pro cross-device resume
create table watch_progress_sync (
  user_id uuid not null references auth.users(id) on delete cascade,
  content_id text not null,
  position_ms bigint not null,
  duration_ms bigint,
  updated_at timestamptz not null default now(),
  primary key (user_id, content_id)
);

-- favorites_sync: Free+Pro cloud favorites backup
create table favorites_sync (
  user_id uuid not null references auth.users(id) on delete cascade,
  content_id text not null,
  playlist_id text,
  added_at timestamptz not null default now(),
  primary key (user_id, content_id)
);

-- feature_flags: admin-controlled toggles
create table feature_flags (
  key text primary key,
  value jsonb not null default '{}',
  audience text not null default 'all' check (audience in ('all','free','pro','admin')),
  updated_at timestamptz not null default now()
);

-- admin_audit_log: every admin action
create table admin_audit_log (
  id bigserial primary key,
  admin_id uuid not null references auth.users(id),
  action text not null,
  target text,
  payload jsonb,
  ts timestamptz not null default now()
);
```

**RLS policies (summary):**
- `profiles`: user reads/updates own row; `is_admin` and `tier` columns are NOT user-writable (enforced by trigger / GRANT).
- `licenses`, `devices`, `activation_codes`: **no client access** — all reads/writes go through Wasmer functions using the service-role key. RLS `USING (false)` on these for anon/authenticated.
- `watch_progress_sync`, `favorites_sync`: user reads/writes own rows (`auth.uid() = user_id`).
- `feature_flags`: world-readable (anon SELECT), admin-writable only.
- `admin_audit_log`: insert via service-role only; admin-readable.

**5-device enforcement:** the `register-device` Wasmer function does `select count(*) from devices where license_id = ? and revoked = false` inside a transaction; rejects if ≥ 5.

---

## 6. Netflix Design System

This is the design north star. Every value here is a target to match; deviations must be justified.

### 6.1 Color tokens
| Token | Value | Matches Netflix? |
|---|---|---|
| `bg.base` | `#141414` | yes (identical) |
| `bg.elevated` | `#181818` | yes |
| `bg.surface` | `#221` (`#222222`) | yes |
| `text.primary` | `#FFFFFF` | yes |
| `text.secondary` | `#B3B3B3` | yes |
| **`accent.primary`** | **`#E11D48`** (rose-red) | **NO — the one allowed deviation** (Netflix uses `#E50914`) |
| `accent.hover` | `#F43F5E` | derived from accent |
| `scrim.gradient` | linear `rgba(0,0,0,0)→rgba(20,20,20,1)` | yes |
| `focus.ring` | `accent.primary` at 40% glow | tinted with accent |

> The accent `#E11D48` is proposed; final value locked at the start of P2 with a side-by-side comparison against 2–3 candidates.

### 6.2 Typography
- **Billboard / hero titles:** bold condensed sans. Netflix uses proprietary "Netflix Sans". **Free equivalent:** `Archivo Narrow` (primary) or `Anton` / `Bebas Neue` (fallback). Final pick in P2.
- **Body / UI:** `Inter` (primary) or `Roboto Flex` (fallback). Weights 400/500/700.
- **Size scale (mobile):** hero title 34/40 bold, row header 18/24 bold, card title 13/18 medium, body 14/20 regular, caption 12/16 regular.
- **Size scale (TV, 10-foot):** multiply mobile scale by ~1.8×; hero title ~60, row header ~28.

### 6.3 Layout primitives

**Mobile:**
- Sticky top bar; transparent over hero, becomes opaque (`bg.base`) on scroll past threshold.
- Bottom tab bar: Home, Series, Movies, Live, Radio, My List. Active tab = accent underline.
- Full-bleed hero billboard (~60% viewport height) with gradient scrim.
- Horizontal scroll rows: category header (bold, left-aligned) + chevron arrows that appear on focus/hover.

**TV (10-foot):**
- Left vertical nav rail: Home, Series, Movies, Live TV, Radio, My List, Search, Settings. Focused item = accent + scale.
- Giant hero billboard (~70% of viewport height).
- D-pad-navigable rows; **focused card scales 1.0 → 1.08 with accent glow + shadow** (the signature Netflix TV interaction).
- Detail modal slides up from the focused card.

**Hero billboard:**
- Full-bleed backdrop image.
- Bottom-up gradient scrim.
- Title area (large condensed), 1–2 line synopsis, **Play** + **My List** + info (i) buttons.
- v1: static backdrop (no autoplay trailer). Crossfade between 3–5 featured titles every ~8s.

**Title cards:**
- VOD: poster aspect 2:3.
- Live / Radio: 16:9 thumbnail.
- Corner radius ~4px.
- Focus/hover: lift (scale 1.08), drop shadow, show title + chevron.

### 6.4 Motion & micro-interactions
| Interaction | Timing |
|---|---|
| Card focus scale | 200ms, ease-out, 1.0 → 1.08 |
| Neighbor card dim (TV) | 150ms, opacity 1.0 → 0.6 |
| Hero crossfade | 800ms, ease-in-out, every 8s |
| Bottom-sheet slide-up | 300ms, ease-out |
| Page transition | 250ms, fade + slight slide |
| Pull-to-refresh | native curve |

Implemented via `flutter_animate` + custom `AnimatedFocus` widgets.

### 6.5 Reference capture (P0 deliverable)
Before building any UI, screenshot the real Netflix app (phone + TV) for every screen in §8 → save annotated images to `docs/ui-references/` → these become the visual acceptance criteria. A screen ships only when it is near-indistinguishable from its reference, except the accent color.

---

## 7. Feature Matrix

| Feature | Anonymous | Free | Pro | Admin |
|---|---|---|---|---|
| Single playlist | ✓ | ✓ | ✓ | ✓ |
| Multiple playlists on device | ✗ | ✗ | ✓ | ✓ |
| Multiple user profiles | ✗ | ✗ | ✓ | ✓ |
| Continue Watching / Up Next | ✗ | ✗ | ✓ | ✓ |
| Cross-device sync (5 devices) | ✗ | ✗ | ✓ | ✓ |
| Cloud favorites backup | ✗ | ✓ | ✓ | ✓ |
| Favorites ("My List") | ✓ | ✓ | ✓ | ✓ |
| VOD — Movies & Series | ✓ | ✓ | ✓ | ✓ |
| Live TV + EPG guide | ✓ | ✓ | ✓ | ✓ |
| Catch-up TV | ✓ | ✓ | ✓ | ✓ |
| Radio | ✓ | ✓ | ✓ | ✓ |
| Upgrade prompts | occasional | occasional | none | none |
| **Admin Panel access** | ✗ | ✗ | ✗ | ✓ |

---

## 8. Screen Inventory

### 8.1 App (Flutter) — all Netflix-mapped
| Screen | Netflix equivalent |
|---|---|
| Onboarding | Netflix-style full-screen first-run (playlist import, language, optional Pro) |
| Home | Netflix Home — hero billboard + rows (Continue Watching [Pro], My Channels, Movies, Series, Live Now, Radio, My List) |
| Browse (Movies/Series/Live/Radio tabs) | Netflix category browsing |
| Detail page | Netflix Title detail — backdrop hero, Play/Resume, synopsis, Episodes tab (series), More Like This, About |
| Player | media_kit surface, Netflix-style controls (scrub preview on VOD, channel zapper on Live, EPG overlay) |
| Live TV guide | EPG grid (no direct Netflix equivalent; styled to match the design system) |
| My Playlists | Manage M3U sources (Free limited to 1) |
| Profile switcher (Pro) | Netflix "Who's watching?" (avatars) |
| Settings | Netflix-style settings list (playback, decoders, subtitles, account/Pro status, device management) |
| Activate Pro | Email entry → browser → Revolut checkout → return → license applied |

### 8.2 Admin Panel (Next.js, Netflix-dark themed)
| Screen | Purpose |
|---|---|
| Login | Supabase Auth (email); rejects non-admin |
| Dashboard | KPIs: total users, anon/free/pro breakdown, revenue, active devices |
| Users | Searchable/filterable list (anon / free / pro); drill into a user |
| User detail | Profile, license, devices, favorites count, recent activity |
| Subscriptions | Grant (manual) / revoke licenses; bulk actions |
| Devices | Per-license device list; revoke a device |
| Feature flags | Toggle keyed flags by audience |
| Audit log | Every admin action, filterable |
| Settings | Panel config (Revolut keys status, webhook URL, etc.) |

---

## 9. Licensing & Payment Flow

### 9.1 Sequence (anonymous → Pro)
See §4.3 "Activation" flow.

### 9.2 Endpoints (Wasmer Edge)
| Method + path | Auth | Purpose |
|---|---|---|
| `POST /api/checkout` | none | `{email, device_fingerprint}` → creates activation_code + Revolut Order → returns `{checkout_url, code}` |
| `POST /api/webhook` | Revolut signature | Revolut fires on payment success → verify sig → idempotent upsert license + register device |
| `POST /api/verify-device` | JWT (app) | `{device_fingerprint}` → returns `{tier, license_status, active_device_count}` for entitlement |
| `POST /api/revoke` | admin | Revoke a device (admin-initiated) |
| `GET/POST /api/admin/*` | admin | All Admin Panel data operations (users, subscriptions, flags, audit) |

### 9.3 Device fingerprinting
- Composed of: Android `ANDROID_ID` + app install UUID + device model. Hashed (SHA-256).
- Stable across app updates within the same install; changes on factory reset or reinstall → counts as a new device slot.

### 9.4 5-device cap
- Enforced server-side in the `register-device` function inside a transaction.
- On hitting the cap, the app shows a "Manage devices" screen (Pro) listing the 5 with `last_seen`; user must revoke one before activating a new device.

### 9.5 Grace period & offline
- License + device verification result is cached locally (Drift) with a **7-day grace period**.
- Background refresh on app start; hard-downgrade only after grace expiry + failed re-verify.
- Lets users watch offline / through transient Wasmer cold starts without being locked out.

### 9.6 Idempotency
- Webhook handler uses `revolut_order_id` as the idempotency key; duplicate deliveries do not double-mint licenses or double-register devices.

---

## 9A. Content Recommendation Engine

A first-class goal: Netflix-style personalized rows on Home. The engine evolves in two stages — v1 ships content-based, v2 grows into collaborative once there is enough usage data.

### 9A.1 What the user sees (Home rows)
- **Continue Watching** (Pro) — resume positions, sorted by `updated_at` desc.
- **Because you watched X** — for each recently-watched title, top-N similar titles by genre/group overlap.
- **Trending Now** — globally most-played in last 7 days (content-based popularity).
- **Top 10 in your country today** (v2) — ranked list with the Netflix big-number styling.
- **New on your playlists** — recently added VOD across the user's playlists.
- **Per-genre rows** — one row per M3U group / detected genre, ranked by affinity.
- **Recommended for you** (v2) — collaborative-filtering blend.

### 9A.2 Inputs (signals)
| Signal | Source | Used by |
|---|---|---|
| Play events (content_id, position, completed) | Drift (anon) + `watch_events` table (registered) | all recommenders |
| Favorites / My List additions | Drift + `favorites_sync` | affinity weights |
| Search queries | Drift | interest profile |
| Content metadata (genres, groups, year, title similarity) | parsed from M3U + EPG | content-based similarity |
| Skip / bail events (played < 30s) | Drift | negative signal |

### 9A.3 v1 — content-based (ships in P3)
- **Where it runs:** on-device (Drift) for anonymous + free; hybrid on-device + Supabase materialized views for Pro cross-device.
- **Algorithm:** TF-IDF over content metadata (genre groups, title tokens) → cosine similarity between a user's affinity vector and each catalog item. Lightweight, runs on-device in <50ms for catalogs up to ~50k items.
- **Affinity model:** per-user vector weighted by recency-decayed play/favorite events.
- **Storage:** `content_embeddings` (precomputed item vectors, refreshed on playlist sync) + `user_affinity` (computed lazily, cached in Drift).
- **Cold start:** anonymous users get "Trending" + "New" + per-genre rows until enough play signals exist (~5 plays), then personalized rows activate.

### 9A.4 v2 — collaborative (deferred to a later phase, see §17)
- Triggered when monthly active users exceed a threshold (provisional: 500 MAU).
- Runs offline/batched (nightly job in a Wasmer function or Supabase Edge Function).
- Item-item collaborative filtering (matrix factorization) stored as `item_similarity` table.
- Blended with v1 content-based via a weighted rank fusion.
- "Top 10 today" becomes possible once aggregate play volume exists.

### 9A.5 Tables (added to §5)
```sql
-- anonymized/registered play + interaction events feeding the engine
create table watch_events (
  id bigserial primary key,
  user_id uuid references auth.users(id) on delete set null, -- null for anonymous
  anonymous_id text,        -- device-scoped id when not signed in
  content_id text not null,
  content_group text,
  event text not null check (event in ('play','progress','completed','skipped','favorited')),
  position_ms bigint,
  duration_ms bigint,
  ts timestamptz not null default now()
);

-- precomputed content vectors (refreshed on playlist sync)
create table content_embeddings (
  content_id text primary key,
  playlist_id text,
  group text,
  embedding float4[],         -- TF-IDF vector
  updated_at timestamptz not null default now()
);

-- (v2) precomputed item-item similarity
create table item_similarity (
  content_id_a text,
  content_id_b text,
  score float4,
  primary key (content_id_a, content_id_b)
);
```
RLS: `watch_events` user-insertable for own rows (or anonymous_id-scoped); `content_embeddings` / `item_similarity` world-readable (computed globally). A Supabase materialized view `recommendations_for(user_id)` exposes the per-user blend to the app.

### 9A.6 Privacy & freemium tie-in
- Anonymous users: recommendations computed locally only; events stay on-device.
- Free users: local + cloud favorites backup; recommendations still local.
- Pro users: recommendations sync across devices (the per-user blend reads cloud events).

---

## 10. Admin Panel

- **Tech:** Next.js (App Router) static export, deployed as the static surface of the Wasmer app.
- **Auth:** Supabase Auth (email/password or magic link). Every request re-checks `profiles.is_admin = true`; non-admins see 403.
- **Data access:** client uses Supabase anon key + JWT for read-only user-scoped queries; all privileged writes go through Wasmer `/api/admin/*` (service-role, server-side).
- **Theme:** Netflix-dark (same tokens as §6.1) so it feels like part of the product.
- **Audit:** every mutating admin action writes to `admin_audit_log` (admin_id, action, target, payload, ts).
- **Feature flags:** the Flags screen lets you toggle keys consumed by the app at runtime (e.g. disable a content type, force an upgrade prompt, enable a beta) — values read by the app on launch.

---

## 11. Edge Deployment (Wasmer)

### 11.1 `app.yaml` (prepared, autodeploy-ready)
File: `/edge/app.yaml`. Schema confirmed from official Wasmer Edge docs.

```yaml
kind: wasmer.io/App.v0
owner: <YOUR_WASMER_USERNAME>   # set during install (§12)
name: flixium-edge
package: '.'                    # uses wasmer.toml in same dir
debug: false
# Secrets set via CLI (never committed):
#   wasmer app secret set SUPABASE_URL=... --app flixium-edge
#   wasmer app secret set SUPABASE_SERVICE_ROLE_KEY=... --app flixium-edge
#   wasmer app secret set REVOLUT_API_KEY=... --app flixium-edge
#   wasmer app secret set REVOLUT_WEBHOOK_SECRET=... --app flixium-edge
#   wasmer app secret set ADMIN_SESSION_SECRET=... --app flixium-edge
env:
  SUPABASE_URL: "${SUPABASE_URL}"
  SUPABASE_SERVICE_ROLE_KEY: "${SUPABASE_SERVICE_ROLE_KEY}"
  REVOLUT_API_KEY: "${REVOLUT_API_KEY}"
  REVOLUT_WEBHOOK_SECRET: "${REVOLUT_WEBHOOK_SECRET}"
  ADMIN_SESSION_SECRET: "${ADMIN_SESSION_SECRET}"
capabilities:
  instaboot:                    # fast cold starts on checkout/verify
    requests:
      - path: /api/checkout
      - path: /api/verify-device
      - path: /_bootstrap
  cdn_cache:
    enabled: true               # cache admin static assets at edge
```

### 11.2 `wasmer.toml` (companion, in `/edge`)
Declares the package; the React static-site bundler builds the Admin SPA; API functions run as edge handlers.

### 11.3 Autodeploy
Git push to the configured branch triggers autodeploy via Wasmer for GitHub. Secrets are injected from the Wasmer secrets store (not from the repo).

### 11.4 Known issue
[wasmer#6803](https://github.com/wasmerio/wasmer/issues/6803): `wasmer deploy` can occasionally corrupt `app.yaml` when rewriting jobs. Mitigation: keep `app.yaml` in git; if it gets mangled, revert and re-push.

---

## 11A. APK Release Distribution & Downloader Code

A first-class goal: every release ships a signed APK to GitHub Releases, resolvable through a short Downloader-app code so you can sideload it onto a TV screen by typing one code.

### 11A.1 Release artifact
- **What:** signed universal APK (`flixium-universal.apk`) + a leaner arm64-v8a build (`flixium-arm64.apk`) for Fire TV sticks / modern Android TV.
- **Where:** GitHub Releases on the repo, tagged `v<semver>` (e.g. `v0.1.0`, `v0.2.0-beta`).
- **Generated by:** GitHub Actions on tag push (workflow `.github/workflows/release.yml`): `flutter build apk --split-per-abi` → sign with release keystore (keystore stored as GH Actions secret, base64) → create Release → upload both APKs.

### 11A.2 The "stable download URL"
GitHub Releases has no built-in `/latest/asset/<name>` stable URL. We solve this with a **redirect function on the Wasmer edge app** that always points to the latest APK:

```
GET https://<edge-app>.wasmer.app/dl/latest          → 302 → latest universal APK
GET https://<edge-app>.wasmer.app/dl/latest/arm64    → 302 → latest arm64 APK
GET https://<edge-app>.wasmer.app/dl/stable          → 302 → latest non-beta APK
GET https://<edge-app>.wasmer.app/dl/v/0.1.0         → 302 → specific version
```

Implementation: an edge handler that queries the GitHub API (`/repos/<owner>/<repo>/releases/latest`) and 302-redirects to the matching `browser_download_url`. Cached briefly at the edge so a cold GitHub API doesn't slow the install. Added to the same Wasmer app as the Admin Panel + Payment API (no second deployment).

### 11A.3 The Downloader-app code
The Downloader app (by AFTVnews) lets Fire TV / Android TV users sideload by entering a short code or typing a URL. There are two supported paths:

- **Path A — Browser URL typing:** open Downloader → type the full URL `https://<edge-app>.wasmer.app/dl/latest` → it downloads and installs the APK. Works immediately, no code needed. Good for testing.
- **Path B — Short code** (what you asked for): the Downloader directory lets you claim a short alphanumeric code that maps to a URL. The code is **claimed through the Downloader app's own directory** (the shortener is operated by AFTVnews, not us — I can't mint one from here). Steps to get `iptv` (or your chosen code):
  1. Open the Downloader app on your TV → **Settings** → enable **Install unknown apps** for Downloader.
  2. Go to the Downloader website shortener: open Downloader on the TV, go to the **Browser**, navigate to `go.aftvnews.com` (the code-claim page) OR visit the directory on a computer.
  3. Search/claim your code (e.g. `iptv` if free) → set its target URL to `https://<edge-app>.wasmer.app/dl/latest`.
  4. From then on: anyone types that code in Downloader → lands on the latest APK → install.

> ⚠️ I cannot generate a real working Downloader code from here — those codes live in AFTVnews's directory, not in this codebase. What I build is the **stable redirect URL** (`/dl/latest`) that the code points to, and the exact claim steps to lock a code to that URL. This is the honest, working approach.

### 11A.4 Test loop (for you)
Once P0 + the release workflow exist:
1. Push a git tag `v0.1.0` → CI builds + signs + uploads APKs to GitHub Releases.
2. On your TV, open Downloader → type `https://<edge-app>.wasmer.app/dl/latest` → APK downloads → install.
3. (Optional, one-time) Claim your short code via the Downloader directory → point it at `/dl/latest` → thereafter type just the code.

### 11A.5 Pre-release vs release
- Tags like `v0.x.0-beta` → `dl/latest` (includes betas); `dl/stable` → latest non-beta.
- The `/dl/...` handlers read the GH Releases API and pick by tag pattern. No database needed.

---

## 12. Dev Environment & Install

### 12.1 Tooling status (verified on this machine)
| Tool | Status |
|---|---|
| Flutter | ✅ installed (`/Applications/Flutter`) |
| Node | ✅ v26.5.0 |
| Docker | ✅ 29.6.2 (not used for backend; only if you ever want local Postgres) |
| Wasmer CLI | ✅ 7.2.1 |
| git | ✅ 2.55.0 |
| Supabase CLI | ❌ **needs install** — `brew install supabase/tap/supabase` |

### 12.2 One-time manual steps (what YOU do)
These cannot be automated for you:

1. **Supabase** — supabase.com → New Project → name it **"Flixium"** → set a strong DB password → pick region → Create. Note down: **Project URL**, **anon key**, **service_role key** (Project Settings → API), and the **project ref** (in the URL).
2. **Wasmer** — you already have an account + CLI (v7.2.1). Note your **username** (goes in `app.yaml` `owner:`).
3. **Revolut Business** — ensure Merchant API is enabled on your Business account; generate an API key + note the webhook signing secret. (Eligibility validated in P0; Stripe is the documented fallback if Revolut blocks your region/account.)
4. **GitHub** — create the repo `Flixium` (or your preferred name).

### 12.3 Commands I run (after plan + spec approval)
```bash
# Supabase — link the project you created and apply schema
supabase login
supabase link --project-ref <PROJECT_REF>
supabase db push                 # applies migrations in infra/supabase/migrations
supabase db execute < seed.sql   # your admin profile + a test Pro license

# Wasmer — set secrets (values from §12.2)
wasmer login
wasmer app secret set SUPABASE_URL=...              --app flixium-edge
wasmer app secret set SUPABASE_SERVICE_ROLE_KEY=...  --app flixium-edge
wasmer app secret set REVOLUT_API_KEY=...            --app flixium-edge
wasmer app secret set REVOLUT_WEBHOOK_SECRET=...     --app flixium-edge
wasmer app secret set ADMIN_SESSION_SECRET=...       --app flixium-edge

# Deploy the edge app (admin panel + payment API together)
cd edge && wasmer deploy
```

Then set `profiles.is_admin = true` for your email in Supabase Studio (Table Editor → profiles) → you can now log into the Admin Panel.

### 12.4 Local dev loop
- **Flutter:** `flutter run -d <device>`; for TV, run on a real Android TV / Fire TV stick with USB debugging from P2 (emulators are unreliable for D-pad focus).
- **Admin panel:** `npm run dev` in `/admin` against a local env file mirroring the Wasmer secrets (`.env.local` gitignored).
- **Edge functions:** local runner via Wasmer CLI or a Node dev harness pointing at Supabase Cloud.

Full step-by-step with screenshots → `docs/INSTALL.md` (produced during P0).

---

## 13. Security

- **App** holds only the Supabase **anon key** + the signed-in user's JWT. RLS enforces users see only their own rows. The app **never** sees the service-role key.
- **Wasmer functions** hold the service-role key + Revolut API key + webhook secret — server-side only.
- **Admin Panel** authenticates via Supabase Auth; every admin API call re-checks `is_admin` on the JWT. No client-side service-role usage.
- **Webhook** signature verified per Revolut spec; idempotency key (`revolut_order_id`) prevents double-mint.
- **Activation endpoint** rate-limited per email + per fingerprint to curb abuse.
- **Secrets** never committed — stored in the Wasmer secrets store, referenced via `${...}` in `app.yaml`.
- **RLS** is the hard boundary; the service-role key is only ever used inside Wasmer functions, never reachable from the app.

---

## 14. Observability

- **Crash reporting:** Sentry free tier in the Flutter app (DSN in env).
- **Basic analytics:** anonymous events (app launch, screen view, playback start/error, upgrade-prompt shown) — wired in P5, off by default, togglable via a feature flag.
- **Edge logs:** Wasmer app logs (checkout, webhook, verify-device, admin actions) → reviewed via Wasmer dashboard + `admin_audit_log` table.
- **Health check:** `GET /api/health` on the edge app returns `{status, supabase_ok, revolut_ok}`.

---

## 15. Risks

| Risk | Mitigation |
|---|---|
| Netflix fidelity not reached | Reference capture in P0; per-screen side-by-side acceptance gate in P2 |
| TV D-pad focus bugs in Flutter | Build the focus/nav kit early in P2; test on a real Fire TV stick from week 5 |
| Wasmer Edge cold starts on license check | `instaboot` on `/checkout` + `/verify-device`; license cached locally with 7-day grace; hard-downgrade only after grace expiry |
| Revolut Merchant API access/region limits | Validate eligibility in P0; Stripe documented as fallback in this spec |
| `app.yaml` corruption (wasmer#6803) | Keep `app.yaml` in git; revert + re-push if mangled |
| Service-role key leak | Server-side only (Wasmer); never in Flutter; RLS on all client queries |
| 5-device cap abuse | Fingerprinting + revocation UI; rate-limit activation endpoint |
| Legal (Netflix trademark/copyright) | Clone UX/layout only; no Netflix marks/art; accent color differentiation; final review before release |

---

## 16. Phased Roadmap

| Phase | Weeks | Deliverables |
|---|---|---|
| **P0 Foundations** | 1 | Create Supabase project "Flixium"; repo scaffold (`/app`, `/admin`, `/edge`, `/infra/supabase`); migrations (profiles, licenses, devices, activation_codes + RLS); set your `is_admin`; `app.yaml` + `wasmer.toml`; GitHub Actions lint+build; Netflix reference capture → `docs/ui-references/`; `INSTALL.md` |
| **P1 Player core** | 2–3 | M3U parser (VOD+Live+Radio+catchup); media_kit surface (phone+TV); single playlist import → flat list → play; Drift schema v1; anon entitlement stub |
| **P2 Netflix-clone UI** | 4–7 (largest) | Design system (tokens/type/cards/rows/billboard/focus/motion); TV left-rail nav + mobile bottom-tab nav; Home, Browse, Detail, Favorites, Settings, EPG grid, Radio; per-screen acceptance gate |
| **P3 Accounts + Pro + Recommendations v1** | 8–9 | Supabase Auth (free), anonymous still supported; multi-profile, multi-playlist, Continue/Up Next, cross-device sync; 4-class gating wired into UI; **content-based recommendation engine** (Trending, Because-you-watched, per-genre, New) with Home rows |
| **P4 Edge: Admin + Payments** | 10–11 | Next.js Admin Panel (all screens); Wasmer API functions (checkout, webhook, verify-device, revoke, admin/*); Revolut integration + sandbox; in-app Activate Pro |
| **P5 Distribution & Release pipeline** | 12 | Signed release APKs (arm64-v8a + universal); GitHub Releases automation (tag → APK); **Wasmer `/dl/latest` redirect handler**; Downloader-code claim steps in `INSTALL.md`; Sentry; onboarding; icon/splash; README landing |
| **P6 Recommendations v2 (deferred)** | post-1.0 | Collaborative filtering (item-item matrix factorization) nightly job; blended rank fusion; "Top 10 today" row — triggered when MAU ≥ ~500 (see §9A.4, §17) |

---

## 17. Open Questions / Deferred to Later Phases

- **Exact accent value** (`#E11D48` proposed) — locked at start of P2 after side-by-side comparison of 2–3 candidates.
- **Final brand name** ("Flixium" provisional) — locked before P0 implementation.
- **Typeface picks** (Archivo Narrow vs Anton vs Bebas for billboards; Inter vs Roboto Flex for body) — locked in P2.
- **Per-screen wireframes/mockups** — the visual companion will be offered when we reach screen-level design (during the writing-plans step for P2).
- **EPG grid interaction detail** (time-scroll granularity, now-line, catch-up entry point) — specified in the P2 implementation plan.
- **Sync conflict policy beyond last-write-wins** (e.g. resume-from-furthest) — deferred; revisit if users hit conflicts.
- **Admin Panel mockups** — produced during P4 planning.
- **Stripe fallback integration** — only built if Revolut eligibility fails in P0.
- **Recommendation engine v2 (collaborative filtering)** — content-based (v1) ships in P3; collaborative (v2) deferred to P6, gated on MAU ≥ ~500. See §9A.4.
- **"Top 10 today" row** — depends on v2 aggregate play volume; deferred to P6.
- **Downloader short code** — I build the stable `/dl/latest` redirect (§11A); claiming the actual short alphanumeric code is done once via the Downloader app directory (AFTVnews-operated). Steps in `INSTALL.md`.
