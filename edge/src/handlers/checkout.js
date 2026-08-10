// POST /api/checkout
// Accepts { email, device_fingerprint }
// Creates an activation_code in Supabase and a mock Revolut checkout session.
// Returns { checkout_url, activation_code }

import { createClient } from "./_supabase.js";

function generateCode() {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // no ambiguous chars
  let code = "";
  const bytes = new Uint8Array(12);
  crypto.getRandomValues(bytes);
  for (const b of bytes) {
    code += chars[b % chars.length];
  }
  return code;
}

export default {
  async fetch(request, env) {
    if (request.method !== "POST") {
      return new Response(JSON.stringify({ error: "Method not allowed" }), {
        status: 405,
        headers: { "Content-Type": "application/json" },
      });
    }

    let body;
    try {
      body = await request.json();
    } catch {
      return new Response(JSON.stringify({ error: "Invalid JSON" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    const { email, device_fingerprint } = body;
    if (!email || !device_fingerprint) {
      return new Response(
        JSON.stringify({ error: "email and device_fingerprint are required" }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }

    const supabase = createClient(env);

    // Generate a unique activation code
    const activation_code = generateCode();

    // Insert activation_code record
    const { error: codeError } = await supabase.from("activation_codes").insert({
      code: activation_code,
      email,
      device_fingerprint,
      used: false,
    });

    if (codeError) {
      return new Response(
        JSON.stringify({ error: "Failed to create activation code" }),
        { status: 500, headers: { "Content-Type": "application/json" } },
      );
    }

    // --- Mock Revolut checkout (replace with real Revolut API later) ---
    const checkout_url = `https://checkout.revolut.com/pay/mock_${activation_code}`;

    return new Response(
      JSON.stringify({ checkout_url, activation_code }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  },
};
