#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "6e5962b10d71ffb3c80a436a4471a831e54929118995910b484ca871c475cb35", "source_sha256": "53a6908a18055c2a46b63b5da3ddbf4ea5f6b1867c1482c1dcc8903c3ab7b89a", "target_language": "javascript"}
// setup.sh — portiert nach javascript
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/podman/setup.sh
// Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

// One-time host setup for rootless OpenClaw in Podman. Uses the current
// non-root user throughout, builds or pulls the image into that user's Podman
// store, writes config under ~/.openclaw by default, and uses the repo-local
// launch script at ./scripts/run-openclaw-podman.sh.
//
// Usage: ./scripts/podman/setup.js [--quadlet|--container]
//   --quadlet   Install a Podman Quadlet as the current user's systemd service
//   --container Only install image + config; you start the container manually (default)
//   Or set OPENCLAW_PODMAN_QUADLET=1 (or 0) to choose without a flag.
//
// After this, start the gateway manually:
//   ./scripts/run-openclaw-podman.js launch
//   ./scripts/run-openclaw-podman.js launch setup
// Or, if you used --quadlet:
//   systemctl --user start openclaw.service

import fs from 'fs';
import os from 'os';
import path from 'path';
import { spawnSync, execSync } from 'child_process';

const REPO_PATH = process.env.OPENCLAW_REPO_PATH || path.resolve(new URL('.', import.meta.url).pathname, '../../..');
const RUN_SCRIPT_SRC = path.join(REPO_PATH, 'scripts', 'run-openclaw-podman.js');
const QUADLET_TEMPLATE = path.join(REPO_PATH, 'scripts', 'podman', 'openclaw.container.in');
const OPENCLAW_USER = os.userInfo().username;
const OPENCLAW_HOME = process.env.HOME || '';
const OPENCLAW_CONFIG_DIR = process.env.OPENCLAW_CONFIG_DIR || path.join(OPENCLAW_HOME, '.openclaw');
const OPENCLAW_WORKSPACE_DIR = process.env.OPENCLAW_WORKSPACE_DIR || path.join(OPENCLAW_CONFIG_DIR, 'workspace');
const OPENCLAW_IMAGE = process.env.OPENCLAW_PODMAN_IMAGE || process.env.OPENCLAW_IMAGE || 'openclaw:local';
const OPENCLAW_CONTAINER_NAME = process.env.OPENCLAW_PODMAN_CONTAINER || 'openclaw';
const PLATFORM_NAME = os.platform();
const HOST_GATEWAY_PORT = process.env.OPENCLAW_PODMAN_GATEWAY_HOST_PORT || process.env.OPENCLAW_GATEWAY_PORT || '18789';
const QUADLET_GATEWAY_PORT = '18789';

function requireCmd(cmd) {
  try {
    execSync(`which ${cmd}`, { stdio: 'ignore' });
  } catch (error) {
    console.error(`Missing dependency: ${cmd}`);
    process.exit(1);
  }
}

function isRoot() {
  return process.getuid() === 0;
}

function fail(message) {
  console.error(message);
  process.exit(1);
}

function validateSingleLineValue(label, value) {
  if (value.includes('\n') || value.includes('\r')) {
    fail(`Invalid ${label}: control characters are not allowed.`);
  }
}

function validateAbsolutePath(label, value) {
  validateSingleLineValue(label, value);
  if (!path.isAbsolute(value)) {
    fail(`Invalid ${label}: expected an absolute path.`);
  }
  if (value.includes('//')) {
    fail(`Invalid ${label}: repeated slashes are not allowed.`);
  }
  const parts = value.split('/').filter(p => p !== '');
  if (parts.includes('.') || parts.includes('..')) {
    fail(`Invalid ${label}: dot path segments are not allowed.`);
  }
}

function validateMountSourcePath(label, value) {
  validateAbsolutePath(label, value);
  if (value.includes(':')) {
    fail(`Invalid ${label}: ':' is not allowed in Podman bind-mount source paths.`);
  }
}

function validateContainerName(value) {
  validateSingleLineValue('container name', value);
  if (!/^[A-Za-z0-9][A-Za-z0-9_.-]*$/.test(value)) {
    fail(`Invalid container name: ${value}`);
  }
}

