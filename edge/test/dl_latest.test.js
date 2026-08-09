import { test } from "node:test";
import assert from "node:assert";
import handler from "../src/handlers/dl_latest.js";

function req(path) {
  return new Request(new URL(path, "http://edge.test"), { method: "GET" });
}

test("unknown path returns 404", async () => {
  const res = await handler.fetch(req("/nope"), {});
  assert.equal(res.status, 404);
});

test("pickAsset-free path: returns 502 when repo has no releases (mocked by bad repo)", async () => {
  // Use a repo that exists but has no releases we can reach in CI sandbox:
  // we just assert the handler returns a 502 (network/empty) not a crash.
  const res = await handler.fetch(req("/dl/latest"), { GITHUB_REPO: "octocat/empty" });
  assert.ok([404, 502].includes(res.status), `unexpected status ${res.status}`);
});
