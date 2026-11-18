#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "847dc572dbf0dfc5cd2c9a659c623b11e9ca8219fefb3272f8cbaa51df0eabcd", "source_sha256": "47064dbc7b32c01d57d42222f8cc3ac7caf9c8d82b98029dc5fc6ecb0d32f2c9", "target_language": "javascript"}
// collect_ist_gateway_a.sh — portiert nach javascript
// Quelle: shell, OpenClaw@gateway1:scripts/collect_ist_gateway_a.sh
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

import fs from 'fs';
import os from 'os';
import path from 'path';
import { execSync } from 'child_process';

const BASE_DIR = path.join(os.homedir(), '.openclaw');
const OUT_DIR = path.join(BASE_DIR, 'workspace', 'vscode');
const NOW_UTC = new Date().toISOString().replace(/\.\d+Z$/, 'Z');
const NOW_LOCAL = new Date().toLocaleString('de-DE') + ' ' + Intl.DateTimeFormat('de-DE', { timeZoneName: 'short' }).formatToParts(new Date()).find(part => part.type === 'timeZoneName').value;
const TS = new Date().toISOString().slice(0, 19).replace(/[:-]/g, '').replace('T', '-');

// Create output directory
fs.mkdirSync(OUT_DIR, { recursive: true });

const IST_FILE = path.join(OUT_DIR, 'IST-ZUSTAND_GATEWAY-A_NODE1.md');
const INV_FILE = path.join(OUT_DIR, 'ARTEFAKT-INVENTAR_GATEWAY-A_NODE1.md');
const CFG_FILE = path.join(OUT_DIR, 'OPENCLAW-CONFIG-SNAPSHOT_GATEWAY-A_NODE1.md');
const ENV_FILE = path.join(OUT_DIR, 'ENV-STATUS_GATEWAY-A_NODE1.md');
const RUN_FILE = path.join(OUT_DIR, `RUN-${TS}.md`);

const OPENCLAW_JSON = path.join(BASE_DIR, 'openclaw.json');
const ENV_DOT = path.join(BASE_DIR, '.env');
const ENV_SYSTEMD = path.join(BASE_DIR, 'gateway.systemd.env');
const VSCODE_DIR = path.join(BASE_DIR, '.vscode');

let HOSTNAME_FQDN = '';
try {
  HOSTNAME_FQDN = os.hostname();
} catch (e) {
  HOSTNAME_FQDN = os.hostname();
}

