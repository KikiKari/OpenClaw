#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "d5030b530b7157afa3aed02ea2434c6157e030b5dce82b3ee6c9c7039c58dd44", "source_sha256": "d563770ee41496760efbfdbb5c3e2c054ecf84de1c5e8eb2fc7cd2ad260b16ce", "target_language": "javascript"}
// docs-spellcheck.sh — portiert nach javascript
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/docs-spellcheck.sh
// Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

const { spawnSync, execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const mode = process.argv[2] || '';
const writeFlag = mode === '--write' ? ['-w'] : [];

const args = [
  'README.md',
  'docs',
  '--skip=*.png,*.jpg,*.jpeg,*.gif,*.svg',
  '-D',
  '-',
  '-D',
  'scripts/codespell-dictionary.txt',
  '-I',
  'scripts/codespell-ignore.txt',
  ...writeFlag
];

// Check if codespell is available in PATH
let result = spawnSync('codespell', args, { stdio: 'inherit' });
if (result.error === undefined) {
  process.exit(result.status);
}

// Check if python3 is available
try {
  execSync('python3 --version', { stdio: 'ignore' });
} catch (error) {
  console.error('codespell unavailable: install codespell or python3');
  process.exit(1);
}

// Try to install codespell via pip
try {
  execSync(
    'python3 -m pip install --user --disable-pip-version-check --break-system-packages codespell',
    { stdio: 'ignore' }
  );
} catch (error) {
  try {
    execSync(
      'python3 -m pip install --user --disable-pip-version-check codespell',
      { stdio: 'ignore' }
    );
  } catch (error) {
    console.error('codespell unavailable: install codespell or python3');
    process.exit(1);
  }
}

// Get user bin directory
const userBaseScript = `
import site
print(f"{site.USER_BASE}/bin")
`;

const userBaseResult = spawnSync('python3', ['-c', userBaseScript], {
  encoding: 'utf-8'
});

if (userBaseResult.status !== 0) {
  console.error('codespell unavailable: install codespell or python3');
  process.exit(1);
}

const userBin = userBaseResult.stdout.trim();
const codespellPath = path.join(userBin, 'codespell');

if (fs.existsSync(codespellPath) && fs.statSync(codespellPath).isFile()) {
  const finalResult = spawnSync(codespellPath, args, { stdio: 'inherit' });
  process.exit(finalResult.status);
}

console.error('codespell unavailable: install codespell or python3');
process.exit(1);
