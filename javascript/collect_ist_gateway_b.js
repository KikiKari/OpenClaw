#!/usr/bin/env node
// collect_ist_gateway_b.sh — portiert nach javascript
// Quelle: shell, OpenClaw@gateway2:scripts/collect_ist_gateway_b.sh
// Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

import fs from 'fs';
import os from 'os';
import path from 'path';
import { execSync } from 'child_process';

const BASE_DIR = path.join(os.homedir(), '.openclaw');
const OUT_DIR = path.join(BASE_DIR, 'workspace', 'vscode');
const NOW_UTC = new Date().toISOString().replace(/\.\d+Z$/, 'Z');
const NOW_LOCAL = new Date().toLocaleString('de-DE') + ' ' + Intl.DateTimeFormat().resolvedOptions().timeZone;
const TS = new Date().toISOString().replace(/[-:]/g, '').replace('T', '-').slice(0, 15);

fs.mkdirSync(OUT_DIR, { recursive: true });

const IST_FILE = path.join(OUT_DIR, 'IST-ZUSTAND_GATEWAY-B_NODE7.md');
const INV_FILE = path.join(OUT_DIR, 'ARTEFAKT-INVENTAR_GATEWAY-B_NODE7.md');
const CFG_FILE = path.join(OUT_DIR, 'OPENCLAW-CONFIG-SNAPSHOT_GATEWAY-B_NODE7.md');
const ENV_FILE = path.join(OUT_DIR, 'ENV-STATUS_GATEWAY-B_NODE7.md');
const RUN_FILE = path.join(OUT_DIR, `RUN-${TS}.md`);

const OPENCLAW_JSON = path.join(BASE_DIR, 'openclaw.json');
const ENV_DOT = path.join(BASE_DIR, '.env');
const ENV_SYSTEMD = path.join(BASE_DIR, 'gateway.systemd.env');
const VSCODE_DIR = path.join(BASE_DIR, '.vscode');

