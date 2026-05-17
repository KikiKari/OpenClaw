"use strict";

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// Pfade
const DASHBOARD_PATH = path.join(__dirname, '../dashboards/nodes-overview.md');

// Farbcodes für Konsole
const C = {
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  red: '\x1b[31m',
  blue: '\x1b[34m',
  reset: '\x1b[0m'
};

function getNodeStatus() {
  try {
    const output = execSync('openclaw nodes status --json', { encoding: 'utf-8' });
    return JSON.parse(output);
  } catch (err) {
    console.error(`${C.red}❌ Fehler beim Abrufen des Node-Status:${C.reset}`, err.message);
    return [];
  }
}

function updateDashboard(nodes) {
  const now = new Date().toLocaleString('de-DE', { timeZone: 'Europe/Berlin' });

  // Manuelle Ergänzung statischer Konfigurationen (da nicht alle Infos über CLI)
  const nodeConfig = {
    '1': { name: 'Gateway',       os: 'Ubuntu 22.04', ip: '152.53.145.65',   wg: '10.10.0.1', tunnel: '–', mode: 'Gateway' },
    '2': { name: 'Netcup Server', os: 'Ubuntu 22.04', ip: '78.46.123.10',  wg: '10.10.0.2', tunnel: '–', mode: 'Node' },
    '3': { name: 'xNetX VPS',     os: 'Debian 11',    ip: '5.45.105.20',   wg: '–',        tunnel: 'Port 18794', mode: 'Node' },
    '4': { name: 'Webhosting',    os: 'Shared Linux', ip: '–',              wg: '–',        tunnel: '–', mode: '–' },
    '5': { name: 'Redmi Note 11', os: 'Android',      ip: '–',              wg: '10.10.0.5', tunnel: '–', mode: 'Node' },
    '6': { name: 'Lenovo (Win)',  os: 'Windows 11',   ip: '–',              wg: '–',        tunnel: '–', mode: 'Node' }
  };

  let rows = [];
  for (let nodeId in nodeConfig) {
    const cfg = nodeConfig[nodeId];
    const node = nodes.find(n => n.nodeId === nodeId || n.name?.includes(cfg.name.split(' ')[0]));

    const statusVPN = node ? (node.status === 'paired' ? '✅' : '🔴') : '⚠️';
    const statusSSH = cfg.tunnel !== '–' ? '✅' : '❌';
    const sshKey = ['2', '3'].includes(nodeId) ? '❌ (Pending)' : (nodeId === '1' ? 'Local (id_ed25519)' : '❌');

    const lastCheck = node ? new Date(node.lastSeen * 1000).toLocaleString('de-DE') : '–';

    rows.push(`| ${nodeId}    | ${cfg.name} | ${cfg.os} | ${cfg.ip} | ${cfg.mode}       | ${cfg.wg}             | ${cfg.tunnel} | ${statusVPN} | ${statusSSH} | ${sshKey} | ${lastCheck} |`);
  }

  const content = `# Nodes Overview (Network Status)

| Node | Name          | OS           | IP             | Mode       | Primär WG IP       | Sekundär/SSH Tunnel | StatusVPN | StatusSSH | SSH Key (Deployed) | Letzter Check       |
|------|---------------|--------------|----------------|------------|--------------------|---------------------|-----------|-----------|---------------------|---------------------|
${rows.join('\n')}

> 💡 **Legende:** 
> - **Primär WG IP**: Die WireGuard-VPN-IP des Nodes
> - **Sekundär/SSH Tunnel**: Fallback-Mechanismus (z. B. Reverse-Tunnel)
> - **StatusVPN**: Verbunden über OpenClaw/WireGuard
> - **StatusSSH**: SSH-Zugriff via Reverse-Tunnel aktiv
> - **SSH Key (Deployed)**: Zeigt an, ob der Gateway-Schlüssel (\`id_ed25519\`) auf dem Ziel bereitgestellt ist
> - Letzter Stand: **${now} CET**

*Größe: ~1.8 KB | Automatisch aktualisiert via \`update-nodes-report.js\`*`;

  try {
    fs.writeFileSync(DASHBOARD_PATH, content, 'utf-8');
    console.log(`${C.green}✅ Dashboard aktualisiert:${C.reset} ${DASHBOARD_PATH}`);
  } catch (err) {
    console.error(`${C.red}❌ Fehler beim Schreiben der Datei:${C.reset}`, err.message);
  }
}

// Hauptausführung
console.log(`${C.blue}🔄 Aktualisiere Nodes-Übersicht...${C.reset}`);
const nodes = getNodeStatus();
updateDashboard(nodes);
