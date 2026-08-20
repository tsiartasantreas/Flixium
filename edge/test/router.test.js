import { test } from "node:test";
import assert from "node:assert";
import handler from "../src/handlers/index.js";

const ENV = {
  GITHUB_REPO: "octocat/empty",
  SUPABASE_URL: "https://test.supabase.co",
  SUPABASE_SERVICE_ROLE_KEY: "test-key",
  SUPABASE_ANON_KEY: "test-anon-key",
};

test("router: GET / returns landing page HTML", async () => {
  const req = new Request(new URL("/", "http://edge.test"));
  const res = await handler.fetch(req, ENV);
  assert.equal(res.status, 200);
  const ct = res.headers.get("content-type");
  assert.ok(ct.includes("text/html"), "should return HTML");
  const body = await res.text();
  assert.ok(body.includes("iFlixify IPTV"), "should contain branding");
  assert.ok(body.includes("Download for Android"), "should contain Android download button");
  assert.ok(body.includes("Download ARM64"), "should contain ARM64 download button");
  assert.ok(body.includes("/dl/latest"), "should link to download endpoint");
  assert.ok(body.includes("/dl/latest/arm64"), "should link to ARM64 endpoint");
  assert.ok(body.includes("Website"), "should have Website link");
  assert.ok(body.includes("Support"), "should have Support link");
  assert.ok(body.includes("Terms"), "should have Terms link");
  assert.ok(body.includes("Privacy"), "should have Privacy link");
});

test("router: POST / returns 405", async () => {
  const req = new Request(new URL("/", "http://edge.test"), { method: "POST" });
  const res = await handler.fetch(req, ENV);
  assert.equal(res.status, 405);
});

test("router: 404 for unknown path", async () => {
  const req = new Request(new URL("/nope", "http://edge.test"));
  const res = await handler.fetch(req, ENV);
  assert.equal(res.status, 404);
});

test("router: /api/health returns ok", async () => {
  const req = new Request(new URL("/api/health", "http://edge.test"));
  const res = await handler.fetch(req, ENV);
  assert.equal(res.status, 200);
  const body = await res.json();
  assert.equal(body.status, "ok");
});

test("router: GET /api/checkout returns 405", async () => {
  const req = new Request(new URL("/api/checkout", "http://edge.test"), { method: "GET" });
  const res = await handler.fetch(req, ENV);
  assert.equal(res.status, 405);
});

test("router: GET /api/webhook returns 405", async () => {
  const req = new Request(new URL("/api/webhook", "http://edge.test"), { method: "GET" });
  const res = await handler.fetch(req, ENV);
  assert.equal(res.status, 405);
});

test("router: GET /api/verify-device returns 405", async () => {
  const req = new Request(new URL("/api/verify-device", "http://edge.test"), { method: "GET" });
  const res = await handler.fetch(req, ENV);
  assert.equal(res.status, 405);
});

test("router: POST /api/checkout without body returns 400", async () => {
  const req = new Request(new URL("/api/checkout", "http://edge.test"), {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: "{}",
  });
  const res = await handler.fetch(req, ENV);
  assert.equal(res.status, 400);
});

test("router: POST /api/verify-device without body returns 400", async () => {
  const req = new Request(new URL("/api/verify-device", "http://edge.test"), {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: "{}",
  });
  const res = await handler.fetch(req, ENV);
  assert.equal(res.status, 400);
});

test("router: GET /reset-password returns HTML", async () => {
  const req = new Request(new URL("/reset-password", "http://edge.test"));
  const res = await handler.fetch(req, ENV);
  assert.equal(res.status, 200);
  const ct = res.headers.get("content-type");
  assert.ok(ct.includes("text/html"), "should return HTML");
  const body = await res.text();
  assert.ok(body.includes("iFlixify IPTV"), "should contain branding");
  assert.ok(body.includes("Reset Password"), "should contain form heading");
});

test("router: POST /reset-password returns 405", async () => {
  const req = new Request(new URL("/reset-password", "http://edge.test"), {
    method: "POST",
  });
  const res = await handler.fetch(req, ENV);
  assert.equal(res.status, 405);
});

test("router: GET /admin returns HTML", async () => {
  const req = new Request(new URL("/admin", "http://edge.test"));
  const res = await handler.fetch(req, ENV);
  assert.equal(res.status, 200);
  const ct = res.headers.get("content-type");
  assert.ok(ct.includes("text/html"), "should return HTML");
  const body = await res.text();
  assert.ok(body.includes("Admin"), "should contain admin branding");
  assert.ok(body.includes("Sign In"), "should contain login form");
});

test("router: GET /api/admin/users without auth returns 401", async () => {
  const req = new Request(new URL("/api/admin/users", "http://edge.test"));
  const res = await handler.fetch(req, ENV);
  assert.equal(res.status, 401);
  const body = await res.json();
  assert.ok(body.error.includes("Missing Authorization"), "should require auth");
});

test("router: PATCH /api/admin/users/test-id/tier without auth returns 401", async () => {
  const req = new Request(new URL("/api/admin/users/test-id/tier", "http://edge.test"), {
    method: "PATCH",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ tier: "pro" }),
  });
  const res = await handler.fetch(req, ENV);
  assert.equal(res.status, 401);
});

test("router: DELETE /api/admin/users/test-id without auth returns 401", async () => {
  const req = new Request(new URL("/api/admin/users/test-id", "http://edge.test"), {
    method: "DELETE",
  });
  const res = await handler.fetch(req, ENV);
  assert.equal(res.status, 401);
});
