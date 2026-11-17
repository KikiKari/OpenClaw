#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "d4b6d5a5036affa772c6d0d09e9dde153d911709f014881bcbed0ce7e825353c", "source_sha256": "8cb73cb9ea3a2ccee09205fcea5d8d2e1f29c369b21a3dfcf948b8029436a339", "target_language": "javascript"}
// node_health.py — portiert nach javascript
// Quelle: python, OpenClaw@gateway1:skills/node-health-monitor/scripts/node_health.py
// Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

/**
 * Node Health Monitor - Multi-Node Gesundheitsüberwachung
 */

const fs = require('fs');
const path = require('path');
const { execSync, spawn } = require('child_process');

// Konfiguration
const WORKSPACE = "/home/openclaw/.openclaw/workspace";
const HEALTH_DB = path.join(WORKSPACE, "db/health.db");
const LOG_FILE = path.join(WORKSPACE, "logs/node-health.log");

// Node-Definitionen
const NODES = {
    "node1": {
        "name": "Gateway",
        "host": "localhost",
        "user": "openclaw",
        "critical": true
    },
    "node2": {
        "name": "Worker", 
        "host": "100.92.155.34",
        "user": "root",
        "ssh_key": "~/.ssh/id_rsa"
    },
    "node3": {
        "name": "Relay",
        "host": "185.242.xxx.xxx",
        "user": "root",
        "disk_warning": 85
    },
    "node5": {
        "name": "Redmi",
        "host": "192.168.1.x",
        "user": "openclaw",
        "optional": true
    }
};

function log(message, level = "INFO") {
    /** Logging */
    const timestamp = new Date().toISOString().replace('T', ' ').substring(0, 19);
    const entry = `[${timestamp}] [${level}] ${message}`;
    console.log(entry);
    
    const logDir = path.dirname(LOG_FILE);
    if (!fs.existsSync(logDir)) {
        fs.mkdirSync(logDir, { recursive: true });
    }
    
    fs.appendFileSync(LOG_FILE, entry + '\n');
}

function checkPing(host, timeout = 5) {
    /** Prüft Erreichbarkeit */
    try {
        const cmd = process.platform === 'win32' 
            ? `ping -n 1 -w ${timeout * 1000} ${host}` 
            : `ping -c 1 -W ${timeout} ${host}`;
        
        execSync(cmd, { stdio: 'ignore' });
        return true;
    } catch (error) {
        return false;
    }
}

function checkSSH(nodeConfig) {
    /** Prüft SSH-Verbindung */
    const host = nodeConfig.host;
    const user = nodeConfig.user || "root";
    
    const cmd = `ssh -o ConnectTimeout=10 -o BatchMode=yes ${user}@${host} echo "OK"`;
    
    try {
        const result = execSync(cmd, { encoding: 'utf8' });
        return result.includes("OK");
    } catch (error) {
        return false;
    }
}

function getNodeMetrics(nodeConfig) {
    /** Holt Metriken via SSH */
    const host = nodeConfig.host;
    const user = nodeConfig.user || "root";
    
    const metrics = {
        "timestamp": new Date().toISOString(),
        "available": false,
        "cpu": null,
        "ram": null,
        "disk": null,
        "load": null
    };
    
    // SSH-Command für alle Metriken
    const cmd = `ssh -o ConnectTimeout=10 ${user}@${host} '
        # CPU
        echo "CPU:$(top -bn1 | grep "Cpu(s)" | awk "{print \\$2}" | cut -d"%" -f1)"
        
        # RAM
        echo "RAM:$(free | grep Mem | awk "{print (\\$3/\\$2) * 100.0}")"
        
        # Disk
        echo "DISK:$(df -h / | tail -1 | awk "{print \\$5}" | tr -d "%")"
        
        # Load
        echo "LOAD:$(uptime | awk -F"load average:" "{print \\$2}" | awk "{print \\$1}" | tr -d ",")"
        
        # Gateway Status
        if command -v openclaw >/dev/null 2>&1; then
            systemctl is-active openclaw-gateway 2>/dev/null || echo "GATEWAY:inactive"
        fi
    '`;
    
    try {
        const result = execSync(cmd, { encoding: 'utf8', timeout: 15000 });
        
        if (result) {
            metrics.available = true;
            
            result.trim().split('\n').forEach(line => {
                if (line.includes(':')) {
                    const [key, value] = line.split(':', 2);
                    if (key === "CPU" && value) {
                        metrics.cpu = parseFloat(value);
                    } else if (key === "RAM" && value) {
                        metrics.ram = parseFloat(value);
                    } else if (key === "DISK" && value) {
                        metrics.disk = parseInt(value, 10);
                    } else if (key === "LOAD" && value) {
                        metrics.load = parseFloat(value);
                    } else if (key === "GATEWAY" && value) {
                        metrics.gateway_status = value;
                    }
                }
            });
        }
    } catch (error) {
        if (error.killed && error.signal === 'SIGTERM') {
            log(`SSH timeout for ${nodeConfig.name}`, "WARN");
        } else {
            log(`Error checking ${nodeConfig.name}: ${error.message}`, "ERROR");
        }
    }
    
    return metrics;
}

