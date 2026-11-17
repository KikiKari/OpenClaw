#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "3fd7a2aa0ea1c630df3cc984b63f1846153a3ddf9b3e855eba9446dd96fcd5ce", "source_sha256": "da890cc26fb848b78b6a85373d6cfa4e08f6e7c2002921e1c0247960b8b361d7", "target_language": "javascript"}
// collect_ist_gateway_b.sh — portiert nach javascript
// Quelle: shell, OpenClaw@gateway2:scripts/collect_ist_gateway_b.sh
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

import { promises as fs } from 'fs';
import { execSync } from 'child_process';
import os from 'os';
import path from 'path';
import { fileURLToPath } from 'url';
import process from 'process';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const BASE_DIR = path.join(os.homedir(), '.openclaw');
const OUT_DIR = path.join(BASE_DIR, 'workspace', 'vscode');

const now = new Date();
const NOW_UTC = now.toISOString().replace(/\.\d+Z$/, 'Z');
const NOW_LOCAL = now.toLocaleString('de-DE') + ' ' + Intl.DateTimeFormat('de-DE', { timeZoneName: 'short' }).formatToParts(now).find(part => part.type === 'timeZoneName').value;
const TS = now.toISOString().replace(/[-:]/g, '').replace('T', '-').substring(0, 15);

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
} catch (error) {
  HOSTNAME_FQDN = os.hostname();
}

