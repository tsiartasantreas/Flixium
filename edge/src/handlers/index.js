// Route handler — dispatches requests to the right endpoint.
//
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

function methodNotAllowed() {
  return new Response(JSON.stringify({ error: "Method not allowed" }), {
    status: 405,
    headers: { "Content-Type": "application/json" },
  });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const { pathname } = url;
    const method = request.method;

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
