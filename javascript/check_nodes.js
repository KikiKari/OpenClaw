#!/usr/bin/env node
// check_nodes.py — portiert nach javascript
// Quelle: python, OpenClaw@gateway1:skills/multi-nodes-utils/scripts/check_nodes.py
// auch in: OpenClaw@gateway2:skills/multi-nodes-utils/scripts/check_nodes.py
// Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

/**
 * Node-Status Checker - Prüft Verfügbarkeit aller Nodes
 */

const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');

// Node-Konfiguration (sollte aus config file geladen werden)
const NODES = {
    "node1": {
        "always_available": true,
        "capacity": "medium",
        "priority": 2,
        "description": "Gateway-Master"
    },
    "node2": {
        "always_available": true,
        "capacity": "medium",
        "priority": 3,
        "description": "Stable Worker"
    },
    "node3": {
        "always_available": false,
        "capacity": "medium",
        "priority": 4,
        "description": "Bald verfügbar (nach Reorganisation)"
    },
    "node5": {
        "always_available": false,
        "capacity": "low",
        "priority": 5,
        "device": "Redmi Note 11S",
        "description": "Mobile (bei Internet verfügbar)"
    },
    "node7": {
        "always_available": true,
        "capacity": "high",
        "priority": 1,
        "description": "Docker Hauptarbeitspferd (bald verfügbar)"
    },
};

function checkNodeStatus(nodeId) {
    return new Promise((resolve) => {
        try {
            exec(`openclaw nodes status ${nodeId}`, { timeout: 5000 }, (error, stdout, stderr) => {
                const isOnline = error === null && (
                    stdout.toLowerCase().includes("online") || 
                    stdout.toLowerCase().includes("active")
                );
                
                resolve({
                    "id": nodeId,
                    "online": isOnline,
                    "available": NODES[nodeId].always_available || false,
                    "response": stdout ? stdout.trim().substring(0, 100) : "No response"
                });
            });
        } catch (e) {
            resolve({
                "id": nodeId,
                "online": false,
                "available": NODES[nodeId].always_available || false,
                "response": `Error: ${e.message}`
            });
        }
    });
}

function printTable(nodesStatus) {
    console.log("\n" + "=".repeat(90));
    console.log(`${'Node'.padEnd(8)} ${'Status'.padEnd(12)} ${'Verfügbar'.padEnd(12)} ${'Kapazität'.padEnd(10)} ${'Priorität'.padEnd(10)} Gerät/Beschreibung`);
    console.log("=".repeat(90));
    
    for (const status of nodesStatus) {
        const nodeId = status.id;
        const config = NODES[nodeId];
        
        const statusIcon = status.online ? "🟢 Online" : "🔴 Offline";
        const availIcon = status.available ? "✅ Immer" : "📱 Bedingt";
        const capacity = config.capacity || "unknown";
        const priority = config.priority || "-";
        const device = config.device || config.description || "";
        
        console.log(`${nodeId.padEnd(8)} ${statusIcon.padEnd(12)} ${availIcon.padEnd(12)} ${capacity.padEnd(10)} ${priority.toString().padEnd(10)} ${device}`);
    }
    
    console.log("=".repeat(90));
    console.log(`\nGeprüft am: ${new Date().toLocaleString('de-DE', {year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit'})}`);
}

function printJson(nodesStatus) {
    const output = {
        "timestamp": new Date().toISOString(),
        "nodes": {}
    };
    
    for (const status of nodesStatus) {
        const nodeId = status.id;
        output.nodes[nodeId] = {
            "status": status,
            "config": NODES[nodeId]
        };
    }
    
    console.log(JSON.stringify(output, null, 2));
}

async function main() {
    const yargs = require('yargs/yargs');
    const { hideBin } = require('yargs/helpers');
    const argv = yargs(hideBin(process.argv))
        .option('format', {
            alias: 'f',
            type: 'string',
            choices: ['table', 'json'],
            default: 'table',
            description: 'Output format'
        })
        .option('save', {
            alias: 's',
            type: 'string',
            description: 'Save to file'
        })
        .parse();

    console.log("🔍 Prüfe Node-Status...");
    
    // Prüfe alle Nodes
    const nodesStatus = [];
    const nodeIds = Object.keys(NODES).sort();
    
    for (const nodeId of nodeIds) {
        process.stdout.write(`  → ${nodeId}... `);
        const status = await checkNodeStatus(nodeId);
        nodesStatus.push(status);
        console.log(status.online ? "✓" : "✗");
    }
    
    // Ausgabe
    if (argv.format === 'table') {
        printTable(nodesStatus);
    } else {
        printJson(nodesStatus);
    }
    
    // Speichern
    if (argv.save) {
        const output = {
            "timestamp": new Date().toISOString(),
            "nodes": {}
        };
        
        for (const status of nodesStatus) {
            output.nodes[status.id] = status;
        }
        
        fs.writeFileSync(argv.save, JSON.stringify(output, null, 2));
        console.log(`\n💾 Gespeichert: ${argv.save}`);
    }
    
    // Zusammenfassung
    const onlineCount = nodesStatus.filter(s => s.online).length;
    console.log(`\n📊 Zusammenfassung: ${onlineCount}/${nodesStatus.length} Nodes online`);
}

if (require.main === module) {
    main().catch(console.error);
}
