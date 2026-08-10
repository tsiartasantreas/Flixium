// POST /api/webhook
// Receives Revolut payment confirmation (simulated).
// Verifies the activation_code, upserts the license, registers the device.
// Returns { success: true }

import { createClient } from "./_supabase.js";

const MAX_ACTIVE_DEVICES = 5;

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

    // Expect either a real Revolut payload or our simulated one.
    // The simulated flow sends { activation_code, email, device_fingerprint }.
    const { activation_code, email, device_fingerprint } = body;
    if (!activation_code || !email) {
      return new Response(
        JSON.stringify({ error: "activation_code and email are required" }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }

    const supabase = createClient(env);

    // 1. Verify activation code exists and is unused
    const { data: codeRow, error: codeErr } = await supabase
      .from("activation_codes")
      .select("*")
      .eq("code", activation_code)
      .eq("used", false)
      .single();

    if (codeErr || !codeRow) {
      return new Response(
        JSON.stringify({ error: "Invalid or already-used activation code" }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }

    // 2. Mark activation code as used
    await supabase
      .from("activation_codes")
      .update({ used: true })
      .eq("code", activation_code);

    // 3. Upsert license (email -> active)
    const { error: licErr } = await supabase.from("licenses").upsert(
      {
        email,
        status: "active",
        tier: "standard",
      },
      { onConflict: "email" },
    );

    if (licErr) {
      return new Response(
        JSON.stringify({ error: "Failed to upsert license" }),
        { status: 500, headers: { "Content-Type": "application/json" } },
      );
    }

    // 4. Count current active devices for this email
    const { count, error: countErr } = await supabase
      .from("devices")
      .select("*", { count: "exact", head: true })
      .eq("email", email)
      .eq("active", true);

    if (countErr) {
      return new Response(
        JSON.stringify({ error: "Failed to count devices" }),
        { status: 500, headers: { "Content-Type": "application/json" } },
      );
    }

    // 5. Register device if under limit
    const fp = device_fingerprint || codeRow.device_fingerprint;
    if (count < MAX_ACTIVE_DEVICES) {
      await supabase.from("devices").upsert(
        {
          email,
          device_fingerprint: fp,
          active: true,
        },
        { onConflict: "email,device_fingerprint" },
      );
    } else {
      // Device limit reached — still succeed but note the limit
      return new Response(
        JSON.stringify({
          success: true,
          warning: "Device limit reached (max 5). New device not registered.",
        }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify({ success: true }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  },
};