function validateImageName(value) {
  validateSingleLineValue('image name', value);
  const forbiddenPrefixes = ['oci-archive:', 'docker-archive:', 'dir:', 'oci:', 'containers-storage:', 'docker-daemon:', 'archive:'];
  for (const prefix of forbiddenPrefixes) {
    if (value.startsWith(prefix)) {
      fail(`Invalid image name: transport prefixes are not allowed: ${value}`);
    }
  }
  if (!/^[A-Za-z0-9][A-Za-z0-9._/:@-]*$/.test(value)) {
    fail(`Invalid image name: ${value}`);
  }
}

function ensureSafeExistingDir(label, dir) {
  validateAbsolutePath(label, dir);
  if (!fs.existsSync(dir)) {
    fail(`Missing ${label}: ${dir}`);
  }
  const stats = fs.lstatSync(dir);
  if (stats.isSymbolicLink()) {
    fail(`Unsafe ${label}: symlinks are not allowed (${dir})`);
  }
}

function statUid(filePath) {
  const stats = fs.statSync(filePath);
  return stats.uid;
}

function statMode(filePath) {
  const stats = fs.statSync(filePath);
  return (stats.mode & 0o777).toString(8);
}

function ensurePrivateExistingDirOwnedByUser(label, dir) {
  ensureSafeExistingDir(label, dir);
  const uid = statUid(dir);
  if (uid !== process.getuid()) {
    fail(`Unsafe ${label}: not owned by current user (${dir})`);
  }
  const mode = parseInt(statMode(dir), 8);
  if ((mode & 0o022) !== 0) {
    fail(`Unsafe ${label}: group/other writable (${dir})`);
  }
}

function ensureSafeWriteFilePath(label, filePath) {
  validateAbsolutePath(label, filePath);
  if (fs.existsSync(filePath)) {
    const stats = fs.lstatSync(filePath);
    if (stats.isSymbolicLink()) {
      fail(`Unsafe ${label}: symlinks are not allowed (${filePath})`);
    }
    if (!stats.isFile()) {
      fail(`Unsafe ${label}: expected a regular file (${filePath})`);
    }
  }
  const dir = path.dirname(filePath);
  ensureSafeExistingDir(`${label} parent directory`, dir);
}

function writeFileAtomically(filePath, mode, content) {
  ensureSafeWriteFilePath('output file', filePath);
  const dir = path.dirname(filePath);
  const tmp = fs.mkdtempSync(path.join(dir, '.tmp.'));
  fs.writeFileSync(tmp, content, { mode: parseInt(mode, 8) });
  fs.renameSync(tmp, filePath);
}

function validatePort(label, value) {
  if (!/^[0-9]{1,5}$/.test(value)) {
    fail(`Invalid ${label}: must be numeric.`);
  }
  const numeric = parseInt(value, 10);
  if (numeric < 1 || numeric > 65535) {
    fail(`Invalid ${label}: out of range.`);
  }
}

function escapeSedReplacementPipeDelim(str) {
  return str.replace(/[\\&|]/g, '\\$&');
}

function resolveUserHome(user) {
  try {
    const result = execSync(`getent passwd ${user}`, { encoding: 'utf-8' });
    const parts = result.trim().split(':');
    if (parts.length >= 6) {
      return parts[5];
    }
  } catch (error) {
    // ignore
  }
  
  if (fs.existsSync('/etc/passwd')) {
    try {
      const content = fs.readFileSync('/etc/passwd', 'utf-8');
      const lines = content.split('\n');
      for (const line of lines) {
        const parts = line.split(':');
        if (parts[0] === user && parts.length >= 6) {
          return parts[5];
        }
      }
    } catch (error) {
      // ignore
    }
  }
  
  return `/home/${user}`;
}

function generateTokenHex32() {
  try {
    const result = execSync('openssl rand -hex 32', { encoding: 'utf-8' });
    return result.trim();
  } catch (error) {
    // ignore
  }
  
  try {
    const result = execSync('python3 -c "import secrets; print(secrets.token_hex(32))"', { encoding: 'utf-8' });
    return result.trim();
  } catch (error) {
    // ignore
  }
  
  try {
    const result = execSync('od -An -N32 -tx1 /dev/urandom', { encoding: 'utf-8' });
    return result.replace(/\s/g, '');
  } catch (error) {
    // ignore
  }
  
  console.error('Missing dependency: need openssl or python3 (or od) to generate OPENCLAW_GATEWAY_TOKEN.');
  process.exit(1);
}