const HOSTNAME_SHORT = os.hostname();
const ARCH = process.arch;
const KERNEL = os.release();
let OS_PRETTY = '';
try {
  const osRelease = await fs.readFile('/etc/os-release', 'utf8');
  const match = osRelease.match(/^PRETTY_NAME=(.*)$/m);
  if (match) {
    OS_PRETTY = match[1].replace(/"/g, '');
  }
} catch (error) {
  OS_PRETTY = '(nicht ermittelt)';
}

const IPV4_ALL = Object.values(os.networkInterfaces())
  .flat()
  .filter(iface => !iface.internal && iface.family === 'IPv4')
  .map(iface => iface.address)
  .join(' ');

let PUBLIC_IP = '';
try {
  PUBLIC_IP = execSync('curl -4 -s --max-time 4 ifconfig.me', { encoding: 'utf8' }).trim();
} catch (error) {
  PUBLIC_IP = '(nicht ermittelt)';
}

let TAILSCALE_IP = '';
try {
  TAILSCALE_IP = execSync('tailscale ip -4', { encoding: 'utf8' }).split('\n')[0];
} catch (error) {
  TAILSCALE_IP = '(nicht ermittelt)';
}

let OPENCLAW_VER = '';
try {
  OPENCLAW_VER = execSync('openclaw --version', { encoding: 'utf8' }).trim();
} catch (error) {
  OPENCLAW_VER = '(nicht ermittelt)';
}

let NODE_VER = '';
try {
  NODE_VER = execSync('node -v', { encoding: 'utf8' }).trim();
} catch (error) {
  NODE_VER = '(nicht ermittelt)';
}

await fs.mkdir(OUT_DIR, { recursive: true });

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

- \`${OPENCLAW_JSON}\`: ${await fs.access(OPENCLAW_JSON).then(() => 'vorhanden').catch(() => 'fehlt')}
- \`${ENV_DOT}\`: ${await fs.access(ENV_DOT).then(() => 'vorhanden').catch(() => 'fehlt')}
- \`${ENV_SYSTEMD}\`: ${await fs.access(ENV_SYSTEMD).then(() => 'vorhanden').catch(() => 'fehlt')}
- \`${path.join(BASE_DIR, 'plugins', 'installs.json')}\`: ${await fs.access(path.join(BASE_DIR, 'plugins', 'installs.json')).then(() => 'vorhanden').catch(() => 'fehlt')}
- \`${path.join(BASE_DIR, 'plugin-skills')}\`: ${await fs.access(path.join(BASE_DIR, 'plugin-skills')).then(() => 'vorhanden').catch(() => 'fehlt')}

## 4) Hinweis

Diese Datei wird bei jedem Lauf neu geschrieben.
Zusätzlich wird ein Laufprotokoll als \`RUN-*.md\` erzeugt.`;

await fs.writeFile(IST_FILE, istContent);

let invContent = `# Artefakt-Inventar: Gateway B / Node 7

Stand: ${NOW_LOCAL}

## Top-Level in ~/.openclaw

\`\`\`text
`;
try {
  const files = await fs.readdir(BASE_DIR);
  invContent += files.join('\n');
} catch (error) {
  invContent += '(nicht ermittelt)';
}
invContent += `
\`\`\`

## ~/.openclaw/.vscode

\`\`\`text
`;

try {
  const stats = await fs.stat(VSCODE_DIR);
  if (stats.isDirectory()) {
    const files = await fs.readdir(VSCODE_DIR);
    for (const file of files) {
      const filePath = path.join(VSCODE_DIR, file);
      const stat = await fs.stat(filePath);
      invContent += `${stat.mode.toString(8).padStart(6)} ${stat.size.toString().padStart(8)} ${file}\n`;
    }
  } else {
    invContent += '(nicht vorhanden)';
  }
} catch (error) {
  invContent += '(nicht vorhanden)';
}

invContent += `
\`\`\`

## plugin-skills/

\`\`\`text
`;

try {
  const stats = await fs.stat(path.join(BASE_DIR, 'plugin-skills'));
  if (stats.isDirectory()) {
    const files = await fs.readdir(path.join(BASE_DIR, 'plugin-skills'));
    invContent += files.join('\n');
  } else {
    invContent += '(nicht vorhanden)';
  }
} catch (error) {
  invContent += '(nicht vorhanden)';
}

invContent += `
\`\`\`

## openclaw.json Backups

\`\`\`text
`;

try {
  const files = await fs.readdir(BASE_DIR);
  const backupFiles = files.filter(file => file.startsWith('openclaw.json.bak'));
  if (backupFiles.length > 0) {
    invContent += backupFiles.join('\n');
  } else {
    invContent += '(keine gefunden)';
  }
} catch (error) {
  invContent += '(keine gefunden)';
}

invContent += `
\`\`\``;

await fs.writeFile(INV_FILE, invContent);

let cfgContent = `# OpenClaw Config Snapshot: Gateway B / Node 7

Stand: ${NOW_LOCAL}

## Schlüsselpositionen (grep)

\`\`\`text
`;

try {
  const content = await fs.readFile(OPENCLAW_JSON, 'utf8');
  const lines = content.split('\n');
  lines.forEach((line, index) => {
    if (/"gateway"|\"session\"|\"dmScope\"|\"auth\"|\"secrets\"|\"tools\"|\"plugins\"|\"profile\"|\"alsoAllow\"|\"denyCommands\"/.test(line)) {
      cfgContent += `${index + 1}: ${line}\n`;
    }
  });
} catch (error) {
  cfgContent += 'openclaw.json fehlt\n';
}

cfgContent += `\`\`\`

## Ausschnitt gateway/session/auth (ungefiltert, betriebsnah)

\`\`\`json
`;

try {
  const content = await fs.readFile(OPENCLAW_JSON, 'utf8');
  const lines = content.split('\n');
  const start = Math.max(0, 580 - 1);
  const end = Math.min(lines.length, 780);
  cfgContent += lines.slice(start, end).join('\n');
} catch (error) {
  cfgContent += '{ "error": "openclaw.json fehlt" }\n';
}

cfgContent += `\`\`\``;

await fs.writeFile(CFG_FILE, cfgContent);

let envContent = `# ENV-Status: Gateway B / Node 7

Stand: ${NOW_LOCAL}

## Dateien

\`\`\`text
`;

try {
  const envDotStat = await fs.stat(ENV_DOT);
  const envSystemdStat = await fs.stat(ENV_SYSTEMD);
  envContent += `-rw-r--r-- ${envDotStat.size.toString().padStart(8)} ${(new Date(envDotStat.mtime)).toISOString().split('T')[0]} ${path.basename(ENV_DOT)}\n`;
  envContent += `-rw-r--r-- ${envSystemdStat.size.toString().padStart(8)} ${(new Date(envSystemdStat.mtime)).toISOString().split('T')[0]} ${path.basename(ENV_SYSTEMD)}\n`;
} catch (error) {
  // ignore
}

envContent += `\`\`\`

## .env (vollständig, ungefiltert)

\`\`\`dotenv
`;

try {
  const content = await fs.readFile(ENV_DOT, 'utf8');
  envContent += content;
} catch (error) {
  envContent += '# .env fehlt\n';
}

envContent += `\`\`\`

## gateway.systemd.env (vollständig, ungefiltert)

\`\`\`dotenv
`;

try {
  const content = await fs.readFile(ENV_SYSTEMD, 'utf8');
  envContent += content;
} catch (error) {
  envContent += '# gateway.systemd.env fehlt\n';
}

envContent += `\`\`\``;

await fs.writeFile(ENV_FILE, envContent);

const runContent = `# Laufprotokoll Gateway B / Node 7

- Zeit (lokal): ${NOW_LOCAL}
- Zeit (UTC): ${NOW_UTC}
- Script: ${__filename}

## Erzeugte Dateien

- ${path.basename(IST_FILE)}
- ${path.basename(INV_FILE)}
- ${path.basename(CFG_FILE)}
- ${path.basename(ENV_FILE)}
`;

await fs.writeFile(RUN_FILE, runContent);

console.log('OK: IST-Zustand erfasst.');
console.log(`Ausgabeordner: ${OUT_DIR}`);
console.log('Dateien:');
try {
  const files = await fs.readdir(OUT_DIR);
  files.forEach(file => console.log(`- ${file}`));
} catch (error) {
  console.error('Fehler beim Lesen des Ausgabeordners:', error.message);
}
