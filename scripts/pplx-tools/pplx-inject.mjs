// Inject a perplexity.ai web session (the __Secure-next-auth.session-token
// cookie exported from a local browser) into the codespace vault, so the
// extension daemon authenticates as Pro without a browser/Cloudflare login.
//
// Usage: PERPLEXITY_VAULT_PASSPHRASE=... PPLX_DIST=<dist> node pplx-inject.mjs <cookies-file>
// (normally invoked by pplx-refresh.sh, which resolves passphrase + dist)
//
// Input file may be: a bare JWT token, a raw "Cookie:" header string, or a
// JSON array (Cookie-Editor / Playwright export).

import { readFileSync, writeFileSync, existsSync, mkdirSync, readdirSync } from "fs";
import { execSync } from "child_process";

const PROFILE = process.env.PERPLEXITY_PROFILE || "codespace";
const EMAIL = process.env.PPLX_EMAIL || "KarimKiki@gmx.de";
const file = process.argv[2];
if (!file) { console.error("usage: node pplx-inject.mjs <cookies-file>"); process.exit(1); }

// --- locate the perplexity-user-mcp dist and its Vault / profile chunks ---
let DIST = process.env.PPLX_DIST;
if (!DIST || !existsSync(DIST)) {
  try {
    DIST = execSync(`find "$HOME/.npm/_npx" -type d -path '*perplexity-user-mcp/dist' 2>/dev/null | head -1`, { encoding: "utf8" }).trim();
  } catch {}
}
if (!DIST || !existsSync(DIST)) { console.error("cannot locate perplexity-user-mcp/dist (set PPLX_DIST)"); process.exit(1); }

// Resolve chunks by following the package's own imports in a stable entry file.
// esbuild minifies class/function names, so we trust the runner's import map.
function chunkFor(symbol, entries = ["manual-login-runner.mjs", "login-runner.mjs", "cli.mjs"]) {
  for (const entry of entries) {
    let src; try { src = readFileSync(`${DIST}/${entry}`, "utf8"); } catch { continue; }
    const re = /import\s*\{([^}]*)\}\s*from\s*"(\.\/chunk-[^"]+\.mjs)"/g;
    let m;
    while ((m = re.exec(src))) {
      const names = m[1].split(",").map((s) => s.trim().split(/\s+as\s+/)[0].trim());
      if (names.includes(symbol)) return `${DIST}/${m[2].slice(2)}`;
    }
  }
  return null;
}
const vaultChunk = chunkFor("Vault");
const profChunk = chunkFor("getProfilePaths");
if (!vaultChunk || !profChunk) { console.error("could not locate Vault/profile chunks in dist"); process.exit(1); }
const { Vault } = await import(vaultChunk);
const { getProfilePaths, recordLoginSuccess } = await import(profChunk);

// --- parse the cookie input (token / header / JSON) ---
const text = readFileSync(file, "utf8").trim();
let raw;
if (text.startsWith("[") || text.startsWith("{")) {
  raw = JSON.parse(text);
  if (!Array.isArray(raw) && Array.isArray(raw.cookies)) raw = raw.cookies;
  if (!Array.isArray(raw)) { console.error("expected a JSON array of cookies"); process.exit(1); }
} else if (text.startsWith("eyJ") && !text.includes("=") && !text.includes(";")) {
  raw = [{ name: "__Secure-next-auth.session-token", value: text }];
} else {
  raw = text.split(/;\s*/).map((kv) => {
    const i = kv.indexOf("=");
    return i < 0 ? null : { name: kv.slice(0, i).trim(), value: kv.slice(i + 1).trim() };
  }).filter(Boolean);
}

function normSameSite(s) {
  const v = String(s ?? "").toLowerCase();
  if (v === "no_restriction" || v === "none") return "None";
  if (v === "strict") return "Strict";
  return "Lax";
}
const cookies = raw
  .filter((c) => c && c.name && c.value)
  .filter((c) => String(c.domain ?? "").includes("perplexity.ai") || !c.domain)
  .map((c) => {
    const domain = c.domain && String(c.domain).includes("perplexity") ? c.domain : ".perplexity.ai";
    let expires = c.expires ?? c.expirationDate ?? -1;
    expires = typeof expires === "number" ? Math.floor(expires) : -1;
    return { name: c.name, value: c.value, domain, path: c.path || "/", expires,
      httpOnly: !!c.httpOnly, secure: c.secure !== false, sameSite: normSameSite(c.sameSite) };
  });

const names = cookies.map((c) => c.name);
console.log(`Parsed ${cookies.length} perplexity.ai cookies: ${names.join(", ")}`);
if (!names.some((n) => n.startsWith("__Secure-next-auth.session-token"))) {
  console.error("WARNING: no '__Secure-next-auth.session-token' — session likely won't authenticate.");
}

const paths = getProfilePaths(PROFILE);
if (!existsSync(paths.dir)) mkdirSync(paths.dir, { recursive: true });
const vault = new Vault();
await vault.set(PROFILE, "cookies", JSON.stringify(cookies));
await vault.set(PROFILE, "email", EMAIL);
if (!existsSync(paths.modelsCache)) writeFileSync(paths.modelsCache, JSON.stringify({ models: {} }, null, 2));
recordLoginSuccess(PROFILE, { tier: "pro", loginMode: "manual", lastLogin: new Date().toISOString() });
writeFileSync(paths.reinit, String(Date.now()));
console.log(`OK: injected ${cookies.length} cookie(s) into vault profile '${PROFILE}'.`);
