// Admin panel for iFlixify IPTV.
//
// GET  /admin                      → admin HTML page (client-side auth)
// GET  /api/admin/users            → list users (requires admin JWT)
// PATCH /api/admin/users/:id/tier  → update user tier (requires admin JWT)
// DELETE /api/admin/users/:id      → delete user (requires admin JWT)
//
// Authentication: The client sends the Supabase JWT in the Authorization header.
// The server verifies the JWT by calling Supabase Auth, then checks if the
// user's profile has is_admin = true.

import { createClient } from "./_supabase.js";

// ---------- helpers ----------

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, PATCH, DELETE, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
  };
}

// Verify JWT and check admin status via Supabase Auth + profiles table.
async function verifyAdmin(request, env) {
  const authHeader = request.headers.get("Authorization") || "";
  const token = authHeader.replace(/^Bearer\s+/i, "").trim();

  if (!token) {
    return { error: "Missing Authorization header", status: 401 };
  }

  // Verify the JWT by calling Supabase Auth getUser endpoint
  const supabaseUrl = env.SUPABASE_URL;
  const serviceKey = env.SUPABASE_SERVICE_ROLE_KEY;

  if (!supabaseUrl || !serviceKey) {
    return { error: "Server misconfiguration", status: 500 };
  }

  const authRes = await fetch(`${supabaseUrl}/auth/v1/user`, {
    headers: {
      apikey: serviceKey,
      Authorization: `Bearer ${token}`,
    },
  });

  if (!authRes.ok) {
    return { error: "Invalid or expired token", status: 401 };
  }

  const authUser = await authRes.json();
  const userId = authUser.id;

  // Check if user is admin in profiles table
  const db = createClient(env);
  const { data: profile, error } = await db
    .from("profiles")
    .select("is_admin")
    .eq("id", userId)
    .single();

  if (error || !profile) {
    return { error: "Profile not found", status: 403 };
  }

  if (!profile.is_admin) {
    return { error: "Access denied: admin privileges required", status: 403 };
  }

  return { userId, email: authUser.email };
}

// Extract user ID from URL path like /api/admin/users/abc123/tier
function extractUserId(pathname) {
  const match = pathname.match(/^\/api\/admin\/users\/([^/]+)(?:\/tier)?$/);
  return match ? match[1] : null;
}

// ---------- API handlers ----------

async function handleListUsers(request, env) {
  const admin = await verifyAdmin(request, env);
  if (admin.error) return json({ error: admin.error }, admin.status);

  const db = createClient(env);
  const { data: users, error } = await db
    .from("profiles")
    .select("id, email, display_name, tier, is_admin, created_at")
    .order("created_at", { ascending: false });

  if (error) {
    return json({ error: "Failed to fetch users" }, 500);
  }

  return json({ users: users || [] });
}

