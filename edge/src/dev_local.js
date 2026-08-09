// Minimal local harness so `npm run dev` can smoke-test the handler logic
// without a Wasmer deploy. Not used in production. Node-only.
import http from "node:http";
import handler from "./handlers/dl_latest.js";

const fakeEnv = { GITHUB_REPO: process.env.GITHUB_REPO || "andreastsiartas/Flixium" };
const port = process.env.PORT || 8787;

http
  .createServer(async (req, res) => {
    const url = new URL(req.url, `http://localhost:${port}`);
    const request = new Request(url, { method: req.method });
    const out = await handler.fetch(request, fakeEnv);
    res.statusCode = out.status;
    out.headers.forEach((v, k) => res.setHeader(k, v));
    res.end(out.status === 302 ? "" : await out.text());
  })
  .listen(port, () => console.log(`dl_latest dev on :${port}`));
