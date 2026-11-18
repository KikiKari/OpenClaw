#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "13b152f8d57bdbdb2b3d6fb92371bb752694bd48b8446445959c00ee429c3a11", "source_sha256": "d32ac11e0dc05ad59745834c2a59aec92d846417b8f7f07d0d21d66ae469c743", "target_language": "javascript"}
// pplx-setup.sh — portiert nach javascript
// Quelle: shell, OpenClaw@main:scripts/pplx-tools/pplx-setup.sh
// Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

// One-time (idempotent): make sure the Perplexity VS Code extension daemon can
// find a Chromium. The daemon uses its OWN bundled patchright, which pins a
// specific chromium revision; install exactly that revision.

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

function findExtensionPatchright() {
  const extensionsDir = path.join(process.env.HOME, '.vscode-remote', 'extensions');
  try {
    const files = fs.readdirSync(extensionsDir);
    const patchrightDirs = files
      .filter(file => file.startsWith('nskha.perplexity-vscode-'))
      .map(dir => path.join(extensionsDir, dir, 'dist', 'node_modules', 'patchright'))
      .filter(dir => fs.existsSync(dir));
    
    if (patchrightDirs.length === 0) return null;
    
    // Sort by version and return the latest
    return patchrightDirs.sort().pop();
  } catch (error) {
    return null;
  }
}

const extPR = findExtensionPatchright();
if (!extPR) {
  console.log('[setup] extension patchright not found — is the Perplexity extension installed?');
  process.exit(0);
}

let exp = '';
try {
  const chromiumPath = execSync(`node -e "const {chromium}=require('${extPR}');console.log(chromium.executablePath())"`, {
    stdio: ['pipe', 'pipe', 'ignore']
  }).toString().trim();
  
  if (fs.existsSync(chromiumPath) && fs.statSync(chromiumPath).isFile()) {
    exp = chromiumPath;
  }
} catch (error) {
  // Ignore errors
}

if (exp) {
  console.log(`[setup] daemon browser already present: ${exp}`);
  process.exit(0);
}

console.log(`[setup] installing matching chromium for the extension daemon (expected: ${exp || 'unknown'})...`);
execSync(`node "${path.join(extPR, 'cli.js')}" install chromium`, { stdio: 'inherit' });
console.log('[setup] done.');
