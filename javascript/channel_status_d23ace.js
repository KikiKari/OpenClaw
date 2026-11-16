#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "7dcb541cdf121a9753264dbdb77eb613e30398774a8715ee72818056473aec60", "source_sha256": "d23aced948e2cbccfa5bfa57ad3b48adfc5d5f7a42c2fbdf665f8c185b8545eb", "target_language": "javascript"}
// channel_status.py — portiert nach javascript
// Quelle: python, workspace@local:git/skills/channel-status-agent/scripts/channel_status.py
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

/**
 * Channel Status Agent - Automatische Status-Updates
 */

const fs = require('fs');
const path = require('path');
const { execSync, spawn } = require('child_process');

// Konfiguration
const WORKSPACE = path.join('/home/openclaw/.openclaw/workspace');
const LOGS_DB = path.join(WORKSPACE, 'db/logs.db');
const CONFIG_FILE = path.join(WORKSPACE, 'config/channel-status.json');
const LOG_FILE = path.join(WORKSPACE, 'logs/channel-status.log');

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
    "node5": new Set(["openclaw-node5", "lenovo-node7", "lenovo-node7.taild25fea.ts.net", "100.103.140.35"]),
};

function fetch_node_status() {
    /** Return mapped OpenClaw connection states; null indicates lookup failure. */
    try {
        const child = spawn('openclaw', ['nodes', 'status', '--json']);
        let stdout = '';
        let stderr = '';
        
        child.stdout.on('data', (data) => {
            stdout += data.toString();
        });
        
        child.stderr.on('data', (data) => {
            stderr += data.toString();
        });
        
        return new Promise((resolve, reject) => {
            child.on('close', (code) => {
                if (code !== 0) {
                    reject(new Error(`Command failed with code ${code}`));
                    return;
                }
                
                try {
                    const payload = JSON.parse(stdout);
                    if (typeof payload !== 'object' || !Array.isArray(payload.nodes)) {
                        resolve(null);
                        return;
                    }
                    
                    const states = {};
                    Object.keys(NODE_NAMES).forEach(node => {
                        states[node] = false;
                    });
                    
                    for (const item of payload.nodes) {
                        if (typeof item !== 'object') continue;
                        
                        const names = new Set([
                            String(item.displayName || "").toLowerCase(),
                            String(item.nodeId || "").toLowerCase(),
                            String(item.remoteIp || "").toLowerCase()
                        ]);
                        
                        for (const [node, aliases] of Object.entries(NODE_NAMES)) {
                            let found = false;
                            for (const alias of aliases) {
                                if (names.has(alias.toLowerCase())) {
                                    found = true;
                                    break;
                                }
                            }
                            if (found && item.connected === true) {
                                states[node] = true;
                            }
                        }
                    }
                    
                    states["node1"] = true; // successful Gateway status request
                    resolve(states);
                } catch (e) {
                    reject(e);
                }
            });
            
            setTimeout(() => {
                child.kill();
                reject(new Error('Timeout'));
            }, 10000);
        });
    } catch (error) {
        return Promise.resolve(null);
    }
}

async function get_system_status() {
    /** Sammelt System-Status */
    const status = {
        "timestamp": new Date().toISOString(),
        "nodes": {},
        "agents": {},
        "system": {}
    };
    
    // Verbindungslage aus der Gateway-Statusliste; keine statischen Online-Werte.
    const states = await fetch_node_status();
    const names = {
        "node1": "Gateway", 
        "node2": "Node2", 
        "node3": "Node3", 
        "node4": "Redmi", 
        "node5": "Lenovo"
    };
    
    status["nodes"] = {};
    for (const [node, name] of Object.entries(names)) {
        status["nodes"][node] = {
            "name": name, 
            "status": (states === null ? "unknown" : (states[node] ? "online" : "offline"))
        };
    }

    // Agent-Status aus Cron
    try {
        const result = execSync('crontab -l', { encoding: 'utf8' });
        const cronLines = result.split('\n').filter(line => line.trim() && !line.startsWith('#')).length;
        status["agents"]["active_crons"] = cronLines;
    } catch (e) {
        status["agents"]["active_crons"] = "unknown";
    }
    
    // System-Metriken
    try {
        // Disk usage
        const dfOutput = execSync('df -h /', { encoding: 'utf8' });
        const dfLines = dfOutput.split('\n');
        for (const line of dfLines) {
            if (line.includes('/') && line.includes('%')) {
                const parts = line.trim().split(/\s+/);
                if (parts.length >= 5) {
                    status["system"]["disk_used"] = parts[4];
                    break;
                }
            }
        }
        
        // RAM usage
        const freeOutput = execSync('free -h', { encoding: 'utf8' });
        const freeLines = freeOutput.split('\n');
        for (const line of freeLines) {
            if (line.includes('Mem:')) {
                const parts = line.trim().split(/\s+/);
                if (parts.length >= 3) {
                    status["system"]["ram_total"] = parts[1];
                    status["system"]["ram_used"] = parts[2];
                    break;
                }
            }
        }
    } catch (e) {
        // Ignore errors
    }
    
    return status;
}

