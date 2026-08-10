import { test } from "node:test";
import assert from "node:assert";
import handler from "../src/handlers/checkout.js";

const ENV = {
  SUPABASE_URL: "https://test.supabase.co",
  SUPABASE_SERVICE_ROLE_KEY: "test-key",
};

function post(body) {
  return new Request(new URL("/api/checkout", "http://edge.test"), {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
}

// Track calls to the mock fetch
let fetchCalls = [];

function mockFetch(url, opts) {
  fetchCalls.push({ url, opts });
  // Simulate successful Supabase insert
  return Promise.resolve(
    new Response(JSON.stringify([{ id: 1 }]), {
      status: 201,
      headers: { "Content-Type": "application/json" },
    }),
  );
}

test("checkout: returns 405 for non-POST", async () => {
  const req = new Request(new URL("/api/checkout", "http://edge.test"), { method: "GET" });
  const res = await handler.fetch(req, ENV);
  assert.equal(res.status, 405);
});

test("checkout: returns 400 for missing fields", async () => {
  const res = await handler.fetch(post({}), ENV);
  assert.equal(res.status, 400);
  const body = await res.json();
  assert.ok(body.error.includes("required"));
});

test("checkout: returns 400 for missing device_fingerprint", async () => {
  const res = await handler.fetch(post({ email: "a@b.com" }), ENV);
  assert.equal(res.status, 400);
});

test("checkout: returns 400 for invalid JSON", async () => {
  const req = new Request(new URL("/api/checkout", "http://edge.test"), {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: "not json",
  });
  const res = await handler.fetch(req, ENV);
  assert.equal(res.status, 400);
});

test("checkout: returns checkout_url and activation_code", async () => {
  const origFetch = globalThis.fetch;
  fetchCalls = [];
  globalThis.fetch = mockFetch;

  try {
    const res = await handler.fetch(
      post({ email: "user@test.com", device_fingerprint: "fp-123" }),
      ENV,
    );
    assert.equal(res.status, 200);
    const body = await res.json();
    assert.ok(body.checkout_url, "should have checkout_url");
    assert.ok(body.activation_code, "should have activation_code");
    assert.ok(body.checkout_url.includes("revolut.com"), "checkout_url should be Revolut");
    assert.equal(body.activation_code.length, 12, "code should be 12 chars");
    // Verify Supabase was called
    assert.ok(fetchCalls.length > 0, "fetch should have been called");
    assert.ok(fetchCalls[0].url.includes("/rest/v1/activation_codes"), "should POST to activation_codes");
  } finally {
    globalThis.fetch = origFetch;
  }
});

test("checkout: activation code uses only valid characters", async () => {
  const origFetch = globalThis.fetch;
  fetchCalls = [];
  globalThis.fetch = mockFetch;

  try {
    const res = await handler.fetch(
      post({ email: "user@test.com", device_fingerprint: "fp-123" }),
      ENV,
    );
    const body = await res.json();
    assert.ok(/^[A-Z0-9]{12}$/.test(body.activation_code), `code "${body.activation_code}" should be uppercase alphanumeric`);
  } finally {
    globalThis.fetch = origFetch;
  }
});
