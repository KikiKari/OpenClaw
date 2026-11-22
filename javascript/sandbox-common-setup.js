#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "f98c12435fe91e0944b272f698e986de1e7175cc5ccf3b5b6c9ede09d8c4524b", "source_sha256": "b31f1bce542d41c8328b88079d7d58fa9d018f246f3f05fa532df8fe4ef6e153", "target_language": "javascript"}
// sandbox-common-setup.sh — portiert nach javascript
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/sandbox-common-setup.sh
// Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

const { spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// Environment variables with defaults
const BASE_IMAGE = process.env.BASE_IMAGE || 'openclaw-sandbox:bookworm-slim';
const TARGET_IMAGE = process.env.TARGET_IMAGE || 'openclaw-sandbox-common:bookworm-slim';
const PACKAGES = process.env.PACKAGES || 'curl wget jq coreutils grep nodejs npm python3 git ca-certificates golang-go rustc cargo unzip pkg-config libasound2-dev build-essential file';
const INSTALL_PNPM = process.env.INSTALL_PNPM || '1';
const INSTALL_BUN = process.env.INSTALL_BUN || '1';
const BUN_INSTALL_DIR = process.env.BUN_INSTALL_DIR || '/opt/bun';
const INSTALL_BREW = process.env.INSTALL_BREW || '1';
const BREW_INSTALL_DIR = process.env.BREW_INSTALL_DIR || '/home/linuxbrew/.linuxbrew';
const FINAL_USER = process.env.FINAL_USER || 'sandbox';
const OPENCLAW_DOCKER_BUILD_USE_BUILDX = process.env.OPENCLAW_DOCKER_BUILD_USE_BUILDX || '0';
const OPENCLAW_DOCKER_BUILD_CACHE_FROM = process.env.OPENCLAW_DOCKER_BUILD_CACHE_FROM || '';
const OPENCLAW_DOCKER_BUILD_CACHE_TO = process.env.OPENCLAW_DOCKER_BUILD_CACHE_TO || '';

// Check if base image exists
const inspectResult = spawnSync('docker', ['image', 'inspect', BASE_IMAGE], {
  stdio: 'pipe'
});

if (inspectResult.status !== 0) {
  console.log(`Base image missing: ${BASE_IMAGE}`);
  console.log('Building base image via scripts/sandbox-setup.sh...');
  
  const setupScriptPath = path.join('scripts', 'sandbox-setup.sh');
  const setupResult = spawnSync('bash', [setupScriptPath], {
    stdio: 'inherit'
  });
  
  if (setupResult.status !== 0) {
    process.exit(setupResult.status);
  }
}

console.log(`Building ${TARGET_IMAGE} with: ${PACKAGES}`);

let buildCmd = ['docker', 'build'];

if (OPENCLAW_DOCKER_BUILD_USE_BUILDX === '1') {
  buildCmd = ['docker', 'buildx', 'build', '--load'];
  
  if (OPENCLAW_DOCKER_BUILD_CACHE_FROM) {
    buildCmd.push('--cache-from', OPENCLAW_DOCKER_BUILD_CACHE_FROM);
  }
  
  if (OPENCLAW_DOCKER_BUILD_CACHE_TO) {
    buildCmd.push('--cache-to', OPENCLAW_DOCKER_BUILD_CACHE_TO);
  }
}

const buildArgs = [
  '-t', TARGET_IMAGE,
  '-f', 'Dockerfile.sandbox-common',
  '--build-arg', `BASE_IMAGE=${BASE_IMAGE}`,
  '--build-arg', `PACKAGES=${PACKAGES}`,
  '--build-arg', `INSTALL_PNPM=${INSTALL_PNPM}`,
  '--build-arg', `INSTALL_BUN=${INSTALL_BUN}`,
  '--build-arg', `BUN_INSTALL_DIR=${BUN_INSTALL_DIR}`,
  '--build-arg', `INSTALL_BREW=${INSTALL_BREW}`,
  '--build-arg', `BREW_INSTALL_DIR=${BREW_INSTALL_DIR}`,
  '--build-arg', `FINAL_USER=${FINAL_USER}`,
  '.'
];

const buildProcess = spawnSync(buildCmd[0], buildCmd.slice(1).concat(buildArgs), {
  stdio: 'inherit'
});

if (buildProcess.status !== 0) {
  process.exit(buildProcess.status);
}

console.log(`
Built ${TARGET_IMAGE}.
To use it, set agents.defaults.sandbox.docker.image to "${TARGET_IMAGE}" and restart.
If you want a clean re-create, remove old sandbox containers:
  docker rm -f $(docker ps -aq --filter label=openclaw.sandbox=1)
`);
