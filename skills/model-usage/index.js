#!/usr/bin/env node
/**
 * Model Usage Skill for OpenClaw
 * Manages AI model configurations and recommendations
 */

const fs = require('fs');
const path = require('path');

// Optional metadata only. Availability and aliases always come from openclaw.json.
const MODEL_METADATA = {};

class ModelUsageSkill {
  constructor() {
    this.configPath = path.join(process.env.HOME, '.openclaw', 'openclaw.json');
  }

  readConfig() {
    try {
      const data = fs.readFileSync(this.configPath, 'utf8');
      return JSON.parse(data);
    } catch (e) {
      console.error('Error reading config:', e.message);
      return null;
    }
  }

  getModels() {
    const config = this.readConfig();
    const entries = config?.agents?.defaults?.models;
    if (!entries || typeof entries !== 'object' || Array.isArray(entries)) {
      throw new Error('agents.defaults.models fehlt oder ist ungültig');
    }
    return Object.fromEntries(Object.entries(entries).map(([id, details]) => {
      if (!details?.alias) throw new Error(`Alias fehlt für Modell: ${id}`);
      return [id, { name: details.alias, ...(MODEL_METADATA[id] || {}) }];
    }));
  }

  getFallbacks() {
    const config = this.readConfig();
    return config?.agents?.defaults?.model?.fallbacks || [];
  }

  getCurrentModel() {
    const config = this.readConfig();
    if (!config) return null;
    return config.agents?.defaults?.model?.primary || 'openrouter/auto';
  }

  listModels(provider = null) {
    const models = this.getModels();
    console.log('\n📊 Available Models\n');
    console.log('Model ID                                         | Alias');
    console.log('-------------------------------------------------|---------------------');
    
    Object.entries(models).forEach(([id, model]) => {
      console.log(`${id.padEnd(49)}| ${model.name}`);
    });
  }

  recommendTask(taskType) {
    const models = this.getModels();
    const fallbacks = this.getFallbacks();
    console.log(`\n🎯 Configured routing for: ${taskType}\n`);
    console.log(`Primary:   ${this.getCurrentModel()} (${models[this.getCurrentModel()]?.name})`);
    console.log(`Fallbacks: ${fallbacks.map(id => `${id} (${models[id]?.name})`).join(', ')}`);
  }

  showCurrent() {
    const current = this.getCurrentModel();
    console.log(`\n🔧 Current Model: ${current}`);
    const model = this.getModels()[current];
    if (model) {
      console.log(`   Name: ${model.name}`);
    }
    console.log();
  }

  showUsage() {
    console.log(`\n📈 Token Usage Tracking\n`);
    console.log('Usage tracking is managed by OpenClaw Gateway.');
    console.log('View detailed usage at: https://openrouter.ai/activity\n');
  }

  run(args) {
    const command = args[0];

    switch (command) {
      case 'current':
        this.showCurrent();
        break;
      case 'list':
        this.listModels();
        break;
      case 'recommend':
        const task = args[1]?.replace('--task=', '').replace('--', '');
        this.recommendTask(task || 'simple');
        break;
      case 'usage':
        this.showUsage();
        break;
      case 'help':
      default:
        this.showHelp();
    }
  }

  showHelp() {
    console.log(`
Model Usage Skill - AI Model Management

Commands:
  current              Show currently configured model
  list                 List all available models with pricing
  recommend <task>     Recommend model for task type
                       Tasks: simple, long_context, complex_logic, web_agents
  usage                Show usage information
  help                 Show this help message

Examples:
  model-usage current
  model-usage list
  model-usage recommend simple
  model-usage recommend complex_logic
`);
  }
}

// CLI entry point
if (require.main === module) {
  const skill = new ModelUsageSkill();
  skill.run(process.argv.slice(2));
}

module.exports = ModelUsageSkill;