const HOSTNAME_SHORT = os.hostname();
const ARCH = process.arch;
const KERNEL = os.release();
let OS_PRETTY = 'Unbekannt';
try {
  const osRelease = fs.readFileSync('/etc/os-release', 'utf8');
  const match = osRelease.match(/^PRETTY_NAME=(.*)$/m);
  if (match) {
    OS_PRETTY = match[1].replace(/"/g, '');
  }
} catch (e) {
  // ignore
}

const IPV4_ALL = Object.values(os.networkInterfaces())
  .flat()
  .filter(iface => !iface.internal && iface.family === 'IPv4')
  .map(iface => iface.address)
  .join(' ');

let PUBLIC_IP = '(nicht ermittelt)';
try {
  PUBLIC_IP = execSync('curl -4 -s --max-time 4 ifconfig.me', { timeout: 4000 }).toString().trim();
} catch (e) {
  // ignore
}

let TAILSCALE_IP = '(nicht ermittelt)';
try {
  TAILSCALE_IP = execSync('tailscale ip -4', { timeout: 4000 }).toString().trim().split('\n')[0];
} catch (e) {
  // ignore
}

let OPENCLAW_VER = '(nicht ermittelt)';
try {
  OPENCLAW_VER = execSync('openclaw --version', { timeout: 4000 }).toString().trim();
} catch (e) {
  // ignore
}

let NODE_VER = '(nicht ermittelt)';
try {
  NODE_VER = process.version;
} catch (e) {
  // ignore
}

const istContent = `# IST-Zustand: Gateway A / Node 1

Stand (lokal): ${NOW_LOCAL}  
Stand (UTC): ${NOW_UTC}

## 1) Identitaet & System

- Gateway: **A**
- Node: **1**
- Hostname (short): \`${HOSTNAME_SHORT}\`
- Hostname (FQDN): \`${HOSTNAME_FQDN}\`
- Architektur: \`${ARCH}\`
- Kernel: \`${KERNEL}\`
- OS: \`${OS_PRETTY}\`
- IPv4 (lokal): \`${IPV4_ALL}\`
- Public IPv4: \`${PUBLIC_IP}\`
- Tailscale IPv4: \`${TAILSCALE_IP}\`
- OpenClaw Version: \`${OPENCLAW_VER}\`
- Node.js Version: \`${NODE_VER}\`

## 2) Arbeitsverzeichnisse

- Basis: \`${BASE_DIR}\`
- Funktionell VSCode: \`${VSCODE_DIR}\`
- Workspace Doku: \`${OUT_DIR}\`

## 3) Kernartefakte (Existenz)

- \`${OPENCLAW_JSON}\`: ${fs.existsSync(OPENCLAW_JSON) ? 'vorhanden' : 'fehlt'}
- \`${ENV_DOT}\`: ${fs.existsSync(ENV_DOT) ? 'vorhanden' : 'fehlt'}
- \`${ENV_SYSTEMD}\`: ${fs.existsSync(ENV_SYSTEMD) ? 'vorhanden' : 'fehlt'}
- \`${path.join(BASE_DIR, 'plugins/installs.json')}\`: ${fs.existsSync(path.join(BASE_DIR, 'plugins/installs.json')) ? 'vorhanden' : 'fehlt'}
- \`${path.join(BASE_DIR, 'plugin-skills')}\`: ${fs.existsSync(path.join(BASE_DIR, 'plugin-skills')) ? 'vorhanden' : 'fehlt'}`;

fs.writeFileSync(IST_FILE, istContent);

let invContent = '# Artefakt-Inventar: Gateway A / Node 1\n\n';
invContent += `Stand: ${NOW_LOCAL}\n\n`;
invContent += '## Top-Level in ~/.openclaw\n\n';
invContent += '```text\n';
try {
  invContent += fs.readdirSync(BASE_DIR).join('\n') + '\n';
} catch (e) {
  invContent += '(Fehler beim Lesen)\n';
}
invContent += '```\n\n';

invContent += '## ~/.openclaw/.vscode\n\n';
invContent += '```text\n';
if (fs.existsSync(VSCODE_DIR)) {
  try {
    const files = fs.readdirSync(VSCODE_DIR);
    files.forEach(file => {
      const stat = fs.statSync(path.join(VSCODE_DIR, file));
      invContent += `${stat.isDirectory() ? 'd' : '-'}${stat.mode.toString(8).slice(-3)} 1 ${process.getuid ? process.getuid() : 'unknown'} ${process.getgid ? process.getgid() : 'unknown'} ${stat.size} ${new Date(stat.mtime).toLocaleString('de-DE')} ${file}\n`;
    });
  } catch (e) {
    invContent += '(Fehler beim Lesen)\n';
  }
} else {
  invContent += '(nicht vorhanden)\n';
}
invContent += '```\n\n';

invContent += '## plugin-skills/\n\n';
invContent += '```text\n';
if (fs.existsSync(path.join(BASE_DIR, 'plugin-skills'))) {
  try {
    invContent += fs.readdirSync(path.join(BASE_DIR, 'plugin-skills')).join('\n') + '\n';
  } catch (e) {
    invContent += '(Fehler beim Lesen)\n';
  }
} else {
  invContent += '(nicht vorhanden)\n';
}
invContent += '```\n\n';

invContent += '## openclaw.json Backups\n\n';
invContent += '```text\n';
try {
  const files = fs.readdirSync(BASE_DIR).filter(f => f.startsWith('openclaw.json.bak'));
  if (files.length > 0) {
    invContent += files.join('\n') + '\n';
  } else {
    invContent += '(keine gefunden)\n';
  }
} catch (e) {
  invContent += '(keine gefunden)\n';
}
invContent += '```';

fs.writeFileSync(INV_FILE, invContent);

let cfgContent = '# OpenClaw Config Snapshot: Gateway A / Node 1\n\n';
cfgContent += `Stand: ${NOW_LOCAL}\n\n`;
cfgContent += '## Schluesselpositionen (grep)\n\n';
cfgContent += '```text\n';
if (fs.existsSync(OPENCLAW_JSON)) {
  try {
    const content = fs.readFileSync(OPENCLAW_JSON, 'utf8');
    const lines = content.split('\n');
    lines.forEach((line, index) => {
      if (line.match(/"gateway"|\"session\"|\"dmScope\"|\"auth\"|\"secrets\"|\"tools\"|\"plugins\"|\"profile\"|\"alsoAllow\"|\"denyCommands\"/)) {
        cfgContent += `${index + 1}: ${line}\n`;
      }
    });
  } catch (e) {
    cfgContent += '(Fehler beim Lesen)\n';
  }
} else {
  cfgContent += 'openclaw.json fehlt\n';
}
cfgContent += '```\n\n';

cfgContent += '## Ausschnitt gateway/session/auth\n\n';
cfgContent += '```json\n';
if (fs.existsSync(OPENCLAW_JSON)) {
  try {
    const content = fs.readFileSync(OPENCLAW_JSON, 'utf8');
    const lines = content.split('\n');
    const start = Math.max(0, 580 - 1);
    const end = Math.min(lines.length, 780);
    cfgContent += lines.slice(start, end).join('\n') + '\n';
  } catch (e) {
    cfgContent += '{ "error": "Fehler beim Lesen" }\n';
  }
} else {
  cfgContent += '{ "error": "openclaw.json fehlt" }\n';
}
cfgContent += '```';

fs.writeFileSync(CFG_FILE, cfgContent);

let envContent = '# ENV-Status: Gateway A / Node 1\n\n';
envContent += `Stand: ${NOW_LOCAL}\n\n`;
envContent += '## Dateien\n\n';
envContent += '```text\n';
try {
  [ENV_DOT, ENV_SYSTEMD].forEach(file => {
    if (fs.existsSync(file)) {
      const stat = fs.statSync(file);
      envContent += `-rw------- 1 ${process.getuid ? process.getuid() : 'unknown'} ${process.getgid ? process.getgid() : 'unknown'} ${stat.size} ${new Date(stat.mtime).toLocaleString('de-DE')} ${path.basename(file)}\n`;
    }
  });
} catch (e) {
  // ignore
}
envContent += '```\n\n';

envContent += '## .env (vollstaendig)\n\n';
envContent += '```dotenv\n';
if (fs.existsSync(ENV_DOT)) {
  try {
    envContent += fs.readFileSync(ENV_DOT, 'utf8') + '\n';
  } catch (e) {
    envContent += '# Fehler beim Lesen\n';
  }
} else {
  envContent += '# .env fehlt\n';
}
envContent += '```\n\n';

envContent += '## gateway.systemd.env (vollstaendig)\n\n';
envContent += '```dotenv\n';
if (fs.existsSync(ENV_SYSTEMD)) {
  try {
    envContent += fs.readFileSync(ENV_SYSTEMD, 'utf8') + '\n';
  } catch (e) {
    envContent += '# Fehler beim Lesen\n';
  }
} else {
  envContent += '# gateway.systemd.env fehlt\n';
}
envContent += '```';

fs.writeFileSync(ENV_FILE, envContent);

const runContent = `# Laufprotokoll Gateway A / Node 1

- Zeit (lokal): ${NOW_LOCAL}
- Zeit (UTC): ${NOW_UTC}
- Script: ${process.argv[1]}

## Erzeugte Dateien

- ${path.basename(IST_FILE)}
- ${path.basename(INV_FILE)}
- ${path.basename(CFG_FILE)}
- ${path.basename(ENV_FILE)}`;

fs.writeFileSync(RUN_FILE, runContent);

console.log('OK: IST-Zustand erfasst.');
try {
  const files = fs.readdirSync(OUT_DIR);
  files.forEach(file => console.log(`- ${file}`));
} catch (e) {
  console.log('- (keine Dateien aufgelistet)');
}
