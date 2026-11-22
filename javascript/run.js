#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "f318fcb41bde9b2bb13cbe3206173dffc6eae704d47229d1319afd861da01a70", "source_sha256": "9bab70cc20775da1defcfadbbbef9ceb0f983a51d1a3988a76a20843d64c8471", "target_language": "javascript"}
// run.sh — portiert nach javascript
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/docker/install-sh-nonroot/run.sh
// Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

'use strict';

const { spawnSync, execSync } = require('child_process');
const { createInterface } = require('readline');
const fs = require('fs');
const path = require('path');

const INSTALL_URL = process.env.OPENCLAW_INSTALL_URL || 'https://openclaw.bot/install.sh';
const DEFAULT_PACKAGE = 'openclaw';
const PACKAGE_NAME = process.env.OPENCLAW_INSTALL_PACKAGE || DEFAULT_PACKAGE;
const SCRIPT_DIR = path.dirname(fs.realpathSync(__filename));

// Load verify functions from cli-verify.js
const cliVerifyPath = path.join(SCRIPT_DIR, '../install-sh-common/cli-verify.js');
if (!fs.existsSync(cliVerifyPath)) {
  console.error(`Missing required file: ${cliVerifyPath}`);
  process.exit(1);
}

const { quietNpm, verifyInstalledCli } = require(cliVerifyPath);

console.log('==> Pre-flight: ensure git absent');
try {
  execSync('git --version', { stdio: 'ignore' });
  console.error('git is present unexpectedly');
  process.exit(1);
} catch (error) {
  // Expected: git should not be present
}

console.log('==> Pre-flight: ensure supported Node is already present');
const nodeVersion = process.versions.node.split('.').map(Number);
const isSupportedNode =
  nodeVersion.length >= 2 &&
  (nodeVersion[0] > 22 || (nodeVersion[0] === 22 && nodeVersion[1] >= 16));

if (!isSupportedNode) {
  console.error(`unsupported node ${process.versions.node}`);
  process.exit(1);
}

try {
  execSync('npm --version', { stdio: 'ignore' });
} catch (error) {
  console.error('npm not found');
  process.exit(1);
}

console.log('==> Run installer (non-root user)');
const curlResult = spawnSync('curl', ['-fsSL', INSTALL_URL], { stdio: 'pipe' });
if (curlResult.status !== 0) {
  console.error('Failed to download installer script');
  process.exit(1);
}

const bashResult = spawnSync('bash', { 
  input: curlResult.stdout,
  stdio: ['pipe', 'inherit', 'inherit']
});

if (bashResult.status !== 0) {
  console.error('Installer script failed');
  process.exit(1);
}

// Ensure PATH picks up user npm prefix
process.env.PATH = `${process.env.HOME}/.npm-global/bin:${process.env.PATH}`;

console.log('==> Verify git installed');
try {
  execSync('git --version', { stdio: 'ignore' });
} catch (error) {
  console.error('git installation verification failed');
  process.exit(1);
}

const EXPECTED_VERSION = process.env.OPENCLAW_INSTALL_EXPECT_VERSION || '';
let LATEST_VERSION;

if (EXPECTED_VERSION) {
  LATEST_VERSION = EXPECTED_VERSION;
} else {
  LATEST_VERSION = quietNpm(['view', PACKAGE_NAME, 'version']);
}

console.log('==> Verify CLI installed');
verifyInstalledCli(PACKAGE_NAME, LATEST_VERSION);

console.log('OK');
