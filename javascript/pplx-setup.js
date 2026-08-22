#!/usr/bin/env node
// pplx-setup.sh — portiert nach javascript
// Quelle: shell, OpenClaw@main:scripts/pplx-tools/pplx-setup.sh
// Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

// One-time (idempotent): make sure the Perplexity VS Code extension daemon can
// find a Chromium. The daemon uses its OWN bundled patchright, which pins a
// specific chromium revision; install exactly that revision.
'use strict';

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

function findExtensionPatchright() {
  const extensionsDir = path.join(process.env.HOME, '.vscode-remote', 'extensions');
  if (!fs.existsSync(extensionsDir)) {
    return null;
  }

  const extDirs = fs.readdirSync(extensionsDir)
    .filter(dir => dir.startsWith('nskha.perplexity-vscode-'))
    .map(dir => path.join(extensionsDir, dir))
    .filter(dir => fs.statSync(dir).isDirectory());

  if (extDirs.length === 0) {
    return null;
  }

  // Sort by version and get latest
  extDirs.sort((a, b) => {
    const verA = a.split('-').pop();
    const verB = b.split('-').pop();
    return verA.localeCompare(verB, undefined, { numeric: true });
  });

  const latestExtDir = extDirs[extDirs.length - 1];
  const patchrightPath = path.join(latestExtDir, 'dist', 'node_modules', 'patchright');

  if (fs.existsSync(patchrightPath)) {
    return patchrightPath;
  }

  return null;
}

function getChromiumExecutablePath(patchrightPath) {
  try {
    const chromiumModulePath = path.join(patchrightPath, 'lib', 'cjs', 'third_party', 'chromium', 'chromium.js');
    if (fs.existsSync(chromiumModulePath)) {
      const chromiumModule = require(chromiumModulePath);
      return chromiumModule.chromium.executablePath();
    }
    
    // Fallback to direct require
    const { chromium } = require(patchrightPath);
    return chromium.executablePath();
  } catch (error) {
    return null;
  }
}

function main() {
  const extPR = findExtensionPatchright();
  if (!extPR) {
    console.log('[setup] extension patchright not found — is the Perplexity extension installed?');
    process.exit(0);
  }

  const exp = getChromiumExecutablePath(extPR);
  if (exp && fs.existsSync(exp) && fs.statSync(exp).mode & fs.constants.X_OK) {
    console.log(`[setup] daemon browser already present: ${exp}`);
    process.exit(0);
  }

  console.log(`[setup] installing matching chromium for the extension daemon (expected: ${exp || 'unknown'})...`);
  try {
    execSync(`node "${path.join(extPR, 'cli.js')}" install chromium`, { stdio: 'inherit' });
    console.log('[setup] done.');
  } catch (error) {
    console.error('[setup] failed to install chromium:', error.message);
    process.exit(1);
  }
}

main();
