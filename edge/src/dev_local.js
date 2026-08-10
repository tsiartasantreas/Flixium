// Minimal local harness so `npm run dev` can smoke-test all handlers
// without a Wasmer deploy. Not used in production. Node-only.
import http from "node:http";
import router from "./handlers/index.js";

const fakeEnv = {
  GITHUB_REPO: process.env.GITHUB_REPO || "andreastsiartas/iFlixify-IPTV",
  SUPABASE_URL: process.env.SUPABASE_URL || "",
  SUPABASE_SERVICE_ROLE_KEY: process.env.SUPABASE_SERVICE_ROLE_KEY || "",
};
const port = process.env.PORT || 8787;

http
  .createServer(async (req, res) => {
    const url = new URL(req.url, `http://localhost:${port}`);
    // Reconstruct the request body for POST
    let body = null;
    if (req.method === "POST") {
      const chunks = [];
      for await (const chunk of req) chunks.push(chunk);
      body = Buffer.concat(chunks);
    }
    const request = new Request(url, {
      method: req.method,
      headers: Object.fromEntries(
        Object.entries(req.headers).filter(([, v]) => v !== undefined),
      ),
      body,
    });
    const out = await router.fetch(request, fakeEnv);
    res.statusCode = out.status;
    out.headers.forEach((v, k) => res.setHeader(k, v));
    res.end(out.status === 302 ? "" : await out.text());
  })
  .listen(port, () => console.log(`edge dev server on :${port}`));
