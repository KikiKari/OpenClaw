#!/usr/bin/env node
// spawn_agent.py — portiert nach javascript
// Quelle: python, OpenClaw@gateway2:skills/sub-agents-utils/scripts/spawn_agent.py
// Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

/**
 * Sub-Agent spawner - Einfache CLI für sessions_spawn
 */

const fs = require('fs');
const path = require('path');
const { program } = require('commander');

// Simuliere den WORKSPACE-Pfad und füge ihn zum Suchpfad hinzu
const WORKSPACE = '/home/openclaw/.openclaw/workspace';
// In Node.js gibt es keinen direkten sys.path-Ersatz, aber wir können Module laden

// Lade die Modellkonfiguration (simuliert)
let MODELS = [];
try {
    // In einer echten Implementierung würden wir hier die Modelle laden
    // Für dieses Beispiel verwenden wir eine feste Liste
    MODELS = ['openai/gpt-4', 'openai/gpt-3.5-turbo', 'anthropic/claude-3-opus', 'openrouter/anthropic/claude-haiku-4.5'];
} catch (error) {
    console.error(`Modellkonfiguration kann nicht geladen werden: ${error.message}`);
    process.exit(1);
}

class SubAgentSpawner {
    /** Hilft beim Spawnen von Sub-Agents */
    
    static getSpawnConfig(options) {
        /** Erstellt Konfiguration für sessions_spawn */
        
        const config = {
            task: options.task
        };
        
        if (options.label) {
            config.label = options.label;
        }
        if (options.model && MODELS.includes(options.model)) {
            config.model = options.model;
        }
        if (options.thinking) {
            config.thinking = options.thinking;
        }
        if (options.timeout) {
            config.runTimeoutSeconds = options.timeout;
        }
        if (options.thread) {
            config.thread = true;
            if (options.mode === 'run') {
                config.mode = 'session'; // thread requires session mode
            }
        } else {
            config.mode = options.mode;
        }
        
        return config;
    }
    
    static printSpawnCommand(config) {
        /** Gibt das equivalente Tool-Kommando aus */
        console.log('\n🛠️  Tool-Aufruf:');
        console.log('=' .repeat(50));
        console.log('sessions_spawn(');
        for (const [key, value] of Object.entries(config)) {
            if (typeof value === 'string') {
                console.log(`    ${key}="${value}"`);
            } else {
                console.log(`    ${key}=${value}`);
            }
        }
        console.log(')');
        console.log('=' .repeat(50));
    }
    
    static printSlashCommand(config) {
        /** Gibt das equivalente Slash-Kommando aus */
        const task = config.task || '';
        const label = config.label || 'agent';
        const model = config.model || '';
        
        let cmd = `/subagents spawn ${label} "${task}"`;
        if (model) {
            cmd += ` --model ${model}`;
        }
        if (config.thinking) {
            cmd += ` --thinking ${config.thinking}`;
        }
        
        console.log('\n💬 Slash Command:');
        console.log('=' .repeat(50));
        console.log(cmd);
        console.log('=' .repeat(50));
    }
}

function main() {
    program
        .description('Sub-Agent Spawn Helper')
        .option('-t, --task <task>', 'Aufgabenbeschreibung', '')
        .option('-l, --label <label>', 'Optionaler Label')
        .option('-m, --model <model>', 'KI-Modell', MODELS)
        .option('--thinking <level>', 'Thinking Level', ['low', 'medium', 'high'])
        .option('--timeout <seconds>', 'Timeout in Sekunden', 900)
        .option('--thread', 'Thread-Binding aktivieren', false)
        .option('--mode <mode>', 'Run mode', 'run', ['run', 'session'])
        .option('-o, --output <format>', 'Output format', 'tool', ['tool', 'slash', 'json'])
        .addHelpText('afterAll', `
Beispiele:
  spawn_agent.js -t "Analyze logs" 
  spawn_agent.js -t "Code review" -m openrouter/anthropic/claude-haiku-4.5 --timeout 1800
  spawn_agent.js -t "Batch process" -l "batch-worker" --thread
        `);

    program.parse();
    
    const options = program.opts();
    
    if (!options.task) {
        console.error('Fehler: --task ist erforderlich');
        program.help();
        process.exit(1);
    }
    
    const spawner = new SubAgentSpawner();
    const config = spawner.getSpawnConfig(options);
    
    console.log('✅ Sub-Agent Konfiguration:');
    console.log(JSON.stringify(config, null, 2));
    
    if (options.output === 'tool') {
        spawner.printSpawnCommand(config);
    } else if (options.output === 'slash') {
        spawner.printSlashCommand(config);
    } else if (options.output === 'json') {
        console.log('\n📄 JSON:');
        console.log(JSON.stringify(config));
        
        // Speichere als Datei
        const outputDir = '/tmp';
        const fileName = `subagent_${config.label || 'spawn'}.json`;
        const outputPath = path.join(outputDir, fileName);
        
        fs.writeFileSync(outputPath, JSON.stringify(config, null, 2));
        console.log(`💾 Gespeichert: ${outputPath}`);
    }
}

main();
