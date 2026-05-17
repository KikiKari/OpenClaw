#!/usr/bin/env node
/**
 * Model Usage Skill for OpenClaw
 * Manages AI model configurations and recommendations
 */

const fs = require('fs');
const path = require('path');

// Model definitions with pricing
const MODELS = {
  'openrouter/auto': {
    name: 'OpenRouter Auto',
    promptPrice: 'Auto',
    completionPrice: 'Auto',
    context: 'Variable',
    thinking: 'off'
  },
  'moonshotai/kimi-k2.5': {
    name: 'Kimi K2.5',
    promptPrice: 0.57,
    completionPrice: 2.30,
    context: '131K',
    thinking: 'off'
  },
  'meta-llama/llama-4-maverick': {
    name: 'Llama 4 Maverick',
    promptPrice: 0.15,
    completionPrice: 0.60,
    context: '1M',
    thinking: 'off'
  },
  'openai/gpt-4.1': {
    name: 'GPT-4.1',
    promptPrice: 2.00,
    completionPrice: 8.00,
    context: '1M',
    thinking: 'off'
  },
  'deepseek/deepseek-r1-0528': {
    name: 'DeepSeek R1',
    promptPrice: 0.45,
    completionPrice: 2.15,
    context: '164K',
    thinking: 'on'
  },
  'anthropic/claude-opus-4': {
    name: 'Claude Opus 4',
    promptPrice: 15.00,
    completionPrice: 75.00,
    context: '200K',
    thinking: 'on'
  },
  'qwen/qwen3-235b-a22b-2507': {
    name: 'Qwen3 235B',
    promptPrice: 0.07,
    completionPrice: 0.10,
    context: '131K',
    thinking: 'off'
  }
};

// Task recommendations
const TASK_RECOMMENDATIONS = {
  simple: {
    primary: 'moonshotai/kimi-k2.5',
    fallback: 'meta-llama/llama-4-maverick',
    description: 'Simple tasks (weather, time, basic queries)'
  },
  long_context: {
    primary: 'meta-llama/llama-4-maverick',
    fallback: 'openai/gpt-4.1',
    description: 'Long context tasks (RAG, documents)'
  },
  complex_logic: {
    primary: 'deepseek/deepseek-r1-0528',
    fallback: 'anthropic/claude-opus-4',
    description: 'Complex logic (code, reasoning)'
  },
  web_agents: {
    primary: 'moonshotai/kimi-k2.5',
    fallback: 'qwen/qwen3-235b-a22b-2507',
    description: 'Web agents and tool use'
  }
};

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

  getCurrentModel() {
    const config = this.readConfig();
    if (!config) return null;
    return config.agents?.defaults?.model?.primary || 'openrouter/auto';
  }

  listModels(provider = null) {
    console.log('\n📊 Available Models\n');
    console.log('Model                           | Prompt  | Completion | Context | Thinking');
    console.log('--------------------------------|---------|------------|---------|----------');
    
    Object.entries(MODELS).forEach(([id, model]) => {
      const name = model.name.padEnd(31);
      const prompt = String(model.promptPrice).padEnd(7);
      const completion = String(model.completionPrice).padEnd(10);
      const context = model.context.padEnd(7);
      const thinking = model.thinking;
      console.log(`${name}| ${prompt} | ${completion} | ${context} | ${thinking}`);
    });
    
    console.log('\nPrices per 1M tokens (USD)\n');
  }

  recommendTask(taskType) {
    const rec = TASK_RECOMMENDATIONS[taskType];
    if (!rec) {
      console.log(`Unknown task type: ${taskType}`);
      console.log('Available types: simple, long_context, complex_logic, web_agents');
      return;
    }

    console.log(`\n🎯 Recommendation for: ${rec.description}\n`);
    console.log(`Primary:   ${rec.primary} (${MODELS[rec.primary]?.name})`);
    console.log(`Fallback:  ${rec.fallback} (${MODELS[rec.fallback]?.name})`);
    console.log();
  }

  showCurrent() {
    const current = this.getCurrentModel();
    console.log(`\n🔧 Current Model: ${current}`);
    const model = MODELS[current];
    if (model) {
      console.log(`   Name: ${model.name}`);
      console.log(`   Prompt: $${model.promptPrice}/1M tokens`);
      console.log(`   Completion: $${model.completionPrice}/1M tokens`);
      console.log(`   Context: ${model.context}`);
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
