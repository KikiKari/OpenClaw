#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "98919aca654527335f0a50a1c6cafe8aa9ad410ab60492a70fef2643e3654ca1", "source_sha256": "0a86c190e36a7131252f54b73542b2e9f42f2b23547cdb5530f47c8477226123", "target_language": "javascript"}
// channel_status.py — portiert nach javascript
// Quelle: python, workspace@local:skills/channel-status-agent/scripts/channel_status.py
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

/**
 * Channel Status Agent - Automatische Status-Updates
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Konfiguration
const WORKSPACE = "/home/openclaw/.openclaw/workspace";
const LOGS_DB = path.join(WORKSPACE, "db/logs.db");
const CONFIG_FILE = path.join(WORKSPACE, "config/channel-status.json");
const LOG_FILE = path.join(WORKSPACE, "logs/channel-status.log");

function log(message, level = "INFO") {
    /** Logging */
    const timestamp = new Date().toISOString().replace('T', ' ').substring(0, 19);
    const entry = `[${timestamp}] [${level}] ${message}`;
    console.log(entry);
    fs.appendFileSync(LOG_FILE, entry + '\n');
}

const NODE_NAMES = {
    "node2": new Set(["openclaw-node2", "arm64-node", "v2202604104722449961", "v2202604104722449961.taild25fea.ts.net", "100.82.198.122"]),
    "node3": new Set(["openclaw-node3", "openclaw-node3.taild25fea.ts.net", "100.73.154.125"]),
    "node4": new Set(["openclaw-node4", "redmi-note-11s", "redmi-note-11s.taild25fea.ts.net", "100.94.134.39"]),
    "node5": new Set(["openclaw-node5"]),
    "node6": new Set(["openclaw-node6"]),
};

function fetchNodeStatus() {
    /** Return mapped OpenClaw connection states; null indicates lookup failure. */
    try {
        const result = execSync("openclaw nodes status --json", { timeout: 10000, encoding: 'utf8' });
        const payload = JSON.parse(result);
        if (typeof payload !== 'object' || !Array.isArray(payload.nodes)) {
            return null;
        }
        const states = {};
        Object.keys(NODE_NAMES).forEach(node => states[node] = false);
        for (const item of payload.nodes) {
            if (typeof item !== 'object') {
                continue;
            }
            const names = new Set([
                String(item.displayName || "").toLowerCase(),
                String(item.nodeId || "").toLowerCase(),
                String(item.remoteIp || "").toLowerCase()
            ]);
            for (const [node, aliases] of Object.entries(NODE_NAMES)) {
                if ([...names].some(name => aliases.has(name)) && item.connected === true) {
                    states[node] = true;
                }
            }
        }
        states.node1 = true; // successful Gateway status request
        return states;
    } catch (error) {
        return null;
    }
}

function getSystemStatus() {
    /** Sammelt System-Status */
    const status = {
        timestamp: new Date().toISOString(),
        nodes: {},
        agents: {},
        system: {}
    };
    
    // Verbindungslage aus der Gateway-Statusliste; keine statischen Online-Werte.
    const states = fetchNodeStatus();
    const names = {
        "node1": "Gateway",
        "node2": "Node2",
        "node3": "Node3",
        "node4": "Redmi",
        "node5": "Lenovo",
        "node6": "Lenovo (Docker)"
    };
    status.nodes = Object.fromEntries(
        Object.entries(names).map(([node, name]) => [
            node,
            {
                name: name,
                status: states === null ? "unknown" : states[node] ? "online" : "offline"
            }
        ])
    );

    // Agent-Status aus Cron
    try {
        const crontab = execSync('crontab -l', { encoding: 'utf8' });
        const cronLines = crontab.split('\n').filter(line => line.trim() && !line.startsWith('#')).length;
        status.agents.active_crons = cronLines;
    } catch (error) {
        status.agents.active_crons = "unknown";
    }
    
    // System-Metriken
    try {
        // Disk usage
        const dfOutput = execSync('df -h /', { encoding: 'utf8' });
        const dfLines = dfOutput.split('\n');
        for (const line of dfLines) {
            if (line.includes('/') && line.includes('%')) {
                const parts = line.split(/\s+/);
                status.system.disk_used = parts[4];
                break;
            }
        }
        
        // RAM usage
        const freeOutput = execSync('free -h', { encoding: 'utf8' });
        const freeLines = freeOutput.split('\n');
        for (const line of freeLines) {
            if (line.includes('Mem:')) {
                const parts = line.split(/\s+/);
                status.system.ram_total = parts[1];
                status.system.ram_used = parts[2];
                break;
            }
        }
    } catch (error) {
        // Ignore errors
    }
    
    return status;
}

