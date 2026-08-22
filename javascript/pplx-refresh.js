#!/usr/bin/env node
// pplx-refresh.sh — portiert nach javascript
// Quelle: shell, OpenClaw@main:scripts/pplx-tools/pplx-refresh.sh
// Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

// Refresh the codespace Perplexity session from a locally-exported cookie.
//
// Usage:
//   ./pplx-refresh.js [cookie-file]
//
// cookie-file defaults to ~/pplx-cookies.txt. Put your local browser's
// __Secure-next-auth.session-token value (raw), or the whole Cookie header,
// or a JSON cookie export, into that file first.
//
// Steps: ensure daemon browser -> read daemon passphrase -> inject into vault
//        -> trigger reinit -> verify authenticated.

import { execSync, spawn } from 'child_process';
import fs from 'fs';
import path from 'path';
import os from 'os';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const CFG = process.env.PERPLEXITY_CONFIG_DIR || path.join(os.homedir(), '.perplexity-mcp');
const PROFILE = process.env.PERPLEXITY_PROFILE || 'codespace';
const COOKIE_FILE = process.argv[2] || path.join(os.homedir(), 'pplx-cookies.txt');

if (!fs.existsSync(COOKIE_FILE) || fs.statSync(COOKIE_FILE).size === 0) {
  console.error(`✗ Cookie file empty/missing: ${COOKIE_FILE}`);
  console.error('  Export __Secure-next-auth.session-token from your local browser');
  console.error('  (DevTools → Application → Cookies → www.perplexity.ai) into that file.');
  process.exit(1);
}

// 1. ensure the extension daemon has a usable browser (idempotent)
execSync(`${path.join(__dirname, 'pplx-setup.sh')}`, { stdio: 'inherit' });

// 2. daemon pid + vault passphrase (never guessed — read from the live daemon)
const LOCK = path.join(CFG, 'daemon.lock');
if (!fs.existsSync(LOCK)) {
  console.error(`✗ no daemon.lock at ${LOCK} — is the extension running?`);
  process.exit(1);
}

const lockData = JSON.parse(fs.readFileSync(LOCK, 'utf8'));
const PID = lockData.pid;

try {
  execSync(`kill -0 ${PID}`, { stdio: 'ignore' });
} catch (error) {
  console.error(`✗ daemon pid ${PID} not running`);
  process.exit(1);
}

// Read environment variables from /proc/PID/environ (Linux-specific)
let PASS = '';
try {
  const environ = fs.readFileSync(`/proc/${PID}/environ`, 'utf8');
  const vars = environ.split('\0');
  for (const v of vars) {
    if (v.startsWith('PERPLEXITY_VAULT_PASSPHRASE=')) {
      PASS = v.substring('PERPLEXITY_VAULT_PASSPHRASE='.length);
      break;
    }
  }
} catch (err) {
  // fallback method for non-Linux systems
  try {
    const psEnv = execSync(`ps eww ${PID} | grep -o 'PERPLEXITY_VAULT_PASSPHRASE=[^ ]*' | cut -d= -f2`, {
      encoding: 'utf8'
    }).trim();
    PASS = psEnv;
  } catch (fallbackErr) {
    console.error('✗ no PERPLEXITY_VAULT_PASSPHRASE in daemon env');
    process.exit(1);
  }
}

if (!PASS) {
  console.error('✗ no PERPLEXITY_VAULT_PASSPHRASE in daemon env');
  process.exit(1);
}

// 3. locate the perplexity-user-mcp dist (populate npx cache if needed)
let DIST = '';
try {
  const npxDir = path.join(os.homedir(), '.npm', '_npx');
  const files = fs.readdirSync(npxDir, { recursive: true });
  for (const f of files) {
    if (f.includes('perplexity-user-mcp') && f.endsWith('dist') && fs.statSync(path.join(npxDir, f)).isDirectory()) {
      DIST = path.join(npxDir, f);
      break;
    }
  }
} catch (err) {
  // ignore and try npx
}

if (!DIST) {
  try {
    execSync('npx -y perplexity-user-mcp --version', { stdio: 'ignore' });
    const npxDir = path.join(os.homedir(), '.npm', '_npx');
    const files = fs.readdirSync(npxDir, { recursive: true });
    for (const f of files) {
      if (f.includes('perplexity-user-mcp') && f.endsWith('dist') && fs.statSync(path.join(npxDir, f)).isDirectory()) {
        DIST = path.join(npxDir, f);
        break;
      }
    }
  } catch (err) {
    // ignore
  }
}

// 4. inject
const env = {
  ...process.env,
  PERPLEXITY_VAULT_PASSPHRASE: PASS,
  PERPLEXITY_CONFIG_DIR: CFG,
  PERPLEXITY_PROFILE: PROFILE,
  PPLX_DIST: DIST
};

const injectProcess = spawn('node', [path.join(__dirname, 'pplx-inject.mjs'), COOKIE_FILE], { env, stdio: 'inherit' });

injectProcess.on('close', (code) => {
  if (code !== 0) {
    process.exit(code);
  }

  // 5. trigger daemon reinit
  const reinitFile = path.join(CFG, 'profiles', PROFILE, '.reinit');
  fs.writeFileSync(reinitFile, Math.floor(Date.now() / 1000).toString());
  console.log('→ reinit triggered, waiting for daemon...');

  // 6. verify
  const STAT = path.join(CFG, 'profiles', PROFILE, 'daemon-status.json');
  let count = 0;
  const interval = setInterval(() => {
    count++;
    if (count > 20) {
      clearInterval(interval);
      console.log(`⚠️  not authenticated yet. Check: tail -20 ${path.join(CFG, 'daemon.log')}`);
      process.exit(1);
    }

    if (!fs.existsSync(STAT)) return;

    try {
      const status = JSON.parse(fs.readFileSync(STAT, 'utf8'));
      const AUTH = status.authenticated;
      const TIER = status.tier;
      if (AUTH === true) {
        clearInterval(interval);
        console.log(`✅ authenticated — tier: ${TIER}`);
        process.exit(0);
      }
    } catch (err) {
      // ignore parse errors
    }
  }, 1500);
});
