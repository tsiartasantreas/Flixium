// GET /dl/latest        → 302 → newest universal APK on the latest GH Release
// GET /dl/latest/arm64  → 302 → newest arm64 APK on the latest GH Release
// GET /dl/latest/stable → 302 → newest non-beta universal APK
//
// Queries the GitHub Releases API (no auth needed for public repos) and 302s
// to the matching browser_download_url. Edge-cached briefly so a cold GitHub
// API doesn't slow the Downloader install.

const DEFAULT_REPO = "andreastsiartas/iFlixify-IPTV"; // overridden by GITHUB_REPO env

function repoFromEnv(env) {
  const r = env.GITHUB_REPO?.trim();
  if (!r) return DEFAULT_REPO;
  return r;
}

function pickAsset(assets, wantArm64) {
  // Prefer explicit abi filenames; fall back to "universal".
  if (wantArm64) {
    const a = assets.find((x) => /arm64/i.test(x.name));
    if (a) return a;
  }
  const universal = assets.find((x) => /universal/i.test(x.name) && !/arm64/i.test(x.name));
  if (universal) return universal;
  // Fallback: any .apk that isn't the arm64 build when universal is requested.
  return assets.find((x) => x.name.endsWith(".apk"));
}

async function latestRelease(repo, { allowBeta = true } = {}) {
  const url = `https://api.github.com/repos/${repo}/releases`;
  const res = await fetch(url, {
    headers: {
      Accept: "application/vnd.github+json",
      "User-Agent": "iflixify-edge",
    },
  });
  if (!res.ok) {
    throw new Error(`GitHub API ${res.status} for ${repo}`);
  }
  const releases = await res.json();
  if (!Array.isArray(releases) || releases.length === 0) {
    throw new Error(`No releases found for ${repo}`);
  }
  const filtered = allowBeta
    ? releases
    : releases.filter((r) => !/beta|rc|alpha/i.test(r.tag_name || ""));
  return (filtered.length ? filtered : releases)[0];
}

// WinterCG fetch handler (default export).
export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname;

    const isLatest = path === "/dl/latest";
    const isArm64 = path === "/dl/latest/arm64";
    const isStable = path === "/dl/latest/stable";

    if (!isLatest && !isArm64 && !isStable) {
      return new Response("Not Found", { status: 404 });
    }

    try {
      const release = await latestRelease(repoFromEnv(env), {
        allowBeta: !isStable,
      });
      const asset = pickAsset(release.assets || [], isArm64);
      if (!asset || !asset.browser_download_url) {
        return new Response(
          `No APK asset in latest release (${release.tag_name})`,
          { status: 404 },
        );
      }
      return Response.redirect(asset.browser_download_url, 302);
    } catch (err) {
      return new Response(`redirect error: ${err.message}`, { status: 502 });
    }
  },
};