function checkAlerts(nodeId, nodeConfig, metrics) {
    /** Prüft Schwellwerte und generiert Alerts */
    const alerts = [];
    
    // Verfügbarkeit
    if (!metrics.available) {
        if (!nodeConfig.optional) {
            alerts.push({
                "level": "CRITICAL",
                "message": `Node ${nodeConfig.name} nicht erreichbar!`
            });
        }
    } else {
        // CPU
        if (metrics.cpu !== null && metrics.cpu > 90) {
            alerts.push({
                "level": "WARNING",
                "message": `Node ${nodeConfig.name}: CPU bei ${metrics.cpu.toFixed(1)}%`
            });
        }
        
        // RAM
        if (metrics.ram !== null && metrics.ram > 90) {
            alerts.push({
                "level": "WARNING", 
                "message": `Node ${nodeConfig.name}: RAM bei ${metrics.ram.toFixed(1)}%`
            });
        }
        
        // Disk
        const diskThreshold = nodeConfig.disk_warning || 85;
        if (metrics.disk !== null && metrics.disk > diskThreshold) {
            const level = metrics.disk > 95 ? "CRITICAL" : "WARNING";
            alerts.push({
                "level": level,
                "message": `Node ${nodeConfig.name}: Disk bei ${metrics.disk}%`
            });
        }
        
        // Gateway
        if (nodeConfig.critical && metrics.gateway_status === "inactive") {
            alerts.push({
                "level": "CRITICAL",
                "message": `Node ${nodeConfig.name}: OpenClaw Gateway nicht aktiv!`
            });
        }
    }
    
    return alerts;
}

function sendAlert(alert) {
    /** Sendet Alert via channel-status-agent */
    try {
        const scriptPath = path.join(WORKSPACE, "skills/channel-status-agent/scripts/channel_status.py");
        const cmd = `python3 "${scriptPath}" --type alert --message "${alert.level}: ${alert.message}"`;
        
        execSync(cmd, { stdio: 'ignore' });
        log(`Alert sent: ${alert.message}`);
    } catch (error) {
        log(`Failed to send alert: ${error.message}`, "ERROR");
    }
}

function main() {
    /** Hauptfunktion */
    const args = process.argv.slice(2);
    let nodeArg = 'all';
    let checkArg = 'all';
    let sendAlerts = false;
    
    // Argumente parsen
    for (let i = 0; i < args.length; i++) {
        if (args[i] === '--node' && i + 1 < args.length) {
            nodeArg = args[++i];
        } else if (args[i] === '--check' && i + 1 < args.length) {
            checkArg = args[++i];
        } else if (args[i] === '--alert') {
            sendAlerts = true;
        }
    }
    
    // Nodes bestimmen
    let nodesToCheck;
    if (nodeArg === 'all') {
        nodesToCheck = Object.entries(NODES);
    } else {
        if (NODES[nodeArg]) {
            nodesToCheck = [[nodeArg, NODES[nodeArg]]];
        } else {
            log(`Unknown node: ${nodeArg}`, "ERROR");
            process.exit(1);
        }
    }
    
    // Health-Checks durchführen
    const allAlerts = [];
    
    for (const [nodeId, nodeConfig] of nodesToCheck) {
        log(`Checking ${nodeConfig.name} (${nodeId})`);
        
        // Ping
        if (checkArg === 'ping' || checkArg === 'all') {
            if (nodeConfig.host !== "localhost") {
                const pingOk = checkPing(nodeConfig.host);
                log(`  Ping: ${pingOk ? 'OK' : 'FAILED'}`);
            }
        }
        
        // SSH
        if (checkArg === 'ssh' || checkArg === 'all') {
            const sshOk = checkSSH(nodeConfig);
            log(`  SSH: ${sshOk ? 'OK' : 'FAILED'}`);
        }
        
        // Metriken
        if (checkArg === 'metrics' || checkArg === 'all') {
            const metrics = getNodeMetrics(nodeConfig);
            
            if (metrics.available) {
                log(`  CPU: ${metrics.cpu !== null ? metrics.cpu.toFixed(1) + '%' : 'N/A'}`);
                log(`  RAM: ${metrics.ram !== null ? metrics.ram.toFixed(1) + '%' : 'N/A'}`);
                log(`  Disk: ${metrics.disk !== null ? metrics.disk + '%' : 'N/A'}`);
                log(`  Load: ${metrics.load !== null ? metrics.load : 'N/A'}`);
            } else {
                log("  Metrics: UNAVAILABLE");
            }
            
            // Alerts prüfen
            const alerts = checkAlerts(nodeId, nodeConfig, metrics);
            allAlerts.push(...alerts);
        }
    }
    
    // Alerts senden
    if (sendAlerts && allAlerts.length > 0) {
        log(`\nSending ${allAlerts.length} alerts...`);
        for (const alert of allAlerts) {
            sendAlert(alert);
        }
    } else if (allAlerts.length > 0) {
        log(`\n${allAlerts.length} alerts found (use --alert to send)`);
    } else {
        log("\nAll nodes healthy!");
    }
}

main();
