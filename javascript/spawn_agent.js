#!/usr/bin/env node
// spawn_agent.py — portiert nach javascript
// Quelle: python, OpenClaw@gateway1:skills/sub-agents-utils/scripts/spawn_agent.py
// Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

/**
 * Sub-Agent spawner - Einfache CLI für sessions_spawn
 */

const fs = require('fs');
const path = require('path');
const { Command } = require('commander');

function loadModels() {
  const configPath = process.env.OPENCLAW_CONFIG || '/home/openclaw/.openclaw/openclaw.json';
  try {
    const configContent = fs.readFileSync(configPath, 'utf-8');
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
  
  static getSpawnConfig(task, options = {}) {
    /** Erstellt Konfiguration für sessions_spawn */
    
    const config = {
      task: task
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
      config.mode = options.mode || 'run';
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
  const program = new Command();
  
  program
    .description('Sub-Agent Spawn Helper')
    .option('-t, --task <task>', 'Aufgabenbeschreibung')
    .option('-l, --label <label>', 'Optionaler Label')
    .option('-m, --model <model>', 'KI-Modell', MODELS)
    .option('--thinking <level>', 'Thinking Level', ['low', 'medium', 'high'])
    .option('--timeout <seconds>', 'Timeout in Sekunden', 900)
    .option('--thread', 'Thread-Binding aktivieren')
    .option('--mode <mode>', 'Run mode', 'run', ['run', 'session'])
    .option('-o, --output <format>', 'Output format', 'tool', ['tool', 'slash', 'json'])
    .addHelpText('afterAll', `
Beispiele:
  spawn_agent.js -t "Analyze logs" 
  spawn_agent.js -t "Code review" -m openai/gpt-5.6-sol --timeout 1800
  spawn_agent.js -t "Batch process" -l "batch-worker" --thread
    `);
  
  program.parse();
  
  const options = program.opts();
  
  if (!options.task) {
    console.error('Fehler: --task ist erforderlich');
    process.exit(1);
  }
  
  const spawner = new SubAgentSpawner();
  const config = spawner.getSpawnConfig(options.task, options);
  
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
    const outputFile = path.join(outputDir, `subagent_${config.label || 'spawn'}.json`);
    fs.writeFileSync(outputFile, JSON.stringify(config, null, 2));
    console.log(`💾 Gespeichert: ${outputFile}`);
  }
}

main();
