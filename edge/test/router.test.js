import { test } from "node:test";
import assert from "node:assert";
import handler from "../src/handlers/index.js";

const ENV = {
  GITHUB_REPO: "octocat/empty",
  SUPABASE_URL: "https://test.supabase.co",
  SUPABASE_SERVICE_ROLE_KEY: "test-key",
};

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