async function handleUpdateTier(request, env, userId) {
  const admin = await verifyAdmin(request, env);
  if (admin.error) return json({ error: admin.error }, admin.status);

  let body;
  try {
    body = await request.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const { tier } = body;
  if (!tier || !["free", "pro"].includes(tier)) {
    return json({ error: "tier must be 'free' or 'pro'" }, 400);
  }

  const db = createClient(env);
  const { data, error } = await db
    .from("profiles")
    .update({ tier })
    .eq("id", userId)
    .select("id, email, display_name, tier, is_admin, created_at")
    .single();

  if (error) {
    return json({ error: "Failed to update tier" }, 500);
  }

  return json({ user: data });
}

async function handleDeleteUser(request, env, userId) {
  const admin = await verifyAdmin(request, env);
  if (admin.error) return json({ error: admin.error }, admin.status);

  // Prevent self-deletion
  if (userId === admin.userId) {
    return json({ error: "Cannot delete your own account" }, 400);
  }

  const serviceKey = env.SUPABASE_SERVICE_ROLE_KEY;
  const supabaseUrl = env.SUPABASE_URL;

  // Delete from Auth (this cascades to profiles if FK is set up)
  const authRes = await fetch(`${supabaseUrl}/auth/v1/admin/users/${userId}`, {
    method: "DELETE",
    headers: {
      apikey: serviceKey,
      Authorization: `Bearer ${serviceKey}`,
    },
  });

  if (!authRes.ok && authRes.status !== 204) {
    // Fallback: delete from profiles table only
    const db = createClient(env);
    await db.from("profiles").delete().eq("id", userId);
  }

  return json({ success: true });
}

// ---------- Admin page HTML ----------

function adminPage(env) {
  const supabaseUrl = env.SUPABASE_URL || "";
  const supabaseAnonKey = env.SUPABASE_ANON_KEY || "";

  const html = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>Admin Panel &mdash; iFlixify IPTV</title>
<style>
  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

  body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    background: #141414;
    color: #e5e5e5;
    min-height: 100vh;
  }

  header {
    background: #1c1c1c;
    border-bottom: 1px solid #333;
    padding: 16px 24px;
    display: flex;
    align-items: center;
    justify-content: space-between;
  }
  header h1 { font-size: 20px; font-weight: 700; }
  header h1 .accent { color: #E50914; }
  header .user-info { font-size: 13px; color: #999; }

  .container { max-width: 960px; margin: 0 auto; padding: 24px; }

  /* Auth card */
  .auth-card {
    max-width: 400px;
    margin: 80px auto;
    background: #1c1c1c;
    border-radius: 12px;
    padding: 40px 32px;
    box-shadow: 0 8px 32px rgba(0,0,0,.5);
  }
  .auth-card h2 { font-size: 22px; margin-bottom: 8px; text-align: center; }
  .auth-card p { color: #999; font-size: 14px; text-align: center; margin-bottom: 24px; }
  .auth-card label { display: block; font-size: 13px; color: #ccc; margin-bottom: 6px; font-weight: 500; }
  .auth-card input {
    width: 100%; padding: 12px 14px; border: 1px solid #333; border-radius: 8px;
    background: #141414; color: #fff; font-size: 15px; outline: none; margin-bottom: 16px;
  }
  .auth-card input:focus { border-color: #E50914; }
  .auth-card button {
    width: 100%; padding: 14px; border: none; border-radius: 8px;
    background: #E50914; color: #fff; font-size: 16px; font-weight: 600; cursor: pointer;
  }
  .auth-card button:hover { background: #be123c; }
  .auth-card button:disabled { opacity: .6; cursor: not-allowed; }

  /* Messages */
  .msg {
    margin-top: 12px; padding: 10px; border-radius: 8px; font-size: 14px; text-align: center; display: none;
  }
  .msg.error { display: block; background: #7f1d1d; color: #fca5a5; }
  .msg.success { display: block; background: #064e3b; color: #6ee7b7; }

  /* Table */
  .table-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
  .table-header h2 { font-size: 18px; }
  .table-header .count { color: #999; font-size: 14px; }

  table { width: 100%; border-collapse: collapse; background: #1c1c1c; border-radius: 8px; overflow: hidden; }
  thead { background: #252525; }
  th { padding: 12px 16px; text-align: left; font-size: 12px; font-weight: 600; color: #999; text-transform: uppercase; letter-spacing: .5px; }
  td { padding: 12px 16px; border-top: 1px solid #2a2a2a; font-size: 14px; }
  tr:hover td { background: #1f1f1f; }

  .badge {
    display: inline-block; padding: 2px 8px; border-radius: 4px; font-size: 12px; font-weight: 600;
  }
  .badge.free { background: #333; color: #999; }
  .badge.pro { background: #7c3aed; color: #fff; }
  .badge.admin { background: #E50914; color: #fff; }

  select.tier-select {
    background: #141414; color: #fff; border: 1px solid #333; border-radius: 4px;
    padding: 6px 8px; font-size: 13px; cursor: pointer;
  }
  select.tier-select:focus { border-color: #E50914; outline: none; }

  button.delete-btn {
    background: transparent; border: 1px solid #7f1d1d; color: #fca5a5;
    padding: 4px 10px; border-radius: 4px; font-size: 12px; cursor: pointer;
    transition: background .2s;
  }
  button.delete-btn:hover { background: #7f1d1d; color: #fff; }

  .spinner {
    display: inline-block; width: 16px; height: 16px;
    border: 2px solid rgba(255,255,255,.3); border-top-color: #fff;
    border-radius: 50%; animation: spin .6s linear infinite;
  }
  @keyframes spin { to { transform: rotate(360deg); } }

  .hidden { display: none; }

  .empty-state { text-align: center; padding: 48px; color: #666; }
</style>
</head>
<body>

<!-- Auth screen -->
<div id="authScreen" class="auth-card">
  <h2>i<span class="accent" style="color:#E50914">Flixify</span> Admin</h2>
  <p>Sign in with your admin account.</p>
  <label for="email">Email</label>
  <input type="email" id="email" placeholder="admin@example.com" required />
  <label for="password">Password</label>
  <input type="password" id="password" placeholder="Password" required />
  <button id="loginBtn" type="button">Sign In</button>
  <div id="authMsg" class="msg"></div>
</div>

<!-- Admin panel (hidden until authenticated) -->
<div id="adminPanel" class="hidden">
  <header>
    <h1>i<span class="accent">Flixify</span> Admin</h1>
    <div class="user-info">
      <span id="adminEmail"></span>
      <button id="logoutBtn" style="background:none;border:none;color:#E50914;cursor:pointer;margin-left:12px;font-size:13px;">Sign Out</button>
    </div>
  </header>
  <div class="container">
    <div class="table-header">
      <h2>Registered Users</h2>
      <span id="userCount" class="count"></span>
    </div>
    <div id="tableContainer">
      <table>
        <thead>
          <tr>
            <th>Email</th>
            <th>Display Name</th>
            <th>Tier</th>
            <th>Admin</th>
            <th>Joined</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody id="userTableBody"></tbody>
      </table>
    </div>
    <div id="emptyState" class="empty-state hidden">No users found.</div>
    <div id="adminMsg" class="msg" style="margin-top:16px;"></div>
  </div>
</div>

<script src="https://unpkg.com/@supabase/supabase-js@2/dist/umd/supabase.min.js"><\/script>
<script>
(function () {
  var supabaseUrl = "${supabaseUrl}";
  var supabaseAnonKey = "${supabaseAnonKey}";

  if (!supabaseUrl || !supabaseAnonKey) {
    document.getElementById("authMsg").textContent = "Server configuration error.";
    document.getElementById("authMsg").className = "msg error";
    return;
  }

  var client = supabase.createClient(supabaseUrl, supabaseAnonKey);
  var currentToken = null;

  // ---------- Auth ----------
  var authScreen = document.getElementById("authScreen");
  var adminPanel = document.getElementById("adminPanel");
  var loginBtn = document.getElementById("loginBtn");
  var logoutBtn = document.getElementById("logoutBtn");
  var authMsg = document.getElementById("authMsg");
  var adminEmail = document.getElementById("adminEmail");

  function showAuthMsg(text, type) {
    authMsg.textContent = text;
    authMsg.className = "msg " + type;
  }

  // Check for existing session
  client.auth.getSession().then(function (result) {
    var session = result.data && result.data.session;
    if (session && session.access_token) {
      currentToken = session.access_token;
      showAdminPanel(session.user.email);
    }
  });

  loginBtn.addEventListener("click", async function () {
    var email = document.getElementById("email").value.trim();
    var password = document.getElementById("password").value;

    if (!email || !password) {
      showAuthMsg("Please enter email and password.", "error");
      return;
    }

    loginBtn.disabled = true;
    loginBtn.textContent = "Signing in...";
    showAuthMsg("", "");

    var result = await client.auth.signInWithPassword({ email: email, password: password });

    loginBtn.disabled = false;
    loginBtn.textContent = "Sign In";

    if (result.error) {
      showAuthMsg(result.error.message || "Login failed.", "error");
      return;
    }

    currentToken = result.data.session.access_token;
    showAdminPanel(result.data.user.email);
  });

  logoutBtn.addEventListener("click", async function () {
    await client.auth.signOut();
    currentToken = null;
    authScreen.classList.remove("hidden");
    adminPanel.classList.add("hidden");
  });

  function showAdminPanel(email) {
    authScreen.classList.add("hidden");
    adminPanel.classList.remove("hidden");
    adminEmail.textContent = email;
    loadUsers();
  }

  // ---------- Users ----------
  var userTableBody = document.getElementById("userTableBody");
  var userCount = document.getElementById("userCount");
  var emptyState = document.getElementById("emptyState");
  var adminMsg = document.getElementById("adminMsg");

  function showAdminMsg(text, type) {
    adminMsg.textContent = text;
    adminMsg.className = "msg " + type;
    if (type === "success") {
      setTimeout(function () { adminMsg.className = "msg"; }, 3000);
    }
  }

  async function loadUsers() {
    var res = await fetch("/api/admin/users", {
      headers: { Authorization: "Bearer " + currentToken },
    });
    var data = await res.json();

    if (res.status === 401 || res.status === 403) {
      showAdminMsg(data.error || "Access denied.", "error");
      return;
    }

    var users = data.users || [];
    userCount.textContent = users.length + " user" + (users.length !== 1 ? "s" : "");

    if (users.length === 0) {
      emptyState.classList.remove("hidden");
      userTableBody.innerHTML = "";
      return;
    }

    emptyState.classList.add("hidden");
    userTableBody.innerHTML = users.map(function (u) {
      var tierBadge = u.tier === "pro"
        ? '<span class="badge pro">PRO</span>'
        : '<span class="badge free">FREE</span>';
      var adminBadge = u.is_admin ? ' <span class="badge admin">ADMIN</span>' : '';
      var joined = u.created_at ? new Date(u.created_at).toLocaleDateString() : "-";
      var tierSelect = u.is_admin ? '' :
        '<select class="tier-select" data-user-id="' + u.id + '">' +
        '<option value="free"' + (u.tier === "free" ? " selected" : "") + '>Free</option>' +
        '<option value="pro"' + (u.tier === "pro" ? " selected" : "") + '>Pro</option>' +
        '</select>';
      var deleteBtn = u.is_admin ? '' :
        '<button class="delete-btn" data-user-id="' + u.id + '" data-email="' + (u.email || '') + '">Delete</button>';

      return '<tr>' +
        '<td>' + (u.email || '-') + '</td>' +
        '<td>' + (u.display_name || '-') + '</td>' +
        '<td>' + tierBadge + '</td>' +
        '<td>' + adminBadge + '</td>' +
        '<td>' + joined + '</td>' +
        '<td>' + tierSelect + ' ' + deleteBtn + '</td>' +
        '</tr>';
    }).join("");

    // Attach event listeners
    document.querySelectorAll(".tier-select").forEach(function (sel) {
      sel.addEventListener("change", async function () {
        var userId = this.getAttribute("data-user-id");
        var newTier = this.value;
        await updateTier(userId, newTier);
      });
    });

    document.querySelectorAll(".delete-btn").forEach(function (btn) {
      btn.addEventListener("click", async function () {
        var userId = this.getAttribute("data-user-id");
        var email = this.getAttribute("data-email");
        if (confirm("Delete user " + email + "? This cannot be undone.")) {
          await deleteUser(userId);
        }
      });
    });
  }

  async function updateTier(userId, tier) {
    var res = await fetch("/api/admin/users/" + userId + "/tier", {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        Authorization: "Bearer " + currentToken,
      },
      body: JSON.stringify({ tier: tier }),
    });
    var data = await res.json();

    if (res.ok) {
      showAdminMsg("Tier updated to " + tier + ".", "success");
      loadUsers();
    } else {
      showAdminMsg(data.error || "Failed to update tier.", "error");
    }
  }

  async function deleteUser(userId) {
    var res = await fetch("/api/admin/users/" + userId, {
      method: "DELETE",
      headers: { Authorization: "Bearer " + currentToken },
    });
    var data = await res.json();

    if (res.ok) {
      showAdminMsg("User deleted.", "success");
      loadUsers();
    } else {
      showAdminMsg(data.error || "Failed to delete user.", "error");
    }
  }
})();
<\/script>
</body>
</html>`;

  return new Response(html, {
    status: 200,
    headers: { "Content-Type": "text/html; charset=utf-8" },
  });
}

// ---------- WinterCG fetch handler ----------

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const { pathname } = url;
    const method = request.method;

    // CORS preflight
    if (method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders() });
    }

    // Admin page
    if (pathname === "/admin" && method === "GET") {
      return adminPage(env);
    }

    // API: list users
    if (pathname === "/api/admin/users" && method === "GET") {
      return handleListUsers(request, env);
    }

    // API: update tier  /api/admin/users/:id/tier
    if (pathname.match(/^\/api\/admin\/users\/[^/]+\/tier$/) && method === "PATCH") {
      const userId = extractUserId(pathname);
      return handleUpdateTier(request, env, userId);
    }

    // API: delete user  /api/admin/users/:id
    if (pathname.match(/^\/api\/admin\/users\/[^/]+$/) && method === "DELETE") {
      const userId = extractUserId(pathname);
      return handleDeleteUser(request, env, userId);
    }

    return null; // not our route
  },
};