function formatDailyStatus(status) {
    /** Formatiert täglichen Status */
    const nodes = status.nodes;
    const online = Object.values(nodes).filter(n => n.status === "online").length;
    
    let message = `📊 **Täglicher Status-Report**
🗓️ ${new Date().toLocaleString('de-DE', { year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit' })}

**🖥️ Nodes (${online}/${Object.keys(nodes).length} online):**
`;
    
    for (const [nodeId, info] of Object.entries(nodes)) {
        const emoji = info.status === "online" ? "🟢" : info.status === "offline" ? "🔴" : "🟡";
        message += `${emoji} ${info.name}: ${info.status}`;
        if (info.reason) {
            message += ` (${info.reason})`;
        }
        message += "\n";
    }
    
    message += `\n**🤖 Agents:**\n`;
    message += `Aktive Cron-Jobs: ${status.agents.active_crons}\n`;
    
    if (status.system.disk_used) {
        message += `\n**💾 System:**\n`;
        message += `Disk: ${status.system.disk_used} belegt\n`;
        message += `RAM: ${status.system.ram_used} / ${status.system.ram_total}\n`;
    }
    
    return message;
}

function formatWeeklyStatus(status) {
    /** Format the weekly report from current node data. */
    const lines = [
        "📈 **Wöchentlicher Report**",
        `📅 Woche ${new Date().toLocaleString('de-DE', { week: 'numeric', year: 'numeric' }).split(' ')[1]} - ${new Date().getFullYear()}`,
        "",
        "**Nodes:**"
    ];
    Object.values(status.nodes).forEach(item => lines.push(`- ${item.name}: ${item.status}`));
    return lines.join("\n") + "\n";
}

function sendToChannel(message, channelType = "telegram", channelId = "-1002381931352") {
    /** Sendet Nachricht an Channel */
    let cmd;
    if (channelType === "telegram") {
        // Nutze OpenClaw message tool
        cmd = `openclaw message send --target ${channelId} --message "${message.replace(/"/g, '\\"')}"`;
    } else {
        log(`Channel type ${channelType} not implemented`, "WARN");
        return false;
    }
    
    try {
        execSync(cmd, { stdio: 'pipe' });
        log(`Message sent to ${channelType} ${channelId}`);
        return true;
    } catch (error) {
        log(`Failed to send: ${error.message}`, "ERROR");
        return false;
    }
}

function main() {
    /** Hauptfunktion */
    const yargs = require('yargs/yargs');
    const { hideBin } = require('yargs/helpers');
    
    const argv = yargs(hideBin(process.argv))
        .usage('Usage: $0 --type <daily|weekly|alert> [options]')
        .option('type', {
            describe: 'Type of status update',
            choices: ['daily', 'weekly', 'alert'],
            demandOption: true
        })
        .option('message', {
            describe: 'Alert message',
            type: 'string'
        })
        .option('channel', {
            describe: 'Channel ID',
            default: '-1002381931352'
        })
        .option('dry-run', {
            describe: 'Show message without sending',
            type: 'boolean'
        })
        .help()
        .argv;
    
    log(`Starting ${argv.type} status update`);
    
    // Status sammeln
    const status = getSystemStatus();
    
    // Message formatieren
    let message;
    if (argv.type === 'daily') {
        message = formatDailyStatus(status);
    } else if (argv.type === 'weekly') {
        message = formatWeeklyStatus(status);
    } else if (argv.type === 'alert') {
        message = `🚨 **ALERT**\n${argv.message || 'Manual alert'}`;
    }
    
    // Senden oder Dry-Run
    if (argv.dryRun) {
        console.log("\n--- DRY RUN ---");
        console.log(message);
        console.log("--- END ---");
    } else {
        sendToChannel(message, "telegram", argv.channel);
    }
    
    log("Status update completed");
}

// Ensure log directory exists
const logDir = path.dirname(LOG_FILE);
if (!fs.existsSync(logDir)) {
    fs.mkdirSync(logDir, { recursive: true });
}

main();
