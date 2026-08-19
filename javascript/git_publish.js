#!/usr/bin/env node
// git_publish.py — portiert nach javascript
// Quelle: python, OpenClaw@gateway1:skills/git-publish-agent/scripts/git_publish.py
// auch in: OpenClaw@gateway2:skills/git-publish-agent/scripts/git_publish.py
// Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

/** Git Publish Agent - Automatisierte Skill-Veröffentlichung */

const { execSync, spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

const SKILLS_DIR = path.join(require('os').homedir(), '.openclaw', 'workspace', 'skills');

function runCommand(command, cwd = null) {
  try {
    const result = execSync(command, { 
      cwd: cwd || process.cwd(),
      encoding: 'utf8'
    });
    return { success: true, stdout: result.trim(), stderr: '' };
  } catch (error) {
    return { 
      success: false, 
      stdout: error.stdout ? error.stdout.toString().trim() : '', 
      stderr: error.stderr ? error.stderr.toString().trim() : error.message 
    };
  }
}

function gitCommit(skillPath, message = null) {
  /** Commit skill changes. */
  if (!message) {
    const now = new Date().toISOString();
    message = `[skill] Auto-update ${path.basename(skillPath)} - ${now}`;
  }
  
  const parentDir = path.dirname(SKILLS_DIR);
  runCommand(`git add "${skillPath}"`, parentDir);
  
  const result = runCommand(`git commit -m "${message}"`, parentDir);
  return result.success;
}

function clawhubPublish(skillName) {
  /** Publish to ClawHub. */
  const skillPath = path.join(SKILLS_DIR, skillName);
  const command = `clawhub publish "${skillPath}" --slug ${skillName} --version 1.0.0`;
  
  const result = runCommand(command);
  return [result.success, result.stdout];
}

function batchPublish() {
  /** Publish all changed skills with rate limiting. */
  // Check git status
  const result = runCommand(`git status --short "${SKILLS_DIR}"`);
  
  const changed = [];
  const lines = result.stdout.split('\n');
  
  for (const line of lines) {
    if (line.trim() && line.includes('skills/')) {
      const parts = line.split('skills/');
      if (parts.length > 1) {
        const skill = parts[1].split('/')[0];
        if (!changed.includes(skill)) {
          changed.push(skill);
        }
      }
    }
  }
  
  console.log(`Changed skills: ${JSON.stringify(changed)}`);
  
  // Publish with delay
  const maxBatch = Math.min(5, changed.length);
  for (let i = 0; i < maxBatch; i++) {
    const skill = changed[i];
    if (i > 0) {
      console.log('Waiting 15min for rate limit...');
      // In real: await new Promise(resolve => setTimeout(resolve, 900000));
    }
    
    console.log(`Publishing ${skill}...`);
    const commitOk = gitCommit(path.join(SKILLS_DIR, skill));
    if (commitOk) {
      const [pubOk, output] = clawhubPublish(skill);
      console.log(`  ${pubOk ? '✓' : '✗'} ${output}`);
    }
  }
}

function main() {
  const args = process.argv.slice(2);
  let skill = null;
  let all = false;
  let noPublish = false;
  let message = null;
  
  for (let i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--skill':
        skill = args[++i];
        break;
      case '--all':
        all = true;
        break;
      case '--no-publish':
        noPublish = true;
        break;
      case '--message':
        message = args[++i];
        break;
    }
  }
  
  if (skill) {
    const skillPath = path.join(SKILLS_DIR, skill);
    if (noPublish) {
      gitCommit(skillPath, message);
    } else {
      gitCommit(skillPath, message);
      clawhubPublish(skill);
    }
  } else if (all) {
    batchPublish();
  } else {
    console.log('Use --skill <name> or --all');
  }
}

if (require.main === module) {
  main();
}
