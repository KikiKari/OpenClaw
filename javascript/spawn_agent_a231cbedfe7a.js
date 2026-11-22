#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "9571cbe3553814b4cd6e59f4c6b2672868bbc6a7988a24372af1e57e0de33fd8", "source_sha256": "a26da3d1befb1a302d385e0a3c85117de3ec06543d5017cf1d706e7f0602be0f", "target_language": "javascript"}
// spawn_agent.py — portiert nach javascript
// Quelle: python, OpenClaw@gateway1:skills/sub-agents-utils/scripts/spawn_agent.py
// Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

/**
 * Sub-Agent spawner - Einfache CLI für sessions_spawn
 */

const fs = require('fs');
const path = require('path');
const { Command } = require('commander');

function loadModels() {
  const configPath = process.env.OPENCLAW_CONFIG || '/home/openclaw/.openclaw/openclaw.json';
  try {
    const configContent = fs.readFileSync(configPath, 'utf8');
    const config = JSON.parse(configContent);
    const modelConfig = config.agents.defaults.model;
    const candidates = [modelConfig.primary, ...modelConfig.fallbacks];
    
    const models = [...new Set(
      candidates.filter(model => 
        typeof model === 'string' && 
        model && 
        !model.startsWith('anthropic/')
      )
    )];
    
    if (models.length === 0) {
      throw new Error(`Keine allgemein verfügbaren Modelle in ${configPath}`);
    }
    return models;
  } catch (error) {
    throw new Error(`Modellkonfiguration kann nicht geladen werden: ${configPath}: ${error.message}`);
  }
}

const MODELS = loadModels();

class SubAgentSpawner {
  /** Hilft beim Spawnen von Sub-Agents */
  
  /**
   * Erstellt Konfiguration für sessions_spawn
   */
  static getSpawnConfig(task, label = null, model = null, thinking = null, timeout = null, thread = false, mode = "run") {
    const config = {
      task: task
    };
    
    if (label) {
      config.label = label;
    }
    if (model && MODELS.includes(model)) {
      config.model = model;
    }
    if (thinking) {
      config.thinking = thinking;
    }
    if (timeout) {
      config.runTimeoutSeconds = timeout;
    }
    if (thread) {
      config.thread = true;
      if (mode === "run") {
        config.mode = "session"; // thread requires session mode
      }
    } else {
      config.mode = mode;
    }
    
    return config;
  }
  
  /**
   * Gibt das equivalente Tool-Kommando aus
   */
  static printSpawnCommand(config) {
    console.log("\n🛠️  Tool-Aufruf:");
    console.log("=".repeat(50));
    console.log("sessions_spawn(");
    for (const [key, value] of Object.entries(config)) {
      if (typeof value === 'string') {
        console.log(`    ${key}="${value}"`);
      } else {
        console.log(`    ${key}=${value}`);
      }
    }
    console.log(")");
    console.log("=".repeat(50));
  }
  
  /**
   * Gibt das equivalente Slash-Kommando aus
   */
  static printSlashCommand(config) {
    const task = config.task || "";
    const label = config.label || "agent";
    const model = config.model || "";
    
    let cmd = `/subagents spawn ${label} "${task}"`;
    if (model) {
      cmd += ` --model ${model}`;
    }
    if (config.thinking) {
      cmd += ` --thinking ${config.thinking}`;
    }
    
    console.log("\n💬 Slash Command:");
    console.log("=".repeat(50));
    console.log(cmd);
    console.log("=".repeat(50));
  }
}

function main() {
  const program = new Command();
  
  program
    .description("Sub-Agent Spawn Helper")
    .option('-t, --task <task>', 'Aufgabenbeschreibung', { required: true })
    .option('-l, --label <label>', 'Optionaler Label')
    .option('-m, --model <model>', 'KI-Modell', MODELS)
    .option('--thinking <level>', 'Thinking Level', ['low', 'medium', 'high'])
    .option('--timeout <seconds>', 'Timeout in Sekunden', parseInt, 900)
    .option('--thread', 'Thread-Binding aktivieren')
    .option('--mode <mode>', 'Run mode', ['run', 'session'], 'run')
    .option('-o, --output <format>', 'Output format', ['tool', 'slash', 'json'], 'tool')
    .action((options) => {
      const spawner = new SubAgentSpawner();
      const config = spawner.getSpawnConfig(
        options.task,
        options.label,
        options.model,
        options.thinking,
        options.timeout,
        options.thread,
        options.mode
      );
      
      console.log("✅ Sub-Agent Konfiguration:");
      console.log(JSON.stringify(config, null, 2));
      
      if (options.output === "tool") {
        spawner.printSpawnCommand(config);
      } else if (options.output === "slash") {
        spawner.printSlashCommand(config);
      } else if (options.output === "json") {
        console.log("\n📄 JSON:");
        console.log(JSON.stringify(config));
        
        // Speichere als Datei
        const label = config.label || 'spawn';
        const output_file = path.join('/tmp', `subagent_${label}.json`);
        fs.writeFileSync(output_file, JSON.stringify(config, null, 2));
        console.log(`💾 Gespeichert: ${output_file}`);
      }
    });
  
  program.addHelpText('afterAll', `
Beispiele:
  ${program.name()} -t "Analyze logs" 
  ${program.name()} -t "Code review" -m openai/gpt-5.6-sol --timeout 1800
  ${program.name()} -t "Batch process" -l "batch-worker" --thread
  `);
  
  program.parse();
}

if (require.main === module) {
  main();
}
