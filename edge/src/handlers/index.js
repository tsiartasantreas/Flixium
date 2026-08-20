// Route handler — dispatches requests to the right endpoint.
//
// GET  /                   → landing page
// GET  /dl/latest          → download redirect (existing)
// GET  /dl/latest/arm64    → download redirect (existing)
// GET  /dl/latest/stable   → download redirect (existing)
// GET  /reset-password      → password-reset page (Supabase Auth)
// POST /api/checkout       → checkout handler
// POST /api/webhook        → webhook handler
// POST /api/verify-device  → verify device handler

import dlLatest from "./dl_latest.js";
import checkout from "./checkout.js";
import webhook from "./webhook.js";
import verifyDevice from "./verify_device.js";
import resetPassword from "./reset_password.js";
import admin from "./admin.js";

function methodNotAllowed() {
  return new Response(JSON.stringify({ error: "Method not allowed" }), {
    status: 405,
    headers: { "Content-Type": "application/json" },
  });
}

function landingPage() {
  const html = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>iFlixify IPTV</title>
<style>
  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    background: #141414;
    color: #fff;
    min-height: 100vh;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 2rem;
  }
  .hero { text-align: center; max-width: 600px; }
  h1 { font-size: 2.8rem; margin-bottom: 0.5rem; }
  .accent { color: #E50914; }
  p.tagline { color: #999; margin-bottom: 2.5rem; font-size: 1.15rem; }
  .btn-group { display: flex; gap: 1rem; justify-content: center; flex-wrap: wrap; margin-bottom: 2rem; }
  a.btn {
    display: inline-block;
    background: #E50914;
    color: #fff;
    text-decoration: none;
    padding: 0.9rem 2.4rem;
    border-radius: 4px;
    font-weight: 600;
    font-size: 1.1rem;
    transition: background 0.2s;
  }
  a.btn:hover { background: #b20710; }
  a.btn.secondary {
    background: transparent;
    border: 2px solid #E50914;
    color: #E50914;
  }
  a.btn.secondary:hover { background: #E50914; color: #fff; }
  .links { margin-top: 1.5rem; border-top: 1px solid #2a2a2a; padding-top: 1.5rem; }
  .links a { color: #999; text-decoration: none; margin: 0 0.75rem; font-size: 0.9rem; }
  .links a:hover { color: #fff; text-decoration: underline; }
</style>
</head>
<body>
  <div class="hero">
    <h1>i<span class="accent">Flixify</span> IPTV</h1>
    <p class="tagline">Stream smarter. Download the latest release for Android.</p>
    <div class="btn-group">
      <a class="btn" href="/dl/latest">Download for Android</a>
      <a class="btn secondary" href="/dl/latest/arm64">Download ARM64</a>
    </div>
    <div class="links">
      <a href="https://iflixify.wasmer.app">Website</a>
      <a href="https://iflixify.wasmer.app/support">Support</a>
      <a href="https://iflixify.wasmer.app/terms">Terms</a>
      <a href="https://iflixify.wasmer.app/privacy">Privacy</a>
    </div>
  </div>
</body>
</html>`;

  return new Response(html, {
    status: 200,
    headers: { "Content-Type": "text/html; charset=utf-8" },
  });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const { pathname } = url;
    const method = request.method;

    // Landing page (GET only)
    if (pathname === "/") {
      if (method !== "GET") return methodNotAllowed();
      return landingPage();
    }

    // Download redirects (GET)
    if (pathname.startsWith("/dl/latest")) {
      return dlLatest.fetch(request, env);
    }

    // API routes — POST only, 405 otherwise
    if (pathname === "/api/checkout") {
      if (method !== "POST") return methodNotAllowed();
      return checkout.fetch(request, env);
    }

    if (pathname === "/api/webhook") {
      if (method !== "POST") return methodNotAllowed();
      return webhook.fetch(request, env);
    }

    if (pathname === "/api/verify-device") {
      if (method !== "POST") return methodNotAllowed();
      return verifyDevice.fetch(request, env);
    }

    // Password-reset page (GET only)
    if (pathname === "/reset-password") {
      return resetPassword.fetch(request, env);
    }

    // Admin panel and admin API routes
    if (pathname === "/admin" || pathname.startsWith("/api/admin/")) {
      const adminRes = await admin.fetch(request, env);
      if (adminRes) return adminRes;
    }

    // Health check
    if (pathname === "/api/health") {
      return new Response(JSON.stringify({ status: "ok" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    // 404 fallback
    return new Response(JSON.stringify({ error: "Not found" }), {
      status: 404,
      headers: { "Content-Type": "application/json" },
    });
  },
};
