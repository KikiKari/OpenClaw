#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "790b62e3a8e2f4266c8c94fdc05f30c0025c192931dc1165570f202c2b24f63b", "source_sha256": "2cdcdc862375b173b06398d139b611f6f002e0435191f56d26d3e48a3cef02cf", "target_language": "javascript"}
// ios-beta-archive.sh — portiert nach javascript
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/ios-beta-archive.sh
// Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

function usage() {
  console.log(`Usage:
  scripts/ios-beta-archive.sh [--build-number 7]

Archives and exports a beta-release IPA locally without uploading.`);
}

function main() {
  let BUILD_NUMBER = process.env.IOS_BETA_BUILD_NUMBER || '';
  const ROOT_DIR = path.resolve(__dirname, '..');
  
  const args = process.argv.slice(2);
  let i = 0;
  
  while (i < args.length) {
    const arg = args[i];
    
    switch (arg) {
      case '--':
        i++;
        break;
      case '--build-number':
        BUILD_NUMBER = args[i + 1] || '';
        i += 2;
        break;
      case '-h':
      case '--help':
        usage();
        process.exit(0);
        break;
      default:
        if (arg.startsWith('-')) {
          console.error(`Unknown argument: ${arg}`);
          usage();
          process.exit(1);
        }
        i++;
        break;
    }
  }
  
  const cwd = path.join(ROOT_DIR, 'apps', 'ios');
  
  const env = { ...process.env };
  if (BUILD_NUMBER) {
    env.IOS_BETA_BUILD_NUMBER = BUILD_NUMBER;
  }
  
  const result = spawnSync('fastlane', ['ios', 'beta_archive'], {
    cwd,
    env,
    stdio: 'inherit'
  });
  
  if (result.error) {
    console.error('Failed to execute fastlane:', result.error.message);
    process.exit(1);
  }
  
  process.exit(result.status || 0);
}

main();
