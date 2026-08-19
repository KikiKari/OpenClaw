#!/usr/bin/env node
// collect_ist_gateway_b.sh — portiert nach javascript
// Quelle: shell, OpenClaw@gateway2:scripts/collect_ist_gateway_b.sh
// Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

const fs = require('fs');
const os = require('os');
const path = require('path');
const { execSync } = require('child_process');

const BASE_DIR = path.join(os.homedir(), '.openclaw');
const OUT_DIR = path.join(BASE_DIR, 'workspace', 'vscode');

// Create output directory
fs.mkdirSync(OUT_DIR, { recursive: true });

// Get current time
const now = new Date();
const NOW_UTC = now.toISOString().replace(/\.\d+Z$/, 'Z');
const NOW_LOCAL = now.toLocaleString('de-DE', { timeZoneName: 'short' });
const TS = now.toISOString().replace(/[-:]/g, '').replace('T', '-').substring(0, 15);

// File paths
const IST_FILE = path.join(OUT_DIR, 'IST-ZUSTAND_GATEWAY-B_NODE7.md');
const INV_FILE = path.join(OUT_DIR, 'ARTEFAKT-INVENTAR_GATEWAY-B_NODE7.md');
const CFG_FILE = path.join(OUT_DIR, 'OPENCLAW-CONFIG-SNAPSHOT_GATEWAY-B_NODE7.md');
const ENV_FILE = path.join(OUT_DIR, 'ENV-STATUS_GATEWAY-B_NODE7.md');
const RUN_FILE = path.join(OUT_DIR, `RUN-${TS}.md`);

const OPENCLAW_JSON = path.join(BASE_DIR, 'openclaw.json');
const ENV_DOT = path.join(BASE_DIR, '.env');
const ENV_SYSTEMD = path.join(BASE_DIR, 'gateway.systemd.env');
const VSCODE_DIR = path.join(BASE_DIR, '.vscode');

// System information
let HOSTNAME_FQDN;
try {
  HOSTNAME_FQDN = execSync('hostname -f', { encoding: 'utf8' }).trim();
} catch (error) {
  HOSTNAME_FQDN = os.hostname();
}

const HOSTNAME_SHORT = os.hostname();
const ARCH = os.arch();
const KERNEL = os.release();

