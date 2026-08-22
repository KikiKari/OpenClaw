#!/usr/bin/env node
// sandbox-vpn.sh — portiert nach javascript
// Quelle: shell, Onboarding@main:scripts/sandbox-vpn.sh
// Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

// Bringt die Sandbox reproduzierbar in das Tailscale-Tailnet des Nutzers —
// als Brücke am Agent-MITM-Proxy vorbei (sauberer Egress via SOCKS5) und mit
// Tailscale-SSH, damit die eigenen Geräte des Nutzers in die Sandbox kommen.
//
// Nutzt den WIEDERVERWENDBAREN Auth-Key aus der .env (nichts committet).
// userspace-networking: verändert NICHT die Host-Routen/den Agent-Proxy dieser
// Session; stellt einen SOCKS5-Proxy auf localhost:1055 bereit.
//
// Aufruf: scripts/sandbox-vpn.js   (idempotent; No-op ohne Auth-Key/tailscale)

import { spawn, execSync } from 'child_process';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const log = (...args) => console.log('[sandbox-vpn]', ...args);

// Auth-Key aus .env lesen (ohne die gesamte .env zu sourcen)
let KEY = "";
if (fs.existsSync('.env')) {
  const envContent = fs.readFileSync('.env', 'utf8');
  const match = envContent.match(/^TAILSCALE_AUTH_KEY="(.*)"/m);
  if (match) {
    KEY = match[1];
  }
}

if (!KEY) {
  log("kein TAILSCALE_AUTH_KEY in .env — überspringe VPN");
  process.exit(0);
}

// Tailscale installieren, falls nicht vorhanden
try {
  execSync('which tailscale', { stdio: 'ignore' });
} catch (error) {
  log("installiere Tailscale …");
  try {
    execSync('curl -fsSL https://tailscale.com/install.sh | sh', { stdio: 'ignore' });
  } catch (installError) {
    log("WARNUNG: Tailscale-Install fehlgeschlagen");
    process.exit(0);
  }
}

// tailscaled im userspace-Modus starten (SOCKS5 + HTTP-Proxy für Tailnet-Egress)
let tailscaleStatus;
try {
  tailscaleStatus = execSync('tailscale status', { stdio: 'ignore' });
} catch (error) {
  log("starte tailscaled (userspace, SOCKS5 localhost:1055) …");
  fs.mkdirSync('/var/lib/tailscale', { recursive: true });
  
  const tailscaled = spawn('tailscaled', [
    '--tun=userspace-networking',
    '--socks5-server=localhost:1055',
    '--outbound-http-proxy-listen=localhost:1056',
    '--statedir=/var/lib/tailscale'
  ], {
    detached: true,
    stdio: 'ignore'
  });
  
  tailscaled.unref();
  // Warte 4 Sekunden
  await new Promise(resolve => setTimeout(resolve, 4000));
}

// Ins Tailnet, mit Tailscale-SSH aktiviert
let statusOutput = "";
try {
  statusOutput = execSync('tailscale status 2>/dev/null', { encoding: 'utf8' });
} catch (error) {
  // Ignoriere Fehler
}

if (!statusOutput.includes('claude-sandbox')) {
  log("tailscale up (hostname=claude-sandbox, --ssh) …");
  try {
    execSync(`tailscale up --authkey="${KEY}" --hostname=claude-sandbox --ssh --accept-routes`, { stdio: 'ignore' });
  } catch (error) {
    log("WARNUNG: tailscale up fehlgeschlagen");
  }
} else {
  try {
    execSync('tailscale set --ssh', { stdio: 'ignore' });
  } catch (error) {
    // Ignoriere Fehler
  }
}

try {
  execSync('tailscale status', { stdio: 'ignore' });
  let IP = "";
  try {
    IP = execSync('tailscale ip -4 2>/dev/null', { encoding: 'utf8' }).split('\n')[0];
  } catch (error) {
    // IP bleibt leer
  }
  log(`im Tailnet: claude-sandbox ${IP || '?'} · SSH aktiv · SOCKS5 localhost:1055`);
} catch (error) {
  // Nicht verbunden
}

process.exit(0);