function seedLocalControlUiOrigins(file, port) {
  ensureSafeWriteFilePath('config file', file);
  if (!fs.existsSync('/usr/bin/python3') && !fs.existsSync('/bin/python3')) {
    console.warn(`Warning: python3 not found; unable to seed gateway.controlUi.allowedOrigins in ${file}.`);
    return;
  }
  
  let content;
  try {
    content = fs.readFileSync(file, 'utf-8');
  } catch (error) {
    console.warn(`Warning: unable to read config file ${file}: ${error.message}`);
    return;
  }
  
  try {
    const data = JSON.parse(content);
    if (typeof data !== 'object' || data === null) {
      throw new Error(`${file}: expected top-level object`);
    }
    
    const gateway = data.gateway || (data.gateway = {});
    if (typeof gateway !== 'object' || gateway === null) {
      throw new Error(`${file}: expected gateway object`);
    }
    
    gateway.mode = gateway.mode || 'local';
    const controlUi = gateway.controlUi || (gateway.controlUi = {});
    if (typeof controlUi !== 'object' || controlUi === null) {
      throw new Error(`${file}: expected gateway.controlUi object`);
    }
    
    let allowed = controlUi.allowedOrigins;
    if (!Array.isArray(allowed)) {
      allowed = [];
    }
    
    const managedLocalhosts = new Set(['127.0.0.1', 'localhost']);
    const desired = [
      `http://127.0.0.1:${port}`,
      `http://localhost:${port}`
    ];
    
    const cleaned = [];
    for (const origin of allowed) {
      if (typeof origin !== 'string') continue;
      const normalized = origin.trim();
      if (!normalized) continue;
      
      if (normalized.startsWith('http://')) {
        const hostPort = normalized.substring(7);
        const host = hostPort.split(':')[0];
        if (managedLocalhosts.has(host)) continue;
      }
      
      cleaned.push(normalized);
    }
    
    controlUi.allowedOrigins = [...cleaned, ...desired];
    
    const dir = path.dirname(file);
    const tmp = fs.mkdtempSync(path.join(dir, '.config.tmp.'));
    fs.writeFileSync(tmp, JSON.stringify(data, null, 2) + '\n', { mode: 0o600 });
    fs.renameSync(tmp, file);
  } catch (error) {
    console.warn(`Warning: unable to seed gateway.controlUi.allowedOrigins in ${file}: ${error.message}. Leaving file unchanged.`);
  }
}

function upsertEnvVar(file, key, value) {
  ensureSafeWriteFilePath('env file', file);
  let content = '';
  if (fs.existsSync(file)) {
    content = fs.readFileSync(file, 'utf-8');
  }
  
  const lines = content.split('\n');
  let found = false;
  const newLines = [];
  
  for (const line of lines) {
    if (line.startsWith(`${key}=`)) {
      newLines.push(`${key}=${value}`);
      found = true;
    } else {
      newLines.push(line);
    }
  }
  
  if (!found) {
    newLines.push(`${key}=${value}`);
  }
  
  fs.writeFileSync(file, newLines.filter(l => l).join('\n') + '\n', { mode: 0o600 });
}

let INSTALL_QUADLET = false;
for (const arg of process.argv.slice(2)) {
  if (arg === '--quadlet') {
    INSTALL_QUADLET = true;
  } else if (arg === '--container') {
    INSTALL_QUADLET = false;
  }
}

if (process.env.OPENCLAW_PODMAN_QUADLET !== undefined) {
  const val = process.env.OPENCLAW_PODMAN_QUADLET.toLowerCase();
  if (['1', 'yes', 'true'].includes(val)) {
    INSTALL_QUADLET = true;
  } else if (['0', 'no', 'false'].includes(val)) {
    INSTALL_QUADLET = false;
  }
}

if (INSTALL_QUADLET && PLATFORM_NAME !== 'linux') {
  fail('--quadlet is only supported on Linux with systemd user services.');
}

