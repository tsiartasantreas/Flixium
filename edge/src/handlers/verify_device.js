// POST /api/verify-device
// Accepts { email, device_fingerprint }
// Checks if the device is registered and the license is active.
// Returns { tier, license_status, active_device_count }

import { createClient } from "./_supabase.js";

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

    // 1. Check license
    const { data: license, error: licErr } = await supabase
      .from("licenses")
      .select("status, tier")
      .eq("email", email)
      .single();

    if (licErr || !license) {
      return new Response(
        JSON.stringify({
          tier: null,
          license_status: "none",
          active_device_count: 0,
        }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    }

    // 2. Check if this device is registered and active
    const { data: device, error: devErr } = await supabase
      .from("devices")
      .select("active")
      .eq("email", email)
      .eq("device_fingerprint", device_fingerprint)
      .single();

    if (devErr || !device || !device.active) {
      return new Response(
        JSON.stringify({
          tier: license.tier,
          license_status: license.status,
          active_device_count: 0,
          device_registered: false,
        }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    }

    // 3. Count active devices
    const { count } = await supabase
      .from("devices")
      .select("*", { count: "exact", head: true })
      .eq("email", email)
      .eq("active", true);

    return new Response(
      JSON.stringify({
        tier: license.tier,
        license_status: license.status,
        active_device_count: count || 0,
        device_registered: true,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  },
};
