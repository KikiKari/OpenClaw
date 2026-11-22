#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "57ff08a5cd7a929f95d7e366d30b7355cc21e58f1ea2caa1e6713082e65679ec", "source_sha256": "9b573d1d5f5751c3fe5bb1eb243725ffb174987da9e458632a295c541458b2a0", "target_language": "javascript"}
// run-openclaw-podman.sh — portiert nach javascript
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/run-openclaw-podman.sh
// Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

// Rootless OpenClaw in Podman: run after one-time setup.
//
// One-time setup (from repo root): ./scripts/podman/setup.sh
// Then:
//   ./run-openclaw-podman.js launch        // Start gateway
//   ./run-openclaw-podman.js launch setup  // Onboarding wizard
//
// Manage the running container from the host CLI:
//   openclaw --container openclaw dashboard --no-open
//   openclaw --container openclaw channels login
//
// Legacy: "setup-host" delegates to the Podman setup script

const fs = require('fs');
const os = require('os');
const path = require('path');
const child_process = require('child_process');
const crypto = require('crypto');

function resolveUserHome(user) {
  let home = '';
  try {
    const passwd = fs.readFileSync('/etc/passwd', 'utf8');
    const lines = passwd.split('\n');
    for (const line of lines) {
      const parts = line.split(':');
      if (parts[0] === user) {
        home = parts[5];
        break;
      }
    }
  } catch (err) {
    // Ignore error
  }
  if (!home) {
    home = `/home/${user}`;
  }
  return home;
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
  if (value.includes('/./') || value.endsWith('/.') || value.includes('/../') || value.endsWith('/..')) {
    fail(`Invalid ${label}: dot path segments are not allowed.`);
  }
}

function validateMountSourcePath(label, value) {
  validateAbsolutePath(label, value);
  if (value.includes(':')) {
    fail(`Invalid ${label}: ':' is not allowed in Podman bind-mount source paths.`);
  }
}

