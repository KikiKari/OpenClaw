#!/usr/bin/env node
const ModelUsageSkill = require('./index.js');
const skill = new ModelUsageSkill();
skill.run(process.argv.slice(2));
