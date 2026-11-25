#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "3be479d0d3ba9cf9d1b21a1405d4ea84b2baa908066e83d93a669342574755d7", "source_sha256": "427807a362e6e00a5a3186533edce544430f9f5097e6eda1d8dac1a6ffaf2107", "target_language": "javascript"}
// test_multinode_fallback.py — portiert nach javascript
// Quelle: python, workspace@local:scripts/test_multinode_fallback.py
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

/**
 * Testet Multi-Node Fallback-Logik des db-maintainer
 * Simuliert: Worker-Node nicht erreichbar → Fallback auf lokal
 */

const { execSync, spawn } = require('child_process');
const path = require('path');
const os = require('os');

const WORKSPACE = path.join(os.homedir(), '.openclaw/workspace');

/**
 * Prüft den Verbindungseintrag dieses Nodes, nicht die Gesamtausgabe.
 */
function checkNodeReachable(nodeId) {
    const aliases = new Set([nodeId.toLowerCase()]);
    const node2Names = new Set([
        "openclaw-node2",
        "arm64-node",
        "v2202604104722449961",
        "v2202604104722449961.taild25fea.ts.net"
    ]);
    
    if (node2Names.has(nodeId.toLowerCase())) {
        node2Names.forEach(name => aliases.add(name));
    }
    
    try {
        const result = execSync('openclaw nodes status --json', {
            timeout: 10000,
            encoding: 'utf8'
        });
        const payload = JSON.parse(result);
        return (payload.nodes || []).some(node => 
            typeof node === 'object' &&
            aliases.has(String(node.displayName || '').toLowerCase()) &&
            node.connected === true
        );
    } catch (error) {
        return false;
    }
}

/**
 * Versucht Task auf Node auszuführen
 */
function spawnOnNode(nodeId, task) {
    console.log(`Versuche Task auf Node ${nodeId} zu starten...`);
    try {
        // Simuliert: openclaw agent spawn --node {node_id}
        execSync(`echo 'Spawned on ${nodeId}: ${task}'`, {
            timeout: 5000,
            stdio: 'inherit'
        });
        console.log(`✅ Erfolgreich delegiert an ${nodeId}`);
        return true;
    } catch (error) {
        console.log(`❌ Node ${nodeId} nicht erreichbar: ${error.message}`);
        return false;
    }
}

/**
 * Führt Task lokal aus (Fallback)
 */
function executeLocally(task) {
    console.log("🔄 Fallback: Führe Task lokal aus...");
    try {
        if (task === 'db_maintainer') {
            const scriptPath = path.join(
                WORKSPACE, 
                'skills', 
                'db-maintainer', 
                'scripts', 
                'db_maintainer.py'
            );
            
            const result = execSync(`python3 "${scriptPath}"`, {
                timeout: 60000,
                encoding: 'utf8'
            });
            
            console.log("✅ Lokale Ausführung erfolgreich");
            return true;
        }
    } catch (error) {
        console.log(`❌ Fehler: ${error.message.substring(0, 200)}`);
        return false;
    }
}

function main() {
    console.log("=".repeat(60));
    console.log("MULTI-NODE FALLBACK TEST");
    console.log("=".repeat(60));
    console.log();
    
    // Konfiguration
    const primaryNode = 'v2202604104722449961.taild25fea.ts.net';  // Node 2
    const task = 'db_maintainer';
    
    console.log(`Primärer Node: ${primaryNode}`);
    console.log(`Task: ${task}`);
    console.log();
    
    // 1. Prüfe Node-Erreichbarkeit
    console.log("--- 1. Prüfe Node-Erreichbarkeit ---");
    if (checkNodeReachable(primaryNode)) {
        console.log(`✅ Node ${primaryNode} ist erreichbar`);
        
        // 2. Versuche Delegation
        console.log("\n--- 2. Versuche Delegation ---");
        if (spawnOnNode(primaryNode, task)) {
            console.log("\n✅ MULTI-NODE: Task erfolgreich delegiert");
            return 0;
        } else {
            console.log("\n⚠️ Delegation fehlgeschlagen, aktiviere Fallback...");
        }
    } else {
        console.log(`❌ Node ${primaryNode} nicht erreichbar`);
        console.log("🔄 Fallback wird aktiviert...");
    }
    
    // 3. Lokale Ausführung (Fallback)
    console.log("\n--- 3. Lokale Ausführung (Fallback) ---");
    if (executeLocally(task)) {
        console.log("\n✅ FALLBACK: Task lokal erfolgreich ausgeführt");
        return 0;
    } else {
        console.log("\n❌ FEHLER: Weder Delegation noch Fallback erfolgreich");
        return 1;
    }
}

process.exitCode = main();