function ensureSafeExistingRegularFile(label, file) {
  validateAbsolutePath(label, file);
  if (!fs.existsSync(file)) {
    fail(`Missing ${label}: ${file}`);
  }
  const stats = fs.lstatSync(file);
  if (stats.isSymbolicLink()) {
    fail(`Unsafe ${label}: symlinks are not allowed (${file})`);
  }
  if (!stats.isFile()) {
    fail(`Unsafe ${label}: expected a regular file (${file})`);
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
  if (!stats.isDirectory()) {
    fail(`Expected ${label} to be a directory: ${dir}`);
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
  if (uid !== os.userInfo().uid) {
    fail(`Unsafe ${label}: not owned by current user (${dir})`);
  }
  const mode = parseInt(statMode(dir), 8);
  if ((mode & 0o022) !== 0) {
    fail(`Unsafe ${label}: group/other writable (${dir})`);
  }
}

function ensurePrivateExistingRegularFileOwnedByUser(label, file) {
  ensureSafeExistingRegularFile(label, file);
  const uid = statUid(file);
  if (uid !== os.userInfo().uid) {
    fail(`Unsafe ${label}: not owned by current user (${file})`);
  }
  const mode = parseInt(statMode(file), 8);
  if ((mode & 0o077) !== 0) {
    fail(`Unsafe ${label}: expected owner-only permissions (${file})`);
  }
}

function ensureSafeWriteFilePath(label, file) {
  validateAbsolutePath(label, file);
  if (fs.existsSync(file)) {
    const stats = fs.lstatSync(file);
    if (stats.isSymbolicLink()) {
      fail(`Unsafe ${label}: symlinks are not allowed (${file})`);
    }
    if (!stats.isFile()) {
      fail(`Unsafe ${label}: expected a regular file (${file})`);
    }
  }
  const dir = path.dirname(file);
  ensureSafeExistingDir(`${label} parent directory`, dir);
}

function writeFileAtomically(file, mode, content) {
  ensureSafeWriteFilePath("output file", file);
  const dir = path.dirname(file);
  const tmp = `${dir}/.tmp.${Math.random().toString(36).substring(2, 15)}`;
  fs.writeFileSync(tmp, content);
  fs.chmodSync(tmp, mode);
  fs.renameSync(tmp, file);
}

function loadPodmanEnvFile(file) {
  ensurePrivateExistingRegularFileOwnedByUser("Podman env file", file);
  const dir = path.dirname(file);
  ensurePrivateExistingDirOwnedByUser("Podman env directory", dir);
  
  const content = fs.readFileSync(file, 'utf8');
  const lines = content.split('\n');
  
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    if (!trimmed.includes('=')) continue;
    
    const [key, ...rest] = trimmed.split('=');
    let value = rest.join('=');
    
    const cleanKey = key.trim();
    if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(cleanKey)) continue;
    
    const validKeys = [
      'OPENCLAW_GATEWAY_TOKEN',
      'OPENCLAW_PODMAN_CONTAINER',
      'OPENCLAW_PODMAN_IMAGE',
      'OPENCLAW_IMAGE',
      'OPENCLAW_PODMAN_PULL',
      'OPENCLAW_PODMAN_GATEWAY_HOST_PORT',
      'OPENCLAW_GATEWAY_PORT',
      'OPENCLAW_PODMAN_BRIDGE_HOST_PORT',
      'OPENCLAW_BRIDGE_PORT',
      'OPENCLAW_GATEWAY_BIND',
      'OPENCLAW_PODMAN_USERNS',
      'OPENCLAW_BIND_MOUNT_OPTIONS',
      'OPENCLAW_PODMAN_PUBLISH_HOST'
    ];
    
    if (!validKeys.includes(cleanKey)) continue;
    
    // Handle quoted values
    if ((value.startsWith('"') && value.endsWith('"')) || 
        (value.startsWith("'") && value.endsWith("'"))) {
      value = value.substring(1, value.length - 1);
    }
    
    process.env[cleanKey] = value;
  }
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

const platformName = os.platform();

const effectiveUser = os.userInfo().username;
let effectiveHome = process.env.HOME || '';
if (!effectiveHome) {
  effectiveHome = resolveUserHome(effectiveUser);
}
if (os.userInfo().uid === 0) {
  fail("Run run-openclaw-podman.js as your normal user so Podman stays rootless.");
}

const args = process.argv.slice(2);

// Legacy: setup-host -> run the Podman setup script
if (args[0] === "setup-host") {
  const remainingArgs = args.slice(1);
  const repoRoot = path.resolve(__dirname, '..');
  let setupPodman = path.join(repoRoot, 'scripts', 'podman', 'setup.sh');
  if (fs.existsSync(setupPodman)) {
    const spawnArgs = ['bash', setupPodman, ...remainingArgs];
    const spawned = child_process.spawn(spawnArgs[0], spawnArgs.slice(1), { stdio: 'inherit' });
    spawned.on('close', (code) => {
      process.exit(code);
    });
    return;
  }
  setupPodman = path.join(repoRoot, 'setup-podman.sh');
  if (fs.existsSync(setupPodman)) {
    const spawnArgs = ['bash', setupPodman, ...remainingArgs];
    const spawned = child_process.spawn(spawnArgs[0], spawnArgs.slice(1), { stdio: 'inherit' });
    spawned.on('close', (code) => {
      process.exit(code);
    });
    return;
  }
  console.error("Podman setup script not found. Run from repo root: ./scripts/podman/setup.sh");
  process.exit(1);
}

let launchIndex = -1;
if (args[0] === "launch") {
  launchIndex = 0;
}
const remainingArgs = launchIndex !== -1 ? args.slice(launchIndex + 1) : args;

if (!effectiveHome) {
  effectiveHome = "/tmp";
}
validateAbsolutePath("effective home", effectiveHome);

let configDir = process.env.OPENCLAW_CONFIG_DIR || path.join(effectiveHome, '.openclaw');
let envFile = process.env.OPENCLAW_PODMAN_ENV || path.join(configDir, '.env');

// Bootstrap `.env` may set runtime/container options, but it must not
// relocate the config/workspace/env paths mid-run. Those path overrides are
// only honored from the parent process environment before bootstrap.
if (fs.existsSync(envFile)) {
  loadPodmanEnvFile(envFile);
}

configDir = process.env.OPENCLAW_CONFIG_DIR || path.join(effectiveHome, '.openclaw');
envFile = process.env.OPENCLAW_PODMAN_ENV || path.join(configDir, '.env');
const workspaceDir = process.env.OPENCLAW_WORKSPACE_DIR || path.join(configDir, 'workspace');
let containerName = process.env.OPENCLAW_PODMAN_CONTAINER || "openclaw";
let openclawImage = process.env.OPENCLAW_PODMAN_IMAGE || process.env.OPENCLAW_IMAGE || "openclaw:local";
const podmanPull = process.env.OPENCLAW_PODMAN_PULL || "never";
const hostGatewayPort = process.env.OPENCLAW_PODMAN_GATEWAY_HOST_PORT || process.env.OPENCLAW_GATEWAY_PORT || "18789";
const hostBridgePort = process.env.OPENCLAW_PODMAN_BRIDGE_HOST_PORT || process.env.OPENCLAW_BRIDGE_PORT || "18790";
const publishHost = process.env.OPENCLAW_PODMAN_PUBLISH_HOST || "127.0.0.1";

validateMountSourcePath("config directory", configDir);
validateMountSourcePath("workspace directory", workspaceDir);
validateAbsolutePath("env file path", envFile);
validateSingleLineValue("container name", containerName);
validateSingleLineValue("image name", openclawImage);
validateSingleLineValue("publish host", publishHost);
validatePort("gateway host port", hostGatewayPort);
validatePort("bridge host port", hostBridgePort);

try {
  process.chdir(effectiveHome);
} catch (err) {
  try {
    process.chdir("/tmp");
  } catch (err2) {
    // Ignore
  }
}

let runSetup = false;
let setupArgs = [];
if (remainingArgs[0] === "setup" || remainingArgs[0] === "onboard") {
  runSetup = true;
  setupArgs = remainingArgs.slice(1);
}

fs.mkdirSync(configDir, { recursive: true });
fs.mkdirSync(workspaceDir, { recursive: true });
fs.mkdirSync(path.join(configDir, 'canvas'), { recursive: true });
fs.mkdirSync(path.join(configDir, 'cron'), { recursive: true });
fs.chmodSync(configDir, 0o700);
fs.chmodSync(workspaceDir, 0o700);

ensurePrivateExistingDirOwnedByUser("config directory", configDir);
ensurePrivateExistingDirOwnedByUser("workspace directory", workspaceDir);

function resolveConfigGatewayBind(configDir) {
  try {
    const result = child_process.execSync('openclaw config get gateway.bind', {
      env: { ...process.env, OPENCLAW_CONTAINER: "", OPENCLAW_CONFIG_DIR: configDir },
      stdio: ['pipe', 'pipe', 'ignore']
    });
    return result.toString().trim();
  } catch (err) {
    return "";
  }
}

// For published container ports, the gateway must listen on the container
// interface, so the Podman launcher defaults to lan. Respect an explicit
// OPENCLAW_GATEWAY_BIND first, then gateway.bind in local config.
const configGatewayBind = resolveConfigGatewayBind(configDir);
const gatewayBind = process.env.OPENCLAW_GATEWAY_BIND || configGatewayBind || "lan";

function upsertEnvVar(file, key, value) {
  ensureSafeWriteFilePath("env file", file);
  const dir = path.dirname(file);
  const tmp = `${dir}/.env.tmp.${Math.random().toString(36).substring(2, 15)}`;
  
  if (fs.existsSync(file)) {
    const content = fs.readFileSync(file, 'utf8');
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
    
    fs.writeFileSync(tmp, newLines.join('\n'));
  } else {
    fs.writeFileSync(tmp, `${key}=${value}\n`);
  }
  
  fs.renameSync(tmp, file);
  try {
    fs.chmodSync(file, 0o600);
  } catch (err) {
    // Ignore
  }
}

function generateTokenHex32() {
  return crypto.randomBytes(32).toString('hex');
}

function createTokenEnvFile(file, token) {
  const dir = path.dirname(file);
  ensurePrivateExistingDirOwnedByUser("token env directory", dir);
  const tmp = `${dir}/.token.env.${Math.random().toString(36).substring(2, 15)}`;
  fs.chmodSync(tmp, 0o600);
  fs.writeFileSync(tmp, `OPENCLAW_GATEWAY_TOKEN=${token}\n`);
  return tmp;
}

function syncLocalControlUiOriginsViaCli(file, port) {
  const configDir = path.dirname(file);
  try {
    child_process.execSync('openclaw', { stdio: 'ignore' });
  } catch (err) {
    console.error("Warning: openclaw not found; unable to sync gateway.controlUi.allowedOrigins in", file);
    return;
  }
  
  try {
    child_process.execSync('python3', { stdio: 'ignore' });
  } catch (err) {
    child_process.execSync(`openclaw config set gateway.controlUi.allowedOrigins "[\\"http://127.0.0.1:${port}\\",\\"http://localhost:${port}\\"]" --strict-json`, {
      env: { ...process.env, OPENCLAW_CONTAINER: "", OPENCLAW_CONFIG_DIR: configDir },
      stdio: 'ignore'
    });
    return;
  }
  
  let allowedJson = "";
  try {
    const result = child_process.execSync(`openclaw config get gateway.controlUi.allowedOrigins --json`, {
      env: { ...process.env, OPENCLAW_CONTAINER: "", OPENCLAW_CONFIG_DIR: configDir },
      stdio: ['pipe', 'pipe', 'ignore']
    });
    allowedJson = result.toString().trim();
  } catch (err) {
    // Ignore
  }
  
  const pythonScript = `
import json
import sys

port = sys.argv[1]
raw = sys.argv[2] if len(sys.argv) > 2 else ""
desired = [
    f"http://127.0.0.1:{port}",
    f"http://localhost:{port}",
]
allowed = []
if raw:
    try:
        parsed = json.loads(raw)
        if isinstance(parsed, list):
            allowed = parsed
    except json.JSONDecodeError:
        allowed = []
cleaned = []
seen = set()
for origin in allowed + desired:
    if not isinstance(origin, str):
        continue
    normalized = origin.strip()
    if not normalized or normalized in seen:
        continue
    cleaned.append(normalized)
    seen.add(normalized)
print(json.dumps(cleaned))
`;
  
  const mergedJson = child_process.execSync(`python3 - ${port} '${allowedJson}'`, {
    input: pythonScript,
    encoding: 'utf8'
  }).trim();
  
  child_process.execSync(`openclaw config set gateway.controlUi.allowedOrigins '${mergedJson}' --strict-json`, {
    env: { ...process.env, OPENCLAW_CONTAINER: "", OPENCLAW_CONFIG_DIR: configDir },
    stdio: 'ignore'
  });
}

function syncLocalControlUiOrigins(file, port) {
  ensureSafeWriteFilePath("config file", file);
  try {
    child_process.execSync('python3', { stdio: 'ignore' });
  } catch (err) {
    console.error("Warning: python3 not found; unable to sync gateway.controlUi.allowedOrigins in", file);
    return;
  }
  
  const dir = path.dirname(file);
  ensurePrivateExistingDirOwnedByUser("config file directory", dir);
  const tmp = `${dir}/.config.tmp.${Math.random().toString(36).substring(2, 15)}`;
  
  const pythonScript = `
import json
import sys

path = sys.argv[1]
port = sys.argv[2]
tmp = sys.argv[3]
try:
    with open(path, "r", encoding="utf-8") as fh:
        data = json.load(fh)
except json.JSONDecodeError as exc:
    print(
        f"Warning: unable to sync gateway.controlUi.allowedOrigins in {path}: existing config is not strict JSON ({exc}). Leaving file unchanged.",
        file=sys.stderr,
    )
    raise SystemExit(1)
if not isinstance(data, dict):
    raise SystemExit(f"{path}: expected top-level object")
gateway = data.setdefault("gateway", {})
if not isinstance(gateway, dict):
    raise SystemExit(f"{path}: expected gateway object")
gateway.setdefault("mode", "local")
control_ui = gateway.setdefault("controlUi", {})
if not isinstance(control_ui, dict):
    raise SystemExit(f"{path}: expected gateway.controlUi object")
allowed = control_ui.get("allowedOrigins")
desired = [
    f"http://127.0.0.1:{port}",
    f"http://localhost:{port}",
]
if not isinstance(allowed, list):
    allowed = []
cleaned = []
seen = set()
for origin in allowed:
    if not isinstance(origin, str):
        continue
    normalized = origin.strip()
    if not normalized or normalized in seen:
        continue
    cleaned.append(normalized)
    seen.add(normalized)
for origin in desired:
    if origin not in seen:
        cleaned.append(origin)
        seen.add(origin)
control_ui["allowedOrigins"] = cleaned
with open(tmp, "w", encoding="utf-8") as fh:
    json.dump(data, fh, indent=2)
    fh.write("\\n")
`;

  try {
    child_process.execSync(`python3 - '${file}' '${port}' '${tmp}'`, {
      input: pythonScript
    });
  } catch (err) {
    fs.unlinkSync(tmp);
    syncLocalControlUiOriginsViaCli(file, port);
    return;
  }
  
  if (!fs.existsSync(tmp) || fs.statSync(tmp).size === 0) {
    fs.unlinkSync(tmp);
    return;
  }
  
  try {
    fs.chmodSync(tmp, 0o600);
  } catch (err) {
    // Ignore
  }
  fs.renameSync(tmp, file);
}

let tokenEnvFile = "";

function cleanupTokenEnvFile() {
  if (tokenEnvFile && fs.existsSync(tokenEnvFile)) {
    fs.unlinkSync(tokenEnvFile);
  }
}

process.on('exit', cleanupTokenEnvFile);
process.on('SIGINT', () => {
  cleanupTokenEnvFile();
  process.exit(0);
});
process.on('SIGTERM', () => {
  cleanupTokenEnvFile();
  process.exit(0);
});

let gatewayToken = process.env.OPENCLAW_GATEWAY_TOKEN;
if (!gatewayToken) {
  gatewayToken = generateTokenHex32();
  process.env.OPENCLAW_GATEWAY_TOKEN = gatewayToken;
  fs.mkdirSync(path.dirname(envFile), { recursive: true });
  ensureSafeExistingDir("env file directory", path.dirname(envFile));
  upsertEnvVar(envFile, "OPENCLAW_GATEWAY_TOKEN", gatewayToken);
  console.error(`Generated OPENCLAW_GATEWAY_TOKEN and wrote it to ${envFile}.`);
}

const configJson = path.join(configDir, 'openclaw.json');
if (!fs.existsSync(configJson)) {
  const oldUmask = process.umask(0o077);
  writeFileAtomically(configJson, 0o600, '{ "gateway": { "mode": "local" } }\n');
  process.umask(oldUmask);
  console.error(`Created ${configJson} (minimal gateway.mode=local).`);
}
syncLocalControlUiOrigins(configJson, hostGatewayPort);

const podmanUserns = process.env.OPENCLAW_PODMAN_USERNS || "keep-id";
let usernsArgs = [];
let runUserArgs = [];

switch (podmanUserns) {
  case "":
  case "auto":
    break;
  case "keep-id":
    usernsArgs = ["--userns=keep-id"];
    break;
  case "host":
    usernsArgs = ["--userns=host"];
    break;
  default:
    console.error(`Unsupported OPENCLAW_PODMAN_USERNS=${podmanUserns} (expected: keep-id, auto, host).`);
    process.exit(2);
}

const runUid = os.userInfo().uid;
const runGid = os.userInfo().gid;

if (podmanUserns === "keep-id") {
  runUserArgs = [`--user`, `${runUid}:${runGid}`];
} else {
  console.error(`Starting container without --user (OPENCLAW_PODMAN_USERNS=${podmanUserns}), mounts may require ownership fixes.`);
}

let selinuxMountOpts = "";
if (!process.env.OPENCLAW_BIND_MOUNT_OPTIONS) {
  if (platformName === "linux") {
    try {
      const selinuxMode = child_process.execSync('getenforce', { stdio: ['pipe', 'pipe', 'ignore'] }).toString().trim();
      if (selinuxMode === "Enforcing" || selinuxMode === "Permissive") {
        selinuxMountOpts = ",Z";
      }
    } catch (err) {
      // Ignore
    }
  }
} else {
  selinuxMountOpts = process.env.OPENCLAW_BIND_MOUNT_OPTIONS.substring(1);
  if (selinuxMountOpts) {
    selinuxMountOpts = `,${selinuxMountOpts}`;
  }
}

if (runSetup) {
  tokenEnvFile = createTokenEnvFile(envFile, gatewayToken);
  const podmanArgs = [
    'run',
    `--pull=${podmanPull}`,
    '--rm',
    '-it',
    '--init',
    ...usernsArgs,
    ...runUserArgs,
    '-e', 'HOME=/home/node',
    '-e', 'TERM=xterm-256color',
    '-e', 'BROWSER=echo',
    '-e', 'NPM_CONFIG_CACHE=/home/node/.openclaw/.npm',
    '-e', 'OPENCLAW_NO_RESPAWN=1',
    '--env-file', tokenEnvFile,
    '-v', `${configDir}:/home/node/.openclaw:rw${selinuxMountOpts}`,
    '-v', `${workspaceDir}:/home/node/.openclaw/workspace:rw${selinuxMountOpts}`,
    openclawImage,
    'node', 'dist/index.js', 'onboard',
    ...setupArgs
  ];
  
  const spawned = child_process.spawn('podman', podmanArgs, { stdio: 'inherit' });
  spawned.on('close', (code) => {
    process.exit(code);
  });
  return;
}

tokenEnvFile = createTokenEnvFile(envFile, gatewayToken);
const podmanArgs = [
  'run',
  `--pull=${podmanPull}`,
  '-d',
  '--replace',
  '--name', containerName,
  '--init',
  ...usernsArgs,
  ...runUserArgs,
  '-e', 'HOME=/home/node',
  '-e', 'TERM=xterm-256color',
  '-e', 'NPM_CONFIG_CACHE=/home/node/.openclaw/.npm',
  '-e', 'OPENCLAW_NO_RESPAWN=1',
  '--env-file', tokenEnvFile,
  '-v', `${configDir}:/home/node/.openclaw:rw${selinuxMountOpts}`,
  '-v', `${workspaceDir}:/home/node/.openclaw/workspace:rw${selinuxMountOpts}`,
  '-p', `${publishHost}:${hostGatewayPort}:18789`,
  '-p', `${publishHost}:${hostBridgePort}:18790`,
  openclawImage,
  'node', 'dist/index.js', 'gateway', '--bind', gatewayBind, '--port', '18789'
];

child_process.execFileSync('podman', podmanArgs, { stdio: 'ignore' });

console.log(`Container ${containerName} started: http://127.0.0.1:${hostGatewayPort}/`);
console.log(`podman exec -it ${containerName} openclaw dashboard --no-open`);
console.log(`podman exec -it ${containerName} openclaw devices approve --latest  # if pairing required`);
console.log(`podman logs -f ${containerName}`);
if (platformName === "linux") {
  console.log("For auto-start/restarts, use: ./scripts/podman/setup.sh --quadlet (Quadlet + systemd user service).");
}
