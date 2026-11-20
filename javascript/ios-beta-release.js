#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "997370a02e133093a6790d5ff33a92e07799e16a7e0e20e8af2ae84995431d0e", "source_sha256": "74168ccc75bdca2481fb7bf1298fad30cea4e5fdd917205e7f1815e86948ca0c", "target_language": "javascript"}
// ios-beta-release.sh — portiert nach javascript
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/ios-beta-release.sh
// Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

const { spawnSync } = require('child_process');
const path = require('path');

function usage() {
  console.log(`Usage:
  scripts/ios-beta-release.sh [--build-number 7]

Archives and uploads a beta-release IPA to TestFlight locally.`);
}

function main() {
  let buildNumber = process.env.IOS_BETA_BUILD_NUMBER || '';
  const rootDir = path.resolve(__dirname, '..');

  const args = process.argv.slice(2);
  let i = 0;
  while (i < args.length) {
    const arg = args[i];
    if (arg === '--') {
      i++;
    } else if (arg === '--build-number') {
      buildNumber = args[i + 1] || '';
      i += 2;
    } else if (arg === '-h' || arg === '--help') {
      usage();
      process.exit(0);
    } else {
      console.error(`Unknown argument: ${arg}`);
      usage();
      process.exit(1);
    }
  }

  const cwd = path.join(rootDir, 'apps', 'ios');
  const env = { ...process.env, IOS_BETA_BUILD_NUMBER: buildNumber };
  
  const result = spawnSync('fastlane', ['ios', 'beta'], {
    cwd,
    env,
    stdio: 'inherit'
  });

  if (result.error) {
    console.error(result.error.message);
    process.exit(1);
  }
  
  process.exit(result.status || 0);
}

main();
