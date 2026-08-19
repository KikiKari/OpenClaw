#!/usr/bin/env node
// dispatch_job.py — portiert nach javascript
// Quelle: python, OpenClaw@gateway1:skills/multi-nodes-utils/scripts/dispatch_job.py
// auch in: OpenClaw@gateway2:skills/multi-nodes-utils/scripts/dispatch_job.py
// Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

/**
 * Job Dispatcher - Verteilt Jobs auf passende Nodes
 */

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

// Node-Konfiguration
const NODES = {
    "node1": { "always_available": true, "capacity": "medium", "priority": 2 },
    "node2": { "always_available": true, "capacity": "medium", "priority": 3 },
    "node3": { "always_available": false, "capacity": "medium", "priority": 4 },
    "node5": { "always_available": false, "capacity": "low", "priority": 5, "device": "Redmi Note 11S" },
    "node7": { "always_available": true, "capacity": "high", "priority": 1 }
};

class JobDispatcher {
    /** Dispatches jobs to appropriate nodes based on weight */
    
    /**
     * Bewertet Job-Gewicht
     * @param {string} scriptPath 
     * @param {number} targetLangsCount 
     * @returns {string}
     */
    getJobWeight(scriptPath, targetLangsCount = 1) {
        if (!fs.existsSync(scriptPath)) {
            return "medium";
        }
        
        const stats = fs.statSync(scriptPath);
        const scriptSize = stats.size;
        const totalWork = scriptSize * targetLangsCount;
        
        if (totalWork > 50000) {  // > 50KB
            return "heavy";
        } else if (totalWork > 10000) {  // > 10KB
            return "medium";
        } else {
            return "light";
        }
    }
    
    /**
     * Wählt besten Node basierend auf Job-Gewicht
     * @param {string} jobWeight 
     * @returns {string}
     */
    selectNode(jobWeight) {
        let preferred = [];
        
        if (jobWeight === "heavy") {
            // Schwere Jobs → Node 7 (Docker), dann Node 2, dann Node 1
            preferred = ["node7", "node2", "node1"];
        } else if (jobWeight === "medium") {
            // Mittlere Jobs → Stable Nodes
            preferred = ["node2", "node1", "node7"];
        } else {  // light
            // Leichte Jobs → Mobile/verfügbare Nodes
            preferred = ["node5", "node1", "node2"];
        }
        
        // Prüfe Verfügbarkeit
        for (const nodeId of preferred) {
            if (this.checkNodeAvailable(nodeId)) {
                return nodeId;
            }
        }
        
        // Fallback
        return "node1";
    }
    
    /**
     * Prüft ob Node erreichbar ist
     * @param {string} nodeId 
     * @returns {boolean}
     */
    checkNodeAvailable(nodeId) {
        if (!NODES[nodeId]) {
            return false;
        }
        
        const node = NODES[nodeId];
        
        // Nicht immer-verfügbare Nodes nur wenn explizit requested
        if (!node.always_available) {
            // Für light-jobs prüfen wir ob online
            if (nodeId === "node5") {  // Redmi
                return this._checkMobileOnline();
            }
            return false;
        }
        
        // Für immer-verfügbare Nodes: prüfe ob wirklich online
        try {
            const result = spawnSync("openclaw", ["nodes", "status", nodeId], {
                timeout: 3000
            });
            return result.status === 0;
        } catch (error) {
            return !!node.always_available;
        }
    }
    
    /**
     * Prüft ob Redmi (Node 5) Internet hat
     * @returns {boolean}
     */
    _checkMobileOnline() {
        try {
            const result = spawnSync("openclaw", ["nodes", "status", "node5"], {
                timeout: 5000
            });
            return result.status === 0 && result.stdout.toString().toLowerCase().includes("online");
        } catch (error) {
            return false;
        }
    }
    
    /**
     * Dispatched Job und gibt Info zurück
     * @param {string} jobScript 
     * @param {string[]} targetLangs 
     * @returns {Object}
     */
    dispatch(jobScript, targetLangs = null) {
        if (targetLangs === null) {
            targetLangs = ["perl5"];
        }
        
        const weight = this.getJobWeight(jobScript, targetLangs.length);
        const selectedNode = this.selectNode(weight);
        
        return {
            job: jobScript,
            weight: weight,
            selected_node: selectedNode,
            target_langs: targetLangs,
            status: "dispatched"
        };
    }
}

/**
 * Main function to parse arguments and run dispatcher
 */
function main() {
    const args = process.argv.slice(2);
    let jobPath = null;
    let targetLangsStr = "perl5";
    let forceWeight = null;
    let execute = false;
    
    // Simple argument parsing
    for (let i = 0; i < args.length; i++) {
        if (args[i] === "--job" || args[i] === "-j") {
            jobPath = args[++i];
        } else if (args[i] === "--langs" || args[i] === "-l") {
            targetLangsStr = args[++i];
        } else if (args[i] === "--weight" || args[i] === "-w") {
            forceWeight = args[++i];
        } else if (args[i] === "--execute" || args[i] === "-x") {
            execute = true;
        }
    }
    
    if (!jobPath) {
        console.error("❌ Job path is required");
        process.exit(1);
    }
    
    if (!fs.existsSync(jobPath)) {
        console.error(`❌ Job not found: ${jobPath}`);
        process.exit(1);
    }
    
    const dispatcher = new JobDispatcher();
    const targetLangs = targetLangsStr.split(",");
    
    // Determine weight
    const weight = forceWeight || dispatcher.getJobWeight(jobPath, targetLangs.length);
    
    // Select node
    const selectedNode = dispatcher.selectNode(weight);
    
    // Output
    console.log("📦 Job Dispatch Information");
    console.log("=".repeat(50));
    const stats = fs.statSync(jobPath);
    console.log(`Job: ${jobPath}`);
    console.log(`Size: ${stats.size} bytes`);
    console.log(`Target langs: ${targetLangs.join(", ")}`);
    console.log(`Job weight: ${weight}`);
    console.log(`Selected node: ${selectedNode}`);
    console.log("=".repeat(50));
    
    if (execute) {
        console.log(`\n🚀 Executing on ${selectedNode}...`);
        // TODO: Implement remote execution
        console.log("(Remote execution not yet implemented)");
    } else {
        console.log(`\n💡 To execute: ${process.argv[1]} --job ${jobPath} --execute`);
    }
}

if (require.main === module) {
    main();
}

module.exports = { JobDispatcher };