const SEED_GATEWAY_PORT = INSTALL_QUADLET ? QUADLET_GATEWAY_PORT : HOST_GATEWAY_PORT;

requireCmd('podman');
if (isRoot()) {
  console.error('Run scripts/podman/setup.js as your normal user so Podman stays rootless.');
  process.exit(1);
}

if (OPENCLAW_IMAGE === 'openclaw:local' && !fs.existsSync(path.join(REPO_PATH, 'Dockerfile'))) {
  console.error(`Dockerfile not found at ${REPO_PATH}. Set OPENCLAW_REPO_PATH to the repo root.`);
  process.exit(1);
}

if (!fs.existsSync(RUN_SCRIPT_SRC)) {
  console.error(`Launch script not found at ${RUN_SCRIPT_SRC}.`);
  process.exit(1);
}

let resolvedHome = OPENCLAW_HOME;
if (!resolvedHome) {
  resolvedHome = resolveUserHome(OPENCLAW_USER);
}
if (!resolvedHome) {
  console.error(`Unable to resolve HOME for user ${OPENCLAW_USER}.`);
  process.exit(1);
}

let configDir = OPENCLAW_CONFIG_DIR;
if (!configDir) {
  configDir = path.join(resolvedHome, '.openclaw');
}

let workspaceDir = OPENCLAW_WORKSPACE_DIR;
if (!workspaceDir) {
  workspaceDir = path.join(configDir, 'workspace');
}

validateAbsolutePath('home directory', resolvedHome);
validateMountSourcePath('config directory', configDir);
validateMountSourcePath('workspace directory', workspaceDir);
validateContainerName(OPENCLAW_CONTAINER_NAME);
validateImageName(OPENCLAW_IMAGE);
validatePort('gateway host port', HOST_GATEWAY_PORT);
validatePort('seed gateway port', SEED_GATEWAY_PORT);

fs.mkdirSync(configDir, { recursive: true, mode: 0o700 });
fs.mkdirSync(workspaceDir, { recursive: true, mode: 0o700 });
ensurePrivateExistingDirOwnedByUser('config directory', configDir);
ensurePrivateExistingDirOwnedByUser('workspace directory', workspaceDir);

const BUILD_ARGS = [];
if (process.env.OPENCLAW_DOCKER_APT_PACKAGES) {
  BUILD_ARGS.push('--build-arg', `OPENCLAW_DOCKER_APT_PACKAGES=${process.env.OPENCLAW_DOCKER_APT_PACKAGES}`);
}
if (process.env.OPENCLAW_EXTENSIONS) {
  BUILD_ARGS.push('--build-arg', `OPENCLAW_EXTENSIONS=${process.env.OPENCLAW_EXTENSIONS}`);
}

if (OPENCLAW_IMAGE === 'openclaw:local') {
  console.log(`Building image ${OPENCLAW_IMAGE} ...`);
  const buildArgs = ['build', '-t', OPENCLAW_IMAGE, '-f', path.join(REPO_PATH, 'Dockerfile'), ...BUILD_ARGS, REPO_PATH];
  const result = spawnSync('podman', buildArgs, { stdio: 'inherit' });
  if (result.status !== 0) {
    process.exit(result.status || 1);
  }
} else {
  const imageExists = spawnSync('podman', ['image', 'exists', OPENCLAW_IMAGE], { stdio: 'ignore' });
  if (imageExists.status === 0) {
    console.log(`Using existing image ${OPENCLAW_IMAGE}`);
  } else {
    console.log(`Pulling image ${OPENCLAW_IMAGE} ...`);
    const result = spawnSync('podman', ['pull', OPENCLAW_IMAGE], { stdio: 'inherit' });
    if (result.status !== 0) {
      process.exit(result.status || 1);
    }
  }
}

const ENV_FILE = path.join(configDir, '.env');
if (!fs.existsSync(ENV_FILE)) {
  const TOKEN = generateTokenHex32();
  writeFileAtomically(ENV_FILE, '600', `OPENCLAW_GATEWAY_TOKEN=${TOKEN}\n`);
  console.log(`Generated OPENCLAW_GATEWAY_TOKEN and wrote it to ${ENV_FILE}`);
}
upsertEnvVar(ENV_FILE, 'OPENCLAW_PODMAN_CONTAINER', OPENCLAW_CONTAINER_NAME);
upsertEnvVar(ENV_FILE, 'OPENCLAW_PODMAN_IMAGE', OPENCLAW_IMAGE);

