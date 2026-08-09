#!/usr/bin/env node
// collect_ist_gateway_a.sh — portiert nach javascript
// Quelle: shell, OpenClaw@gateway1:scripts/collect_ist_gateway_a.sh
// Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

const fs = require('fs');
const os = require('os');
const path = require('path');
const { execSync } = require('child_process');

const BASE_DIR = path.join(os.homedir(), '.openclaw');
const OUT_DIR = path.join(BASE_DIR, 'workspace', 'vscode');

const now = new Date();
const NOW_UTC = now.toISOString().replace(/\.\d+Z$/, 'Z');
const NOW_LOCAL = now.toLocaleString('de-DE') + ' ' + Intl.DateTimeFormat().resolvedOptions().timeZone;
const TS = now.toISOString().replace(/[-:]/g, '').replace('T', '-').substring(0, 15);

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

let HOSTNAME_FQDN = 'nicht ermittelbar';
try {
  HOSTNAME_FQDN = execSync('hostname -f', { encoding: 'utf8' }).trim();
} catch {
  HOSTNAME_FQDN = os.hostname();
}

const HOSTNAME_SHORT = os.hostname();
const ARCH = process.arch;
const KERNEL = os.release();
let OS_PRETTY = 'nicht ermittelbar';
try {
  const osRelease = fs.readFileSync('/etc/os-release', 'utf8');
  const match = osRelease.match(/^PRETTY_NAME=(.*)$/m);
  if (match) OS_PRETTY = match[1].replace(/"/g, '');
} catch {}

let IPV4_ALL = 'nicht ermittelbar';
try {
  IPV4_ALL = Object.values(os.networkInterfaces())
    .flat()
    .filter(iface => iface.family === 'IPv4' && !iface.internal)
    .map(iface => iface.address)
    .join(' ');
} catch {}

let PUBLIC_IP = 'nicht ermittelt';
try {
  PUBLIC_IP = execSync('curl -4 -s --max-time 4 ifconfig.me', { encoding: 'utf8', timeout: 4000 }).trim();
} catch {}

let TAILSCALE_IP = 'nicht ermittelt';
try {
  TAILSCALE_IP = execSync('tailscale ip -4', { encoding: 'utf8' }).split('\n')[0].trim();
} catch {}

let OPENCLAW_VER = 'nicht ermittelt';
try {
  OPENCLAW_VER = execSync('openclaw --version', { encoding: 'utf8' }).trim();
} catch {}

let NODE_VER = 'nicht ermittelt';
try {
  NODE_VER = process.version;
} catch {}

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
- \`${BASE_DIR}/plugins/installs.json\`: ${fs.existsSync(path.join(BASE_DIR, 'plugins', 'installs.json')) ? 'vorhanden' : 'fehlt'}
- \`${BASE_DIR}/plugin-skills\`: ${fs.existsSync(path.join(BASE_DIR, 'plugin-skills')) ? 'vorhanden' : 'fehlt'}`;

fs.writeFileSync(IST_FILE, istContent);

let invContent = `# Artefakt-Inventar: Gateway A / Node 1

Stand: ${NOW_LOCAL}

## Top-Level in ~/.openclaw

\`\`\`text
`;
try {
  invContent += fs.readdirSync(BASE_DIR).join('\n');
} catch {
  invContent += 'Fehler beim Lesen des Verzeichnisses';
}
invContent += `
\`\`\`

## ~/.openclaw/.vscode

\`\`\`text
`;
if (fs.existsSync(VSCODE_DIR)) {
  try {
    const files = fs.readdirSync(VSCODE_DIR);
    const stats = files.map(file => {
      const stat = fs.statSync(path.join(VSCODE_DIR, file));
      return `${stat.isDirectory() ? 'd' : '-'}${stat.mode.toString(8).slice(-3)} ${stat.size} ${file}`;
    });
    invContent += stats.join('\n');
  } catch {
    invContent += 'Fehler beim Lesen des Verzeichnisses';
  }
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
    invContent += fs.readdirSync(path.join(BASE_DIR, 'plugin-skills')).join('\n');
  } catch {
    invContent += 'Fehler beim Lesen des Verzeichnisses';
  }
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

let cfgContent = `# OpenClaw Config Snapshot: Gateway A / Node 1

Stand: ${NOW_LOCAL}

## Schluesselpositionen (grep)

\`\`\`text
`;
if (fs.existsSync(OPENCLAW_JSON)) {
  try {
    const content = fs.readFileSync(OPENCLAW_JSON, 'utf8');
    const lines = content.split('\n');
    lines.forEach((line, index) => {
      if (/"gateway"|\"session\"|\"dmScope\"|\"auth\"|\"secrets\"|\"tools\"|\"plugins\"|\"profile\"|\"alsoAllow\"|\"denyCommands\"/.test(line)) {
        cfgContent += `${index + 1}: ${line}\n`;
      }
    });
  } catch {
    cfgContent += 'Fehler beim Lesen der Datei\n';
  }
} else {
  cfgContent += 'openclaw.json fehlt\n';
}
cfgContent += '```\n\n## Ausschnitt gateway/session/auth\n\n```json\n';
if (fs.existsSync(OPENCLAW_JSON)) {
  try {
    const content = fs.readFileSync(OPENCLAW_JSON, 'utf8');
    const lines = content.split('\n');
    const start = 579;
    const end = 779;
    cfgContent += lines.slice(start, end + 1).join('\n');
  } catch {
    cfgContent += '{ "error": "Fehler beim Lesen der Datei" }';
  }
} else {
  cfgContent += '{ "error": "openclaw.json fehlt" }';
}
cfgContent += '\n```';

fs.writeFileSync(CFG_FILE, cfgContent);

let envContent = `# ENV-Status: Gateway A / Node 1

Stand: ${NOW_LOCAL}

## Dateien

\`\`\`text
`;
try {
  const envStat = fs.statSync(ENV_DOT);
  const systemdStat = fs.statSync(ENV_SYSTEMD);
  envContent += `-rwx------ 1 ${os.userInfo().username} ${os.userInfo().username} ${envStat.size} ${envStat.mtime.toLocaleString()} ${ENV_DOT}\n`;
  envContent += `-rwx------ 1 ${os.userInfo().username} ${os.userInfo().username} ${systemdStat.size} ${systemdStat.mtime.toLocaleString()} ${ENV_SYSTEMD}\n`;
} catch {
  envContent += 'Dateien nicht gefunden\n';
}
envContent += '```\n\n## .env (vollstaendig)\n\n```dotenv\n';
if (fs.existsSync(ENV_DOT)) {
  envContent += fs.readFileSync(ENV_DOT, 'utf8');
} else {
  envContent += '# .env fehlt';
}
envContent += '\n```\n\n## gateway.systemd.env (vollstaendig)\n\n```dotenv\n';
if (fs.existsSync(ENV_SYSTEMD)) {
  envContent += fs.readFileSync(ENV_SYSTEMD, 'utf8');
} else {
  envContent += '# gateway.systemd.env fehlt';
}
envContent += '\n```';

fs.writeFileSync(ENV_FILE, envContent);

const runContent = `# Laufprotokoll Gateway A / Node 1

- Zeit (lokal): ${NOW_LOCAL}
- Zeit (UTC): ${NOW_UTC}
- Script: ${__filename}

## Erzeugte Dateien

- ${path.basename(IST_FILE)}
- ${path.basename(INV_FILE)}
- ${path.basename(CFG_FILE)}
- ${path.basename(ENV_FILE)}`;

fs.writeFileSync(RUN_FILE, runContent);

console.log('OK: IST-Zustand erfasst.');
try {
  const files = fs.readdirSync(OUT_DIR);
  files.forEach(file => console.log('- ' + file));
} catch {
  console.log('- Fehler beim Auflisten der Dateien');
}
