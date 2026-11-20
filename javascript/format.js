#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "87df1a764cef741574a3bd60c126c1c2fcf173f1c4e4be9335265dca064981cc", "source_sha256": "ed82b1410f121f3b1436d54099143d7010035ba702c64f21d2669fce9dd3f2ae", "target_language": "javascript"}
// format.sh — portiert nach javascript
// Quelle: shell, workspace@local:skills/github-clones/openclaw/Swabble/scripts/format.sh
// Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

const { execSync } = require('child_process');
const path = require('path');

// Set strict mode equivalent
'use strict';

// Get root directory (equivalent to $(cd "$(dirname "$0")/.." && pwd))
const __filename = process.argv[1];
const __dirname = path.dirname(__filename);
const ROOT = path.resolve(__dirname, '..');

// Define config and sources paths
const CONFIG = path.join(ROOT, '.swiftformat');
const SOURCES = path.join(ROOT, 'Sources');

try {
  // Execute swiftformat with config and sources arguments
  execSync(`swiftformat --config "${CONFIG}" "${SOURCES}"`, { 
    stdio: 'inherit',
    shell: true
  });
} catch (error) {
  console.error('Error executing swiftformat:', error.message);
  process.exit(1);
}
