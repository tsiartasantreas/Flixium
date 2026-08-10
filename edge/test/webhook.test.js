import { test } from "node:test";
import assert from "node:assert";
import handler from "../src/handlers/webhook.js";

const ENV = {
  SUPABASE_URL: "https://test.supabase.co",
  SUPABASE_SERVICE_ROLE_KEY: "test-key",
};

function post(body) {
  return new Request(new URL("/api/webhook", "http://edge.test"), {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
}

// Mock fetch that returns different responses based on URL pattern
let mockResponses = [];

function mockFetch(url, opts) {
  const method = opts?.method || "GET";

  // Activation code check (GET select with eq filters)
  if (url.includes("/rest/v1/activation_codes") && method === "GET") {
    if (mockResponses.length > 0) {
      return Promise.resolve(mockResponses.shift());
    }
    // Default: valid unused code
    return Promise.resolve(
      new Response(JSON.stringify([{ code: "TEST12345678", email: "a@b.com", device_fingerprint: "fp-1" }]), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      }),
    );
  }

  // PATCH (mark code as used) or POST (upsert license/device)
  return Promise.resolve(
    new Response(JSON.stringify([{ id: 1 }]), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    }),
  );
}

// Mock for counting devices
function mockFetchCount(count) {
  return (url, opts) => {
    const method = opts?.method || "GET";

    if (url.includes("/rest/v1/activation_codes") && method === "GET") {
      return Promise.resolve(
        new Response(JSON.stringify([{ code: "TEST12345678", email: "a@b.com", device_fingerprint: "fp-1" }]), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        }),
      );
    }

    // Count query (limit=0)
    if (url.includes("limit=0") || url.includes("count=exact")) {
      return Promise.resolve(
        new Response(JSON.stringify([]), {
          status: 200,
          headers: {
            "Content-Type": "application/json",
            "content-range": `0-${count - 1}/${count}`,
          },
        }),
      );
    }

    return Promise.resolve(
      new Response(JSON.stringify([{ id: 1 }]), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      }),
    );
  };
}

test("webhook: returns 405 for non-POST", async () => {
  const req = new Request(new URL("/api/webhook", "http://edge.test"), { method: "GET" });
  const res = await handler.fetch(req, ENV);
  assert.equal(res.status, 405);
});

test("webhook: returns 400 for missing fields", async () => {
  const res = await handler.fetch(post({}), ENV);
  assert.equal(res.status, 400);
});

test("webhook: returns 400 for missing email", async () => {
  const res = await handler.fetch(post({ activation_code: "ABC123" }), ENV);
  assert.equal(res.status, 400);
});

test("webhook: returns 400 for invalid JSON", async () => {
  const req = new Request(new URL("/api/webhook", "http://edge.test"), {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: "bad",
  });
  const res = await handler.fetch(req, ENV);
  assert.equal(res.status, 400);
});

test("webhook: rejects invalid activation code", async () => {
  const origFetch = globalThis.fetch;
  globalThis.fetch = (url, opts) => {
    if (url.includes("/rest/v1/activation_codes") && (opts?.method || "GET") === "GET") {
      return Promise.resolve(
        new Response(JSON.stringify([]), {
          status: 404,
          headers: { "Content-Type": "application/json" },
        }),
      );
    }
    return Promise.resolve(new Response(JSON.stringify([]), { status: 200, headers: { "Content-Type": "application/json" } }));
  };

  try {
    const res = await handler.fetch(
      post({ activation_code: "BADCODE", email: "a@b.com", device_fingerprint: "fp-1" }),
      ENV,
    );
    assert.equal(res.status, 400);
    const body = await res.json();
    assert.ok(body.error.includes("Invalid"));
  } finally {
    globalThis.fetch = origFetch;
  }
});

test("webhook: succeeds with valid activation code", async () => {
  const origFetch = globalThis.fetch;
  globalThis.fetch = mockFetch;

  try {
    const res = await handler.fetch(
      post({ activation_code: "TEST12345678", email: "a@b.com", device_fingerprint: "fp-1" }),
      ENV,
    );
    assert.equal(res.status, 200);
    const body = await res.json();
    assert.equal(body.success, true);
  } finally {
    globalThis.fetch = origFetch;
  }
});

test("webhook: warns when device limit reached", async () => {
  const origFetch = globalThis.fetch;
  globalThis.fetch = mockFetchCount(5);

  try {
    const res = await handler.fetch(
      post({ activation_code: "TEST12345678", email: "a@b.com", device_fingerprint: "fp-new" }),
      ENV,
    );
    assert.equal(res.status, 200);
    const body = await res.json();
    assert.equal(body.success, true);
    assert.ok(body.warning, "should warn about device limit");
  } finally {
    globalThis.fetch = origFetch;
  }
});
