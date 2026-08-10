import { test } from "node:test";
import assert from "node:assert";
import handler from "../src/handlers/verify_device.js";

const ENV = {
  SUPABASE_URL: "https://test.supabase.co",
  SUPABASE_SERVICE_ROLE_KEY: "test-key",
};

function post(body) {
  return new Request(new URL("/api/verify-device", "http://edge.test"), {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
}

test("verify-device: returns 405 for non-POST", async () => {
  const req = new Request(new URL("/api/verify-device", "http://edge.test"), { method: "GET" });
  const res = await handler.fetch(req, ENV);
  assert.equal(res.status, 405);
});

test("verify-device: returns 400 for missing fields", async () => {
  const res = await handler.fetch(post({}), ENV);
  assert.equal(res.status, 400);
});

test("verify-device: returns 400 for missing device_fingerprint", async () => {
  const res = await handler.fetch(post({ email: "a@b.com" }), ENV);
  assert.equal(res.status, 400);
});

test("verify-device: returns 400 for invalid JSON", async () => {
  const req = new Request(new URL("/api/verify-device", "http://edge.test"), {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: "not-json",
  });
  const res = await handler.fetch(req, ENV);
  assert.equal(res.status, 400);
});

test("verify-device: returns license_status=none when no license exists", async () => {
  const origFetch = globalThis.fetch;
  globalThis.fetch = (url) => {
    return Promise.resolve(
      new Response(JSON.stringify(null), {
        status: 406,
        headers: { "Content-Type": "application/json" },
      }),
    );
  };

  try {
    const res = await handler.fetch(
      post({ email: "nobody@test.com", device_fingerprint: "fp-1" }),
      ENV,
    );
    assert.equal(res.status, 200);
    const body = await res.json();
    assert.equal(body.license_status, "none");
    assert.equal(body.tier, null);
    assert.equal(body.active_device_count, 0);
  } finally {
    globalThis.fetch = origFetch;
  }
});

test("verify-device: returns license details for active license with registered device", async () => {
  const origFetch = globalThis.fetch;
  let callCount = 0;

  globalThis.fetch = (url, opts) => {
    callCount++;
    // License query
    if (url.includes("/rest/v1/licenses")) {
      return Promise.resolve(
        new Response(JSON.stringify({ status: "active", tier: "standard" }), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        }),
      );
    }
    // Device query
    if (url.includes("/rest/v1/devices")) {
      if (url.includes("limit=0")) {
        // Count query
        return Promise.resolve(
          new Response(JSON.stringify([]), {
            status: 200,
            headers: {
              "Content-Type": "application/json",
              "content-range": "0-2/3",
            },
          }),
        );
      }
      return Promise.resolve(
        new Response(JSON.stringify({ active: true }), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        }),
      );
    }
    return Promise.resolve(new Response("{}", { status: 200, headers: { "Content-Type": "application/json" } }));
  };

  try {
    const res = await handler.fetch(
      post({ email: "user@test.com", device_fingerprint: "fp-1" }),
      ENV,
    );
    assert.equal(res.status, 200);
    const body = await res.json();
    assert.equal(body.license_status, "active");
    assert.equal(body.tier, "standard");
    assert.equal(body.device_registered, true);
    assert.equal(body.active_device_count, 3);
  } finally {
    globalThis.fetch = origFetch;
  }
});

test("verify-device: returns device_registered=false when device not found", async () => {
  const origFetch = globalThis.fetch;

  globalThis.fetch = (url) => {
    if (url.includes("/rest/v1/licenses")) {
      return Promise.resolve(
        new Response(JSON.stringify({ status: "active", tier: "standard" }), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        }),
      );
    }
    if (url.includes("/rest/v1/devices")) {
      return Promise.resolve(
        new Response(JSON.stringify(null), {
          status: 406,
          headers: { "Content-Type": "application/json" },
        }),
      );
    }
    return Promise.resolve(new Response("{}", { status: 200, headers: { "Content-Type": "application/json" } }));
  };

  try {
    const res = await handler.fetch(
      post({ email: "user@test.com", device_fingerprint: "unknown-fp" }),
      ENV,
    );
    assert.equal(res.status, 200);
    const body = await res.json();
    assert.equal(body.device_registered, false);
  } finally {
    globalThis.fetch = origFetch;
  }
});