let OS_PRETTY = '';
try {
  const osRelease = fs.readFileSync('/etc/os-release', 'utf8');
  const match = osRelease.match(/^PRETTY_NAME=(.*)$/m);
  if (match) {
    OS_PRETTY = match[1].replace(/"/g, '');
  }
} catch (error) {
  // Ignore error
}

let IPV4_ALL = '';
try {
  IPV4_ALL = execSync('hostname -I', { encoding: 'utf8' }).trim().split(/\s+/).join(', ');
} catch (error) {
  // Ignore error
}

let PUBLIC_IP = '';
try {
  PUBLIC_IP = execSync('curl -4 -s --max-time 4 ifconfig.me', { encoding: 'utf8' }).trim();
} catch (error) {
  // Ignore error
}

let TAILSCALE_IP = '';
try {
  TAILSCALE_IP = execSync('tailscale ip -4', { encoding: 'utf8' }).trim().split('\n')[0];
} catch (error) {
  // Ignore error
}

let OPENCLAW_VER = '';
try {
  OPENCLAW_VER = execSync('openclaw --version', { encoding: 'utf8' }).trim();
} catch (error) {
  // Ignore error
}

let NODE_VER = '';
try {
  NODE_VER = process.version;
} catch (error) {
  // Ignore error
}

// Set default values if empty
if (!PUBLIC_IP) PUBLIC_IP = '(nicht ermittelt)';
if (!TAILSCALE_IP) TAILSCALE_IP = '(nicht ermittelt)';
if (!OPENCLAW_VER) OPENCLAW_VER = '(nicht ermittelt)';
if (!NODE_VER) NODE_VER = '(nicht ermittelt)';

// IST-Zustand file content
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
- \`${path.join(BASE_DIR, 'plugins/installs.json')}\`: ${fs.existsSync(path.join(BASE_DIR, 'plugins/installs.json')) ? 'vorhanden' : 'fehlt'}
- \`${path.join(BASE_DIR, 'plugin-skills')}\`: ${fs.existsSync(path.join(BASE_DIR, 'plugin-skills')) ? 'vorhanden' : 'fehlt'}

## 4) Hinweis

Diese Datei wird bei jedem Lauf neu geschrieben.
Zusätzlich wird ein Laufprotokoll als \`RUN-*.md\` erzeugt.`;

fs.writeFileSync(IST_FILE, istContent);

// Artefakt-Inventar file content
let invContent = `# Artefakt-Inventar: Gateway B / Node 7

Stand: ${NOW_LOCAL}

## Top-Level in ~/.openclaw

\`\`\`text
`;

try {
  const baseDirItems = fs.readdirSync(BASE_DIR);
  invContent += baseDirItems.join('\n');
} catch (error) {
  // Ignore error
}

invContent += `
\`\`\`

## ~/.openclaw/.vscode

\`\`\`text
`;

if (fs.existsSync(VSCODE_DIR)) {
  try {
    const vscodeItems = fs.readdirSync(VSCODE_DIR);
    invContent += vscodeItems.map(item => {
      const stat = fs.statSync(path.join(VSCODE_DIR, item));
      return `${stat.isDirectory() ? 'd' : '-'}${stat.mode.toString(8).padStart(6, '0')} ${stat.size} ${item}`;
    }).join('\n');
  } catch (error) {
    // Ignore error
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
    const pluginSkillsItems = fs.readdirSync(path.join(BASE_DIR, 'plugin-skills'));
    invContent += pluginSkillsItems.join('\n');
  } catch (error) {
    // Ignore error
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
  const backupFiles = fs.readdirSync(BASE_DIR).filter(file => file.startsWith('openclaw.json.bak'));
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

fs.writeFileSync(INV_FILE, invContent);

// OpenClaw Config Snapshot file content
let cfgContent = `# OpenClaw Config Snapshot: Gateway B / Node 7

Stand: ${NOW_LOCAL}

## Schlüsselpositionen (grep)

\`\`\`text
`;

if (fs.existsSync(OPENCLAW_JSON)) {
  try {
    const openclawJsonContent = fs.readFileSync(OPENCLAW_JSON, 'utf8');
    const lines = openclawJsonContent.split('\n');
    lines.forEach((line, index) => {
      if (line.match(/"gateway"|\"session\"|\"dmScope\"|\"auth\"|\"secrets\"|\"tools\"|\"plugins\"|\"profile\"|\"alsoAllow\"|\"denyCommands\"/)) {
        cfgContent += `${index + 1}: ${line}\n`;
      }
    });
  } catch (error) {
    // Ignore error
  }
} else {
  cfgContent += 'openclaw.json fehlt\n';
}

cfgContent += `\`\`\`

## Ausschnitt gateway/session/auth (ungefiltert, betriebsnah)

\`\`\`json
`;

if (fs.existsSync(OPENCLAW_JSON)) {
  try {
    const openclawJsonContent = fs.readFileSync(OPENCLAW_JSON, 'utf8');
    const lines = openclawJsonContent.split('\n');
    const startLine = 579; // 0-based index for line 580
    const endLine = 779;   // 0-based index for line 780
    const snippet = lines.slice(startLine, endLine + 1).join('\n');
    cfgContent += snippet;
  } catch (error) {
    cfgContent += '{ "error": "Fehler beim Lesen von openclaw.json" }\n';
  }
} else {
  cfgContent += '{ "error": "openclaw.json fehlt" }\n';
}

cfgContent += `
\`\`\``;

fs.writeFileSync(CFG_FILE, cfgContent);

// ENV-Status file content
let envContent = `# ENV-Status: Gateway B / Node 7

Stand: ${NOW_LOCAL}

## Dateien

\`\`\`text
`;

try {
  [ENV_DOT, ENV_SYSTEMD].forEach(envFile => {
    if (fs.existsSync(envFile)) {
      const stat = fs.statSync(envFile);
      envContent += `${stat.isDirectory() ? 'd' : '-'}${stat.mode.toString(8).padStart(6, '0')} ${stat.size} ${envFile}\n`;
    }
  });
} catch (error) {
  // Ignore error
}

envContent += `\`\`\`

## .env (vollständig, ungefiltert)

\`\`\`dotenv
`;

if (fs.existsSync(ENV_DOT)) {
  try {
    envContent += fs.readFileSync(ENV_DOT, 'utf8');
  } catch (error) {
    envContent += '# Fehler beim Lesen von .env\n';
  }
} else {
  envContent += '# .env fehlt\n';
}

envContent += `\`\`\`

## gateway.systemd.env (vollständig, ungefiltert)

\`\`\`dotenv
`;

if (fs.existsSync(ENV_SYSTEMD)) {
  try {
    envContent += fs.readFileSync(ENV_SYSTEMD, 'utf8');
  } catch (error) {
    envContent += '# Fehler beim Lesen von gateway.systemd.env\n';
  }
} else {
  envContent += '# gateway.systemd.env fehlt\n';
}

envContent += `\`\`\``;

fs.writeFileSync(ENV_FILE, envContent);

// Run protocol file content
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

fs.writeFileSync(RUN_FILE, runContent);

// Output success message
console.log('OK: IST-Zustand erfasst.');
console.log(`Ausgabeordner: ${OUT_DIR}`);
console.log('Dateien:');
try {
  const files = fs.readdirSync(OUT_DIR);
  files.forEach(file => console.log(`- ${file}`));
} catch (error) {
  // Ignore error
}
