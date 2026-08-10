# iFlixify IPTV

A Netflix-style IPTV player for Android phone, Android TV, and Fire TV. Supports M3U playlists (VOD movies & series, Live TV + EPG, Catch-up TV, Radio, favorites). Four user classes (anonymous / free / pro / admin). Self-serve Pro activation ($8.99 once-off lifetime, 5 devices). Developer Admin Panel.

> 🎯 The look and feel mirrors the Netflix app. The only visual deviation is a slight accent color shift. Clone UX/layout only — no Netflix trademarks or copyrighted art.

## Status
Phase 0 — Foundations (in progress). See `docs/superpowers/plans/2026-08-09-phase0-foundations.md`.

## Structure
| Path | Purpose |
|---|---|
| `app/` | Flutter app (phone + Android TV + Fire TV) |
| `admin/` | Next.js Admin Panel (scaffolded; built in Phase 4) |
| `edge/` | Wasmer Edge app — licensing/payment API + `/dl/latest` APK redirect |
| `infra/supabase/` | Versioned Postgres migrations + seed |

## Docs
- Design spec: `docs/superpowers/specs/2026-08-09-iflixify-design.md`
- Phase 0 plan: `docs/superpowers/plans/2026-08-09-phase0-foundations.md`
- Install guide: `docs/INSTALL.md`
- Architecture diagram: `docs/architecture/element-connection-diagram.svg`

## Install (for sideload testers)
See `docs/INSTALL.md`. In short: push a `vX.Y.Z` tag → CI builds a signed APK → sideload via the Downloader app using `https://<edge-app>.wasmer.app/dl/latest`.
