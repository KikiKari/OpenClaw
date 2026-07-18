#!/usr/bin/env node
/**
 * Model Usage Skill for OpenClaw
 * Manages AI model configurations and recommendations
 */

const fs = require('fs');
const path = require('path');

// Task recommendations
const TASK_RECOMMENDATIONS = {
  simple: {
    primary: 'openai/gpt-5.6-luna',
    fallback: 'openrouter/moonshotai/kimi-k3',
    description: 'Simple tasks (weather, time, basic queries)'
  },
  long_context: {
    primary: 'openrouter/meta-llama/llama-4-maverick',
    fallback: 'openrouter/qwen/qwen3-235b-a22b-2507',
    description: 'Long context tasks (RAG, documents)'
  },
  complex_logic: {
    primary: 'openai/gpt-5.6-sol',
    fallback: 'openai/gpt-5.6-terra',
    description: 'Complex logic (code, reasoning)'
  },
  web_agents: {
    primary: 'openrouter/moonshotai/kimi-k3',
    fallback: 'openrouter/meta-llama/llama-4-maverick',
    description: 'Web agents and tool use'
  }
};

class ModelUsageSkill {
  constructor() {
    this.configPath = process.env.OPENCLAW_CONFIG || path.join(process.env.HOME, '.openclaw', 'openclaw.json');
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

  getCurrentModel() {
    const config = this.readConfig();
    if (!config) return null;
    return config.agents?.defaults?.model?.primary || 'openrouter/auto';
  }

  getModels() {
    const config = this.readConfig();
    if (!config) throw new Error('Model configuration is unavailable');
    const modelConfig = config.agents?.defaults?.model;
    const catalog = config.agents?.defaults?.models || {};
    if (!modelConfig?.primary || !Array.isArray(modelConfig.fallbacks)) {
      throw new Error('General primary/fallback model configuration is invalid');
    }
    return [...new Set([modelConfig.primary, ...modelConfig.fallbacks])]
      .filter(id => !id.startsWith('anthropic/'))
      .map(id => ({ id, name: catalog[id]?.alias || id }));
  }

  listModels(provider = null) {
    console.log('\n📊 Available Models\n');
    this.getModels().forEach(model => console.log(`${model.id} — ${model.name}`));
    console.log('\nClaude models are agent-specific and are not listed for general use.\n');
  }

  recommendTask(taskType) {
    const rec = TASK_RECOMMENDATIONS[taskType];
    if (!rec) {
      console.log(`Unknown task type: ${taskType}`);
      console.log('Available types: simple, long_context, complex_logic, web_agents');
      return;
    }

    console.log(`\n🎯 Recommendation for: ${rec.description}\n`);
    const models = new Map(this.getModels().map(model => [model.id, model.name]));
    console.log(`Primary:   ${rec.primary} (${models.get(rec.primary) || rec.primary})`);
    console.log(`Fallback:  ${rec.fallback} (${models.get(rec.fallback) || rec.fallback})`);
    console.log();
  }

  showCurrent() {
    const current = this.getCurrentModel();
    console.log(`\n🔧 Current Model: ${current}`);
    const model = this.getModels().find(candidate => candidate.id === current);
    if (model) console.log(`   Name: ${model.name}`);
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
  list                 List all generally available models
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
