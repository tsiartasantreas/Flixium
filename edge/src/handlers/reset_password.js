// Password-reset page for Supabase Auth.
//
// Supabase sends the user to  /reset-password#access_token=<JWT>&...
// The client-side JS extracts the token from the hash fragment and calls
// supabase.auth.updateUser({ password }) directly — no server-side secret needed.

export default {
  async fetch(request, env) {
    if (request.method !== "GET") {
      return new Response(JSON.stringify({ error: "Method not allowed" }), {
        status: 405,
        headers: { "Content-Type": "application/json" },
      });
    }

    const supabaseUrl = env.SUPABASE_URL || "";

    const html = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>Reset Password &mdash; iFlixify IPTV</title>
<style>
  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

  body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto,
                 Helvetica, Arial, sans-serif;
    background: #141414;
    color: #fff;
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .card {
    background: #1c1c1c;
    border-radius: 12px;
    padding: 40px 32px;
    width: 100%;
    max-width: 420px;
    box-shadow: 0 8px 32px rgba(0,0,0,.5);
  }

  .logo {
    text-align: center;
    margin-bottom: 24px;
  }
  .logo h1 {
    font-size: 28px;
    font-weight: 700;
    color: #E11D48;
  }
  .logo p {
    color: #999;
    font-size: 14px;
    margin-top: 4px;
  }

  h2 {
    font-size: 20px;
    font-weight: 600;
    margin-bottom: 8px;
    text-align: center;
  }

  .subtitle {
    color: #aaa;
    font-size: 14px;
    text-align: center;
    margin-bottom: 24px;
  }

  label {
    display: block;
    font-size: 13px;
    font-weight: 500;
    color: #ccc;
    margin-bottom: 6px;
  }

  input[type="password"] {
    width: 100%;
    padding: 12px 14px;
    border: 1px solid #333;
    border-radius: 8px;
    background: #141414;
    color: #fff;
    font-size: 15px;
    outline: none;
    transition: border-color .2s;
    margin-bottom: 16px;
  }
  input[type="password"]:focus {
    border-color: #E11D48;
  }

  button[type="submit"] {
    width: 100%;
    padding: 14px;
    border: none;
    border-radius: 8px;
    background: #E11D48;
    color: #fff;
    font-size: 16px;
    font-weight: 600;
    cursor: pointer;
    transition: background .2s;
    margin-top: 8px;
  }
  button[type="submit"]:hover { background: #be123c; }
  button[type="submit"]:disabled {
    opacity: .6;
    cursor: not-allowed;
  }

  .msg {
    margin-top: 16px;
    padding: 12px;
    border-radius: 8px;
    font-size: 14px;
    text-align: center;
    display: none;
  }
  .msg.success { display: block; background: #064e3b; color: #6ee7b7; }
  .msg.error   { display: block; background: #7f1d1d; color: #fca5a5; }

  .open-btn {
    display: none;
    width: 100%;
    padding: 14px;
    margin-top: 16px;
    border: 2px solid #E11D48;
    border-radius: 8px;
    background: transparent;
    color: #E11D48;
    font-size: 16px;
    font-weight: 600;
    cursor: pointer;
    text-align: center;
    text-decoration: none;
    transition: background .2s, color .2s;
  }
  .open-btn:hover { background: #E11D48; color: #fff; }
  .open-btn.show  { display: block; }

  .spinner {
    display: inline-block;
    width: 18px;
    height: 18px;
    border: 2px solid rgba(255,255,255,.3);
    border-top-color: #fff;
    border-radius: 50%;
    animation: spin .6s linear infinite;
    vertical-align: middle;
    margin-right: 8px;
  }
  @keyframes spin { to { transform: rotate(360deg); } }

  .hidden { display: none; }
</style>
</head>
<body>
<div class="card">
  <div class="logo">
    <h1>iFlixify IPTV</h1>
    <p>Reset your password</p>
  </div>

  <form id="resetForm">
    <h2>Set a new password</h2>
    <p class="subtitle">Enter and confirm your new password below.</p>

    <label for="password">New Password</label>
    <input type="password" id="password" name="password"
           placeholder="At least 6 characters" minlength="6" required autocomplete="new-password" />

    <label for="confirm">Confirm Password</label>
    <input type="password" id="confirm" name="confirm"
           placeholder="Re-enter password" minlength="6" required autocomplete="new-password" />

    <button type="submit" id="submitBtn">Reset Password</button>
  </form>

  <div id="msg" class="msg"></div>
  <a id="openApp" class="open-btn" href="iflixify://">Open iFlixify IPTV</a>
</div>

<script src="https://unpkg.com/@supabase/supabase-js@2/dist/umd/supabase.min.js"><\/script>
<script>
(function () {
  // ---------- helpers ----------
  var form     = document.getElementById("resetForm");
  var msgEl    = document.getElementById("msg");
  var openBtn  = document.getElementById("openApp");
  var submitBtn = document.getElementById("submitBtn");

  function showMsg(text, type) {
    msgEl.textContent = text;
    msgEl.className = "msg " + type;
  }

  function setLoading(on) {
    submitBtn.disabled = on;
    submitBtn.innerHTML = on
      ? '<span class="spinner"></span> Updating\u2026'
      : "Reset Password";
  }

  // ---------- extract token from hash ----------
  function getHashParams() {
    var hash = window.location.hash.substring(1); // strip leading #
    var params = {};
    hash.split("&").forEach(function (pair) {
      var parts = pair.split("=");
      if (parts.length === 2) params[parts[0]] = decodeURIComponent(parts[1]);
    });
    return params;
  }

  var hashParams = getHashParams();
  var accessToken = hashParams.access_token;
  var refreshToken = hashParams.refresh_token;

  if (!accessToken) {
    form.classList.add("hidden");
    showMsg("Invalid or missing reset token. Please request a new password reset link from the iFlixify IPTV app.", "error");
    return;
  }

  // ---------- init supabase client ----------
  // The SUPABASE_URL placeholder is replaced server-side.
  var supabaseUrl = "${supabaseUrl}";
  // anon key is safe to expose in client-side code
  var supabaseAnonKey = "${env.SUPABASE_ANON_KEY || ""}";

  if (!supabaseUrl || !supabaseAnonKey) {
    form.classList.add("hidden");
    showMsg("Server configuration error. Please contact support.", "error");
    return;
  }

  var client = supabase.createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: "Bearer " + accessToken } },
  });

  // If Supabase also sent a refresh token, set the session so updateUser works
  if (refreshToken) {
    client.auth.setSession({ access_token: accessToken, refresh_token: refreshToken });
  }

  // ---------- form submit ----------
  form.addEventListener("submit", async function (e) {
    e.preventDefault();

    var pw  = document.getElementById("password").value;
    var con = document.getElementById("confirm").value;

    if (pw.length < 6) {
      showMsg("Password must be at least 6 characters.", "error");
      return;
    }
    if (pw !== con) {
      showMsg("Passwords do not match.", "error");
      return;
    }

    setLoading(true);
    showMsg("", "");

    var result = await client.auth.updateUser({ password: pw });

    setLoading(false);

    if (result.error) {
      showMsg(result.error.message || "Failed to update password. The link may have expired.", "error");
    } else {
      showMsg("Password updated successfully!", "success");
      form.classList.add("hidden");
      openBtn.classList.add("show");
    }
  });
})();
<\/script>
</body>
</html>`;

    return new Response(html, {
      status: 200,
      headers: { "Content-Type": "text/html; charset=utf-8" },
    });
  },
};