function format_daily_status(status) {
    /** Formatiert täglichen Status */
    const nodes = status["nodes"];
    const online = Object.values(nodes).filter(n => n["status"] === "online").length;
    
    let message = `📊 **Täglicher Status-Report**
🗓️ ${new Date().toLocaleString('de-DE', { year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit' })}

**🖥️ Nodes (${online}/${Object.keys(nodes).length} online):**
`;
    
    for (const [node_id, info] of Object.entries(nodes)) {
        const emoji = info["status"] === "online" ? "🟢" : (info["status"] === "offline" ? "🔴" : "🟡");
        message += `${emoji} ${info['name']}: ${info['status']}`;
        if ("reason" in info) {
            message += ` (${info['reason']})`;
        }
        message += "\n";
    }
    
    message += `\n**🤖 Agents:**\n`;
    message += `Aktive Cron-Jobs: ${status['agents']['active_crons']}\n`;
    
    if ("disk_used" in status["system"]) {
        message += `\n**💾 System:**\n`;
        message += `Disk: ${status['system']['disk_used']} belegt\n`;
        message += `RAM: ${status['system']['ram_used']} / ${status['system']['ram_total']}\n`;
    }
    
    return message;
}

function format_weekly_status(status) {
    /** Format the weekly report from current node data. */
    const now = new Date();
    const weekNumber = Math.ceil((((now - new Date(now.getFullYear(), 0, 1)) / 86400000) + 1)/7);
    
    const lines = [
        `📈 **Wöchentlicher Report**`,
        `📅 Woche ${weekNumber} - ${now.getFullYear()}`,
        ``,
        `**Nodes:**`
    ];
    
    Object.values(status["nodes"]).forEach(item => {
        lines.push(`- ${item['name']}: ${item['status']}`);
    });
    
    return lines.join('\n') + '\n';
}

function send_to_channel(message, channel_type = "telegram", channel_id = "-1002381931352") {
    /** Sendet Nachricht an Channel */
    let cmd;
    if (channel_type === "telegram") {
        // Nutze OpenClaw message tool
        cmd = ["openclaw", "message", "send", "--target", channel_id, "--message", message];
    } else {
        log(`Channel type ${channel_type} not implemented`, "WARN");
        return Promise.resolve(false);
    }
    
    return new Promise((resolve) => {
        const child = spawn(cmd[0], cmd.slice(1));
        let stderr = '';
        
        child.stderr.on('data', (data) => {
            stderr += data.toString();
        });
        
        child.on('close', (code) => {
            if (code === 0) {
                log(`Message sent to ${channel_type} ${channel_id}`);
                resolve(true);
            } else {
                log(`Failed to send: ${stderr}`, "ERROR");
                resolve(false);
            }
        });
        
        child.on('error', (error) => {
            log(`Send error: ${error.message}`, "ERROR");
            resolve(false);
        });
    });
}

async function main() {
    /** Hauptfunktion */
    const yargs = require('yargs/yargs');
    const { hideBin } = require('yargs/helpers');
    
    const argv = yargs(hideBin(process.argv))
        .usage('Usage: $0 --type [daily|weekly|alert] [options]')
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
        .argv;
    
    log(`Starting ${argv.type} status update`);
    
    // Status sammeln
    const status = await get_system_status();
    
    // Message formatieren
    let message;
    if (argv.type === 'daily') {
        message = format_daily_status(status);
    } else if (argv.type === 'weekly') {
        message = format_weekly_status(status);
    } else if (argv.type === 'alert') {
        message = `🚨 **ALERT**\n${argv.message || 'Manual alert'}`;
    }
    
    // Senden oder Dry-Run
    if (argv.dryRun) {
        console.log("\n--- DRY RUN ---");
        console.log(message);
        console.log("--- END ---");
    } else {
        await send_to_channel(message, "telegram", argv.channel);
    }
    
    log("Status update completed");
}

// Ensure log directory exists
const logDir = path.dirname(LOG_FILE);
if (!fs.existsSync(logDir)) {
    fs.mkdirSync(logDir, { recursive: true });
}

main().catch(err => {
    console.error(err);
    process.exit(1);
});