let HOSTNAME_FQDN = '';
try {
  HOSTNAME_FQDN = execSync('hostname -f', { encoding: 'utf8' }).trim();
} catch {
  HOSTNAME_FQDN = os.hostname();
}
const HOSTNAME_SHORT = os.hostname();
const ARCH = process.arch;
const KERNEL = os.release();
let OS_PRETTY = '';
try {
  const osRelease = fs.readFileSync('/etc/os-release', 'utf8');
  const match = osRelease.match(/^PRETTY_NAME=(.*)$/m);
  OS_PRETTY = match ? match[1].replace(/"/g, '') : '';
} catch {}
let IPV4_ALL = '';
try {
  IPV4_ALL = execSync('hostname -I', { encoding: 'utf8' }).trim().split(/\s+/).join(', ');
} catch {}
let PUBLIC_IP = '';
try {
  PUBLIC_IP = execSync('curl -4 -s --max-time 4 ifconfig.me', { encoding: 'utf8' }).trim();
} catch {}
let TAILSCALE_IP = '';
try {
  TAILSCALE_IP = execSync('tailscale ip -4', { encoding: 'utf8' }).trim().split('\n')[0];
} catch {}
let OPENCLAW_VER = '';
try {
  OPENCLAW_VER = execSync('openclaw --version', { encoding: 'utf8' }).trim();
} catch {}
let NODE_VER = '';
try {
  NODE_VER = execSync('node -v', { encoding: 'utf8' }).trim();
} catch {}

if (!PUBLIC_IP) PUBLIC_IP = '(nicht ermittelt)';
if (!TAILSCALE_IP) TAILSCALE_IP = '(nicht ermittelt)';
if (!OPENCLAW_VER) OPENCLAW_VER = '(nicht ermittelt)';
if (!NODE_VER) NODE_VER = '(nicht ermittelt)';

const istContent = `# IST-Zustand: Gateway B / Node 7

Stand (lokal): ${NOW_LOCAL}  
Stand (UTC): ${NOW_UTC}

## 1) Identität & System

- Gateway: **B**
- Node: **7**
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
- \`${path.join(BASE_DIR, 'plugins', 'installs.json')}\`: ${fs.existsSync(path.join(BASE_DIR, 'plugins', 'installs.json')) ? 'vorhanden' : 'fehlt'}
- \`${path.join(BASE_DIR, 'plugin-skills')}\`: ${fs.existsSync(path.join(BASE_DIR, 'plugin-skills')) ? 'vorhanden' : 'fehlt'}

## 4) Hinweis

Diese Datei wird bei jedem Lauf neu geschrieben.
Zusätzlich wird ein Laufprotokoll als \`RUN-*.md\` erzeugt.`;

fs.writeFileSync(IST_FILE, istContent);

let invContent = `# Artefakt-Inventar: Gateway B / Node 7

Stand: ${NOW_LOCAL}

## Top-Level in ~/.openclaw

\`\`\`text
`;
try {
  const files = fs.readdirSync(BASE_DIR);
  invContent += files.join('\n');
} catch {}
invContent += `
\`\`\`

## ~/.openclaw/.vscode

\`\`\`text
`;
if (fs.existsSync(VSCODE_DIR)) {
  try {
    const stats = fs.readdirSync(VSCODE_DIR);
    invContent += stats.map(f => {
      const stat = fs.statSync(path.join(VSCODE_DIR, f));
      return `${stat.isDirectory() ? 'd' : '-'} ${f}`;
    }).join('\n');
  } catch {}
} else {
  invContent += '(nicht vorhanden)';
}
invContent += `
\`\`\`

## plugin-skills/

\`\`\`text
`;
if (fs.existsSync(path.join(BASE_DIR, 'plugin-skills'))) {
  try {
    const files = fs.readdirSync(path.join(BASE_DIR, 'plugin-skills'));
    invContent += files.join('\n');
  } catch {}
} else {
  invContent += '(nicht vorhanden)';
}
invContent += `
\`\`\`

## openclaw.json Backups

\`\`\`text
`;
try {
  const files = fs.readdirSync(BASE_DIR).filter(f => f.startsWith('openclaw.json.bak'));
  invContent += files.length > 0 ? files.join('\n') : '(keine gefunden)';
} catch {
  invContent += '(keine gefunden)';
}
invContent += `
\`\`\``;

fs.writeFileSync(INV_FILE, invContent);

let cfgContent = `# OpenClaw Config Snapshot: Gateway B / Node 7

Stand: ${NOW_LOCAL}

## Schlüsselpositionen (grep)

\`\`\`text
`;
if (fs.existsSync(OPENCLAW_JSON)) {
  try {
    const content = fs.readFileSync(OPENCLAW_JSON, 'utf8');
    const lines = content.split('\n');
    lines.forEach((line, index) => {
      if (line.match(/"gateway"|\"session\"|\"dmScope\"|\"auth\"|\"secrets\"|\"tools\"|\"plugins\"|\"profile\"|\"alsoAllow\"|\"denyCommands\"/)) {
        cfgContent += `${index + 1}: ${line}\n`;
      }
    });
  } catch {}
} else {
  cfgContent += 'openclaw.json fehlt';
}
cfgContent += `
\`\`\`

## Ausschnitt gateway/session/auth (ungefiltert, betriebsnah)

\`\`\`json
`;
if (fs.existsSync(OPENCLAW_JSON)) {
  try {
    const content = fs.readFileSync(OPENCLAW_JSON, 'utf8');
    const lines = content.split('\n');
    const start = 579;
    const end = 779;
    for (let i = start; i <= Math.min(end, lines.length - 1); i++) {
      cfgContent += lines[i] + '\n';
    }
  } catch {}
} else {
  cfgContent += '{ "error": "openclaw.json fehlt" }';
}
cfgContent += `
\`\`\``;

fs.writeFileSync(CFG_FILE, cfgContent);

let envContent = `# ENV-Status: Gateway B / Node 7

Stand: ${NOW_LOCAL}

## Dateien

\`\`\`text
`;
try {
  const envStat = fs.statSync(ENV_DOT);
  const systemdStat = fs.statSync(ENV_SYSTEMD);
  envContent += `${envStat.mode.toString(8)} ${ENV_DOT}\n`;
  envContent += `${systemdStat.mode.toString(8)} ${ENV_SYSTEMD}\n`;
} catch {}
envContent += `
\`\`\`

## .env (vollständig, ungefiltert)

\`\`\`dotenv
`;
if (fs.existsSync(ENV_DOT)) {
  envContent += fs.readFileSync(ENV_DOT, 'utf8');
} else {
  envContent += '# .env fehlt';
}
envContent += `
\`\`\`

## gateway.systemd.env (vollständig, ungefiltert)

\`\`\`dotenv
`;
if (fs.existsSync(ENV_SYSTEMD)) {
  envContent += fs.readFileSync(ENV_SYSTEMD, 'utf8');
} else {
  envContent += '# gateway.systemd.env fehlt';
}
envContent += `
\`\`\``;

fs.writeFileSync(ENV_FILE, envContent);

const runContent = `# Laufprotokoll Gateway B / Node 7

- Zeit (lokal): ${NOW_LOCAL}
- Zeit (UTC): ${NOW_UTC}
- Script: ${process.argv[1]}

## Erzeugte Dateien

- ${path.basename(IST_FILE)}
- ${path.basename(INV_FILE)}
- ${path.basename(CFG_FILE)}
- ${path.basename(ENV_FILE)}
`;

fs.writeFileSync(RUN_FILE, runContent);

console.log('OK: IST-Zustand erfasst.');
console.log(`Ausgabeordner: ${OUT_DIR}`);
console.log('Dateien:');
try {
  const files = fs.readdirSync(OUT_DIR);
  files.forEach(file => console.log(`- ${file}`));
} catch {}