const CONFIG_JSON = path.join(configDir, 'openclaw.json');
if (!fs.existsSync(CONFIG_JSON)) {
  const content = `{
  "gateway": {
    "mode": "local",
    "controlUi": {
      "allowedOrigins": [
        "http://127.0.0.1:${SEED_GATEWAY_PORT}",
        "http://localhost:${SEED_GATEWAY_PORT}"
      ]
    }
  }
}
`;
  writeFileAtomically(CONFIG_JSON, '600', content);
  console.log(`Wrote minimal config to ${CONFIG_JSON}`);
}
seedLocalControlUiOrigins(CONFIG_JSON, SEED_GATEWAY_PORT);

if (INSTALL_QUADLET) {
  const QUADLET_DIR = path.join(resolvedHome, '.config', 'containers', 'systemd');
  const QUADLET_DST = path.join(QUADLET_DIR, 'openclaw.container');
  console.log(`Installing Quadlet to ${QUADLET_DST} ...`);
  fs.mkdirSync(QUADLET_DIR, { recursive: true });
  ensureSafeExistingDir('quadlet directory', QUADLET_DIR);
  
  const OPENCLAW_HOME_ESCAPED = escapeSedReplacementPipeDelim(resolvedHome);
  const OPENCLAW_CONFIG_ESCAPED = escapeSedReplacementPipeDelim(configDir);
  const OPENCLAW_WORKSPACE_ESCAPED = escapeSedReplacementPipeDelim(workspaceDir);
  const OPENCLAW_IMAGE_ESCAPED = escapeSedReplacementPipeDelim(OPENCLAW_IMAGE);
  const OPENCLAW_CONTAINER_ESCAPED = escapeSedReplacementPipeDelim(OPENCLAW_CONTAINER_NAME);
  
  let templateContent = fs.readFileSync(QUADLET_TEMPLATE, 'utf-8');
  templateContent = templateContent
    .replace(/{{OPENCLAW_HOME}}/g, OPENCLAW_HOME_ESCAPED)
    .replace(/{{OPENCLAW_CONFIG_DIR}}/g, OPENCLAW_CONFIG_ESCAPED)
    .replace(/{{OPENCLAW_WORKSPACE_DIR}}/g, OPENCLAW_WORKSPACE_ESCAPED)
    .replace(/{{IMAGE_NAME}}/g, OPENCLAW_IMAGE_ESCAPED)
    .replace(/{{CONTAINER_NAME}}/g, OPENCLAW_CONTAINER_ESCAPED);
  
  writeFileAtomically(QUADLET_DST, '644', templateContent);
  
  try {
    execSync('which systemctl', { stdio: 'ignore' });
    console.log('Reloading and starting user service...');
    const reloadResult = spawnSync('systemctl', ['--user', 'daemon-reload'], { stdio: 'inherit' });
    if (reloadResult.status === 0) {
      const startResult = spawnSync('systemctl', ['--user', 'start', 'openclaw.service'], { stdio: 'inherit' });
      if (startResult.status === 0) {
        console.log('Quadlet installed and service started.');
      } else {
        console.error('Quadlet installed, but automatic start failed.');
        console.error('Try: systemctl --user daemon-reload && systemctl --user start openclaw.service');
        try {
          execSync('which loginctl', { stdio: 'ignore' });
          console.error(`For boot persistence on headless hosts, you may also need: sudo loginctl enable-linger ${os.userInfo().username}`);
        } catch (error) {
          // ignore
        }
      }
    }
  } catch (error) {
    console.error('systemctl not found; Quadlet installed but not started.');
  }
} else {
  console.log('Container setup complete.');
}

console.log('');
console.log('Next:');
console.log('  ./scripts/run-openclaw-podman.js launch');
console.log('  ./scripts/run-openclaw-podman.js launch setup');
console.log(`  openclaw --container ${OPENCLAW_CONTAINER_NAME} dashboard --no-open`);
