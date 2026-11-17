#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "1e9133b0724991278578f3719ca391e8d1e365d524ef19288d105385913bc33c", "source_sha256": "4c10c6b6fd911cb95da119f761f402073d1a836cab6b40a9f3b989536d5df5ec", "target_language": "javascript"}
// git_publish.py — portiert nach javascript
// Quelle: python, OpenClaw@gateway1:skills/git-publish-agent/scripts/git_publish.py
// auch in: OpenClaw@gateway2:skills/git-publish-agent/scripts/git_publish.py
// Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

import { spawnSync } from 'child_process';
import { homedir } from 'os';
import { join } from 'path';
import { readFileSync } from 'fs';

const SKILLS_DIR = join(homedir(), '.openclaw', 'workspace', 'skills');

function gitCommit(skillPath, message = null) {
  // Commit skill changes.
  if (!message) {
    const now = new Date().toISOString();
    message = `[skill] Auto-update ${skillPath.name} - ${now}`;
  }

  spawnSync('git', ['add', skillPath], { cwd: join(SKILLS_DIR, '..') });
  const result = spawnSync(
    'git', ['commit', '-m', message],
    { cwd: join(SKILLS_DIR, '..'), encoding: 'utf8' }
  );
  return result.status === 0;
}

function clawhubPublish(skillName) {
  // Publish to ClawHub.
  const skillPath = join(SKILLS_DIR, skillName);
  const result = spawnSync(
    'clawhub', ['publish', skillPath,
      '--slug', skillName,
      '--version', '1.0.0'],
    { encoding: 'utf8' }
  );
  return [result.status === 0, result.stdout];
}

function batchPublish() {
  // Publish all changed skills with rate limiting.
  // Check git status
  const result = spawnSync(
    'git', ['status', '--short', SKILLS_DIR],
    { encoding: 'utf8' }
  );

  const changed = [];
  for (const line of result.stdout.split('\n')) {
    if (line.trim() && line.includes('skills/')) {
      const skill = line.split('skills/')[1].split('/')[0];
      if (!changed.includes(skill)) {
        changed.push(skill);
      }
    }
  }

  console.log(`Changed skills: ${JSON.stringify(changed)}`);

  // Publish with delay
  const batch = changed.slice(0, 5); // Max 5 per batch
  for (let i = 0; i < batch.length; i++) {
    const skill = batch[i];
    if (i > 0) {
      console.log('Waiting 15min for rate limit...');
      // In real: await new Promise(resolve => setTimeout(resolve, 900000));
    }

    console.log(`Publishing ${skill}...`);
    const commitOk = gitCommit(join(SKILLS_DIR, skill));
    if (commitOk) {
      const [pubOk, output] = clawhubPublish(skill);
      console.log(`  ${pubOk ? '✓' : '✗'} ${output}`);
    }
  }
}

function main() {
  const args = process.argv.slice(2);
  let skillName = null;
  let noPublish = false;
  let message = null;
  let publishAll = false;

  for (let i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--skill':
        skillName = args[++i];
        break;
      case '--no-publish':
        noPublish = true;
        break;
      case '--message':
        message = args[++i];
        break;
      case '--all':
        publishAll = true;
        break;
    }
  }

  if (skillName) {
    const skillPath = join(SKILLS_DIR, skillName);
    if (noPublish) {
      gitCommit(skillPath, message);
    } else {
      gitCommit(skillPath, message);
      clawhubPublish(skillName);
    }
  } else if (publishAll) {
    batchPublish();
  } else {
    console.log('Use --skill <name> or --all');
  }
}

main();
