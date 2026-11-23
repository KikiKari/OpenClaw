#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "b15637937684c3090aa7db5835a6c8122f4b183f9ae7618c768971bb0c5a902e", "source_sha256": "7c279836c2c2bf7bf1f0cd8868a320423a0e69387a65cec698db01e1d888a57a", "target_language": "javascript"}
// setup.sh — portiert nach javascript
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/docker/setup.sh
// Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

import { spawnSync, execSync } from 'child_process';
import { promises as fs } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import { createRequire } from 'module';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const require = createRequire(import.meta.url);

const ROOT_DIR = join(dirname(dirname(__dirname)));
const COMPOSE_FILE = join(ROOT_DIR, 'docker-compose.yml');
const EXTRA_COMPOSE_FILE = join(ROOT_DIR, 'docker-compose.extra.yml');
const IMAGE_NAME = process.env.OPENCLAW_IMAGE || 'openclaw:local';
const EXTRA_MOUNTS = process.env.OPENCLAW_EXTRA_MOUNTS || '';
const HOME_VOLUME_NAME = process.env.OPENCLAW_HOME_VOLUME || '';
const RAW_SANDBOX_SETTING = process.env.OPENCLAW_SANDBOX || '';
let SANDBOX_ENABLED = '';
const DOCKER_SOCKET_PATH = process.env.OPENCLAW_DOCKER_SOCKET || '';
const TIMEZONE = process.env.OPENCLAW_TZ || '';

function fail(message) {
  console.error(`ERROR: ${message}`);
  process.exit(1);
}

function requireCmd(cmd) {
  try {
    execSync(`which ${cmd}`, { stdio: 'ignore' });
  } catch (error) {
    console.error(`Missing dependency: ${cmd}`);
    process.exit(1);
  }
}

function runDockerBuild(...args) {
  const result = spawnSync('docker', ['build', ...args], {
    env: { ...process.env, DOCKER_BUILDKIT: '1' },
    stdio: 'inherit'
  });
  if (result.status !== 0) {
    process.exit(result.status || 1);
  }
}

function isTruthyValue(raw) {
  if (!raw) return false;
  const normalized = raw.toLowerCase().trim();
  return ['1', 'true', 'yes', 'on'].includes(normalized);
}

async function readConfigGatewayToken() {
  const configPath = join(process.env.OPENCLAW_CONFIG_DIR || join(require('os').homedir(), '.openclaw'), 'openclaw.json');
  
  try {
    await fs.access(configPath);
  } catch {
    return '';
  }

  try {
    const content = await fs.readFile(configPath, 'utf8');
    const cfg = JSON.parse(content);
    const token = cfg?.gateway?.auth?.token;
    if (typeof token === 'string' && token.trim()) {
      return token.trim();
    }
  } catch {
    // Keep docker-setup resilient when config parsing fails.
  }
  
  return '';
}

async function readEnvGatewayToken(envPath) {
  try {
    await fs.access(envPath);
  } catch {
    return '';
  }

  try {
    const content = await fs.readFile(envPath, 'utf8');
    const lines = content.split(/\r?\n/);
    for (const line of lines) {
      const trimmed = line.trim();
      if (trimmed.startsWith('OPENCLAW_GATEWAY_TOKEN=')) {
        return trimmed.substring('OPENCLAW_GATEWAY_TOKEN='.length);
      }
    }
  } catch {
    // Ignore errors
  }
  
  return '';
}

function syncGatewayConfig() {
  let allowedOriginJson = '';
  let currentAllowedOrigins = '';
  let batchJson = '';

  if (process.env.OPENCLAW_GATEWAY_BIND !== 'loopback') {
    allowedOriginJson = `["http://localhost:${process.env.OPENCLAW_GATEWAY_PORT}","http://127.0.0.1:${process.env.OPENCLAW_GATEWAY_PORT}"]`;
    try {
      const result = runPrestartCli('config', 'get', 'gateway.controlUi.allowedOrigins');
      currentAllowedOrigins = result.stdout.toString().trim().replace(/\r/g, '');
    } catch {
      // Ignore errors
    }
  }

  batchJson = `[{"path":"gateway.mode","value":"local"},{"path":"gateway.bind","value":"${process.env.OPENCLAW_GATEWAY_BIND}"}`;
  if (allowedOriginJson) {
    if (!currentAllowedOrigins || currentAllowedOrigins === 'null' || currentAllowedOrigins === '[]') {
      batchJson += `,{"path":"gateway.controlUi.allowedOrigins","value":${allowedOriginJson}}`;
    } else {
      console.log('Control UI allowlist already configured; leaving gateway.controlUi.allowedOrigins unchanged.');
    }
  }
  batchJson += ']';

  runPrestartCli('config', 'set', '--batch-json', batchJson);
  console.log(`Pinned gateway.mode=local and gateway.bind=${process.env.OPENCLAW_GATEWAY_BIND} for Docker setup.`);
  if (allowedOriginJson && (!currentAllowedOrigins || currentAllowedOrigins === 'null' || currentAllowedOrigins === '[]')) {
    console.log(`Set gateway.controlUi.allowedOrigins to ${allowedOriginJson} for non-loopback bind.`);
  }
}

function runPrestartGateway(...args) {
  const cmd = ['docker', 'compose', ...COMPOSE_ARGS, 'run', '--rm', '--no-deps', ...args];
  const result = spawnSync(cmd[0], cmd.slice(1), { stdio: 'inherit' });
  if (result.status !== 0) {
    process.exit(result.status || 1);
  }
}

function runPrestartCli(...args) {
  return spawnSync('docker', [
    'compose', ...COMPOSE_ARGS, 'run', '--rm', '--no-deps',
    '--entrypoint', 'node', 'openclaw-gateway',
    'dist/index.js', ...args
  ], { stdio: ['pipe', 'pipe', 'inherit'] });
}

function runRuntimeCli(composeScope = 'current', depsMode = 'with-deps', ...args) {
  let composeArgs = [];
  const runArgs = ['run', '--rm'];

  switch (composeScope) {
    case 'current': composeArgs = [...COMPOSE_ARGS]; break;
    case 'base': composeArgs = [...BASE_COMPOSE_ARGS]; break;
    default: fail(`Unknown runtime CLI compose scope: ${composeScope}`);
  }

  switch (depsMode) {
    case 'with-deps': break;
    case 'no-deps': runArgs.push('--no-deps'); break;
    default: fail(`Unknown runtime CLI deps mode: ${depsMode}`);
  }

  const cmd = ['docker', 'compose', ...composeArgs, ...runArgs, 'openclaw-cli', ...args];
  const result = spawnSync(cmd[0], cmd.slice(1), { stdio: 'inherit' });
  if (result.status !== 0) {
    process.exit(result.status || 1);
  }
}

function containsDisallowedChars(value) {
  return /[\n\r\t]/.test(value);
}

function isValidTimezone(value) {
  try {
    execSync(`test -e "/usr/share/zoneinfo/${value}" && test ! -d "/usr/share/zoneinfo/${value}"`, { stdio: 'ignore' });
    return true;
  } catch {
    return false;
  }
}

function validateMountPathValue(label, value) {
  if (!value) {
    fail(`${label} cannot be empty.`);
  }
  if (containsDisallowedChars(value)) {
    fail(`${label} contains unsupported control characters.`);
  }
  if (/\s/.test(value)) {
    fail(`${label} cannot contain whitespace.`);
  }
}

function validateNamedVolume(value) {
  if (!/^[A-Za-z0-9][A-Za-z0-9_.-]*$/.test(value)) {
    fail('OPENCLAW_HOME_VOLUME must match [A-Za-z0-9][A-Za-z0-9_.-]* when using a named volume.');
  }
}

function validateMountSpec(mount) {
  if (containsDisallowedChars(mount)) {
    fail('OPENCLAW_EXTRA_MOUNTS entries cannot contain control characters.');
  }
  if (!/^[^,:]+:[^,:]+(:[^,:]+)?$/.test(mount)) {
    fail(`Invalid mount format '${mount}'. Expected source:target[:options] without spaces.`);
  }
}

// Main execution
(async () => {
  requireCmd('docker');
  
  try {
    execSync('docker compose version', { stdio: 'ignore' });
  } catch {
    console.error('Docker Compose not available (try: docker compose version)');
    process.exit(1);
  }

  let dockerSocketPath = DOCKER_SOCKET_PATH;
  if (!dockerSocketPath && process.env.DOCKER_HOST && process.env.DOCKER_HOST.startsWith('unix://')) {
    dockerSocketPath = process.env.DOCKER_HOST.substring('unix://'.length);
  }
  if (!dockerSocketPath) {
    dockerSocketPath = '/var/run/docker.sock';
  }
  if (isTruthyValue(RAW_SANDBOX_SETTING)) {
    SANDBOX_ENABLED = '1';
  }

  const OPENCLAW_CONFIG_DIR = process.env.OPENCLAW_CONFIG_DIR || join(require('os').homedir(), '.openclaw');
  const OPENCLAW_WORKSPACE_DIR = process.env.OPENCLAW_WORKSPACE_DIR || join(require('os').homedir(), '.openclaw', 'workspace');

  validateMountPathValue('OPENCLAW_CONFIG_DIR', OPENCLAW_CONFIG_DIR);
  validateMountPathValue('OPENCLAW_WORKSPACE_DIR', OPENCLAW_WORKSPACE_DIR);
  
  if (HOME_VOLUME_NAME) {
    if (HOME_VOLUME_NAME.includes('/')) {
      validateMountPathValue('OPENCLAW_HOME_VOLUME', HOME_VOLUME_NAME);
    } else {
      validateNamedVolume(HOME_VOLUME_NAME);
    }
  }
  
  if (containsDisallowedChars(EXTRA_MOUNTS)) {
    fail('OPENCLAW_EXTRA_MOUNTS cannot contain control characters.');
  }
  
  if (SANDBOX_ENABLED) {
    validateMountPathValue('OPENCLAW_DOCKER_SOCKET', dockerSocketPath);
  }
  
  if (TIMEZONE) {
    if (containsDisallowedChars(TIMEZONE)) {
      fail('OPENCLAW_TZ contains unsupported control characters.');
    }
    if (!/^[A-Za-z0-9/_+-]+$/.test(TIMEZONE)) {
      fail('OPENCLAW_TZ must be a valid IANA timezone string (e.g. Asia/Shanghai).');
    }
    if (!isValidTimezone(TIMEZONE)) {
      fail('OPENCLAW_TZ must match a timezone in /usr/share/zoneinfo (e.g. Asia/Shanghai).');
    }
  }

  // Create directories
  await fs.mkdir(OPENCLAW_CONFIG_DIR, { recursive: true });
  await fs.mkdir(OPENCLAW_WORKSPACE_DIR, { recursive: true });
  await fs.mkdir(join(OPENCLAW_CONFIG_DIR, 'identity'), { recursive: true });
  await fs.mkdir(join(OPENCLAW_CONFIG_DIR, 'agents', 'main', 'agent'), { recursive: true });
  await fs.mkdir(join(OPENCLAW_CONFIG_DIR, 'agents', 'main', 'sessions'), { recursive: true });

  process.env.OPENCLAW_CONFIG_DIR = OPENCLAW_CONFIG_DIR;
  process.env.OPENCLAW_WORKSPACE_DIR = OPENCLAW_WORKSPACE_DIR;
  process.env.OPENCLAW_GATEWAY_PORT = process.env.OPENCLAW_GATEWAY_PORT || '18789';
  process.env.OPENCLAW_BRIDGE_PORT = process.env.OPENCLAW_BRIDGE_PORT || '18790';
  process.env.OPENCLAW_GATEWAY_BIND = process.env.OPENCLAW_GATEWAY_BIND || 'lan';
  process.env.OPENCLAW_IMAGE = IMAGE_NAME;
  process.env.OPENCLAW_DOCKER_APT_PACKAGES = process.env.OPENCLAW_DOCKER_APT_PACKAGES || '';
  process.env.OPENCLAW_EXTENSIONS = process.env.OPENCLAW_EXTENSIONS || '';
  process.env.OPENCLAW_EXTRA_MOUNTS = EXTRA_MOUNTS;
  process.env.OPENCLAW_HOME_VOLUME = HOME_VOLUME_NAME;
  process.env.OPENCLAW_ALLOW_INSECURE_PRIVATE_WS = process.env.OPENCLAW_ALLOW_INSECURE_PRIVATE_WS || '';
  process.env.OPENCLAW_SANDBOX = SANDBOX_ENABLED;
  process.env.OPENCLAW_DOCKER_SOCKET = dockerSocketPath;
  process.env.OPENCLAW_TZ = TIMEZONE;

  // Detect Docker socket GID
  let DOCKER_GID = '';
  if (SANDBOX_ENABLED && require('fs').existsSync(dockerSocketPath)) {
    try {
      const stats = require('fs').statSync(dockerSocketPath);
      DOCKER_GID = stats.gid.toString();
    } catch {
      // Ignore errors
    }
  }
  process.env.DOCKER_GID = DOCKER_GID;

  if (!process.env.OPENCLAW_GATEWAY_TOKEN) {
    let existingConfigToken = await readConfigGatewayToken();
    if (existingConfigToken) {
      process.env.OPENCLAW_GATEWAY_TOKEN = existingConfigToken;
      console.log(`Reusing gateway token from ${join(OPENCLAW_CONFIG_DIR, 'openclaw.json')}`);
    } else {
      let dotenvGatewayToken = await readEnvGatewayToken(join(ROOT_DIR, '.env'));
      if (dotenvGatewayToken) {
        process.env.OPENCLAW_GATEWAY_TOKEN = dotenvGatewayToken;
        console.log(`Reusing gateway token from ${join(ROOT_DIR, '.env')}`);
      } else {
        try {
          process.env.OPENCLAW_GATEWAY_TOKEN = execSync('openssl rand -hex 32', { encoding: 'utf8' }).trim();
        } catch {
          process.env.OPENCLAW_GATEWAY_TOKEN = require('crypto').randomBytes(32).toString('hex');
        }
      }
    }
  }

  const COMPOSE_FILES = [COMPOSE_FILE];
  let COMPOSE_ARGS = [];

  async function writeExtraCompose(homeVolume, ...mounts) {
    let content = `services:
  openclaw-gateway:
    volumes:\n`;

    if (homeVolume) {
      const gatewayHomeMount = `${homeVolume}:/home/node`;
      const gatewayConfigMount = `${OPENCLAW_CONFIG_DIR}:/home/node/.openclaw`;
      const gatewayWorkspaceMount = `${OPENCLAW_WORKSPACE_DIR}:/home/node/.openclaw/workspace`;
      
      validateMountSpec(gatewayHomeMount);
      validateMountSpec(gatewayConfigMount);
      validateMountSpec(gatewayWorkspaceMount);
      
      content += `      - ${gatewayHomeMount}\n`;
      content += `      - ${gatewayConfigMount}\n`;
      content += `      - ${gatewayWorkspaceMount}\n`;
    }

    for (const mount of mounts) {
      validateMountSpec(mount);
      content += `      - ${mount}\n`;
    }

    content += `  openclaw-cli:
    volumes:\n`;

    if (homeVolume) {
      content += `      - ${homeVolume}:/home/node\n`;
      content += `      - ${OPENCLAW_CONFIG_DIR}:/home/node/.openclaw\n`;
      content += `      - ${OPENCLAW_WORKSPACE_DIR}:/home/node/.openclaw/workspace\n`;
    }

    for (const mount of mounts) {
      validateMountSpec(mount);
      content += `      - ${mount}\n`;
    }

    if (homeVolume && !homeVolume.includes('/')) {
      validateNamedVolume(homeVolume);
      content += `volumes:
  ${homeVolume}:\n`;
    }

    await fs.writeFile(EXTRA_COMPOSE_FILE, content);
  }

  if (SANDBOX_ENABLED) {
    if (!process.env.OPENCLAW_INSTALL_DOCKER_CLI) {
      process.env.OPENCLAW_INSTALL_DOCKER_CLI = '1';
    }
  }

  const VALID_MOUNTS = [];
  if (EXTRA_MOUNTS) {
    const mounts = EXTRA_MOUNTS.split(',').map(m => m.trim()).filter(m => m);
    VALID_MOUNTS.push(...mounts);
  }

  if (HOME_VOLUME_NAME || VALID_MOUNTS.length > 0) {
    if (VALID_MOUNTS.length > 0) {
      await writeExtraCompose(HOME_VOLUME_NAME, ...VALID_MOUNTS);
    } else {
      await writeExtraCompose(HOME_VOLUME_NAME);
    }
    COMPOSE_FILES.push(EXTRA_COMPOSE_FILE);
  }

  COMPOSE_ARGS = [];
  for (const composeFile of COMPOSE_FILES) {
    COMPOSE_ARGS.push('-f', composeFile);
  }

  const BASE_COMPOSE_ARGS = [...COMPOSE_ARGS];
  global.BASE_COMPOSE_ARGS = BASE_COMPOSE_ARGS;

  const ENV_FILE = join(ROOT_DIR, '.env');
  
  async function upsertEnv(file, ...keys) {
    const seen = new Set();
    let content = '';
    
    try {
      const existingContent = await fs.readFile(file, 'utf8');
      const lines = existingContent.split(/\r?\n/);
      
      for (const line of lines) {
        if (line.trim() && !line.startsWith('#')) {
          const [key] = line.split('=', 2);
          if (keys.includes(key)) {
            content += `${key}=${process.env[key] || ''}\n`;
            seen.add(key);
          } else {
            content += `${line}\n`;
          }
        } else {
          content += `${line}\n`;
        }
      }
    } catch {
      // File doesn't exist, that's OK
    }

    for (const key of keys) {
      if (!seen.has(key)) {
        content += `${key}=${process.env[key] || ''}\n`;
      }
    }

    await fs.writeFile(file, content);
  }

  await upsertEnv(ENV_FILE,
    'OPENCLAW_CONFIG_DIR',
    'OPENCLAW_WORKSPACE_DIR',
    'OPENCLAW_GATEWAY_PORT',
    'OPENCLAW_BRIDGE_PORT',
    'OPENCLAW_GATEWAY_BIND',
    'OPENCLAW_GATEWAY_TOKEN',
    'OPENCLAW_IMAGE',
    'OPENCLAW_EXTRA_MOUNTS',
    'OPENCLAW_HOME_VOLUME',
    'OPENCLAW_DOCKER_APT_PACKAGES',
    'OPENCLAW_EXTENSIONS',
    'OPENCLAW_SANDBOX',
    'OPENCLAW_DOCKER_SOCKET',
    'DOCKER_GID',
    'OPENCLAW_INSTALL_DOCKER_CLI',
    'OPENCLAW_ALLOW_INSECURE_PRIVATE_WS',
    'OPENCLAW_TZ'
  );

  if (IMAGE_NAME === 'openclaw:local') {
    console.log(`==> Building Docker image: ${IMAGE_NAME}`);
    runDockerBuild(
      '--build-arg', `OPENCLAW_DOCKER_APT_PACKAGES=${process.env.OPENCLAW_DOCKER_APT_PACKAGES}`,
      '--build-arg', `OPENCLAW_EXTENSIONS=${process.env.OPENCLAW_EXTENSIONS}`,
      '--build-arg', `OPENCLAW_INSTALL_DOCKER_CLI=${process.env.OPENCLAW_INSTALL_DOCKER_CLI || ''}`,
      '-t', IMAGE_NAME,
      '-f', join(ROOT_DIR, 'Dockerfile'),
      ROOT_DIR
    );
  } else {
    console.log(`==> Pulling Docker image: ${IMAGE_NAME}`);
    const result = spawnSync('docker', ['pull', IMAGE_NAME], { stdio: 'inherit' });
    if (result.status !== 0) {
      console.error(`ERROR: Failed to pull image ${IMAGE_NAME}. Please check the image name and your access permissions.`);
      process.exit(1);
    }
  }

  console.log('');
  console.log('==> Fixing data-directory permissions');
  runPrestartGateway('--user', 'root', '--entrypoint', 'sh', 'openclaw-gateway', '-c',
    'find /home/node/.openclaw -xdev -exec chown node:node {} +; ' +
    '[ -d /home/node/.openclaw/workspace/.openclaw ] && chown -R node:node /home/node/.openclaw/workspace/.openclaw || true'
  );

  console.log('');
  console.log('==> Onboarding (interactive)');
  console.log('Docker setup pins Gateway mode to local.');
  console.log(`Gateway runtime bind comes from OPENCLAW_GATEWAY_BIND (default: lan).`);
  console.log(`Current runtime bind: ${process.env.OPENCLAW_GATEWAY_BIND}`);
  console.log(`Gateway token: ${process.env.OPENCLAW_GATEWAY_TOKEN}`);
  console.log('Tailscale exposure: Off (use host-level tailnet/Tailscale setup separately).');
  console.log('Install Gateway daemon: No (managed by Docker Compose)');
  console.log('');

  runPrestartCli('onboard', '--mode', 'local', '--no-install-daemon');

  console.log('');
  console.log('==> Docker gateway defaults');
  await syncGatewayConfig();

  console.log('');
  console.log('==> Provider setup (optional)');
  console.log('WhatsApp (QR):');
  console.log(`  docker compose ${COMPOSE_FILES.map(f => `-f ${f}`).join(' ')} run --rm openclaw-cli channels login`);
  console.log('Telegram (bot token):');
  console.log(`  docker compose ${COMPOSE_FILES.map(f => `-f ${f}`).join(' ')} run --rm openclaw-cli channels add --channel telegram --token <token>`);
  console.log('Discord (bot token):');
  console.log(`  docker compose ${COMPOSE_FILES.map(f => `-f ${f}`).join(' ')} run --rm openclaw-cli channels add --channel discord --token <token>`);
  console.log('Docs: https://docs.openclaw.ai/channels');

  console.log('');
  console.log('==> Starting gateway');
  const startResult = spawnSync('docker', ['compose', ...COMPOSE_ARGS, 'up', '-d', 'openclaw-gateway'], { stdio: 'inherit' });
  if (startResult.status !== 0) {
    process.exit(startResult.status || 1);
  }

  if (SANDBOX_ENABLED) {
    console.log('');
    console.log('==> Sandbox setup');

    const sandboxDockerfilePath = join(ROOT_DIR, 'Dockerfile.sandbox');
    if (require('fs').existsSync(sandboxDockerfilePath)) {
      console.log('Building sandbox image: openclaw-sandbox:bookworm-slim');
      runDockerBuild(
        '-t', 'openclaw-sandbox:bookworm-slim',
        '-f', sandboxDockerfilePath,
        ROOT_DIR
      );
    } else {
      console.warn('WARNING: Dockerfile.sandbox not found in ' + ROOT_DIR);
      console.warn('  Sandbox config will be applied but no sandbox image will be built.');
      console.warn('  Agent exec may fail if the configured sandbox image does not exist.');
    }

    if (spawnSync('docker', ['compose', ...COMPOSE_ARGS, 'run', '--rm', '--entrypoint', 'docker', 'openclaw-gateway', '--version'], { stdio: 'ignore' }).status !== 0) {
      console.warn('WARNING: Docker CLI not found inside the container image.');
      console.warn('  Sandbox requires Docker CLI. Rebuild with --build-arg OPENCLAW_INSTALL_DOCKER_CLI=1');
      console.warn('  or use a local build (OPENCLAW_IMAGE=openclaw:local). Skipping sandbox setup.');
      SANDBOX_ENABLED = '';
    }
  }

  if (SANDBOX_ENABLED) {
    const dockerSocketExists = require('fs').existsSync(dockerSocketPath);
    if (dockerSocketExists) {
      const SANDBOX_COMPOSE_FILE = join(ROOT_DIR, 'docker-compose.sandbox.yml');
      let sandboxContent = `services:
  openclaw-gateway:
    volumes:
      - ${dockerSocketPath}:/var/run/docker.sock\n`;
      
      if (DOCKER_GID) {
        sandboxContent += `    group_add:
      - "${DOCKER_GID}"\n`;
      }
      
      await fs.writeFile(SANDBOX_COMPOSE_FILE, sandboxContent);
      COMPOSE_ARGS.push('-f', SANDBOX_COMPOSE_FILE);
      console.log('==> Sandbox: added Docker socket mount');
    } else {
      console.warn(`WARNING: OPENCLAW_SANDBOX enabled but Docker socket not found at ${dockerSocketPath}.`);
      console.warn('  Sandbox requires Docker socket access. Skipping sandbox setup.');
      SANDBOX_ENABLED = '';
    }
  }

  if (SANDBOX_ENABLED) {
    let sandboxConfigOk = true;
    
    try {
      runRuntimeCli('current', 'no-deps', 'config', 'set', 'agents.defaults.sandbox.mode', 'non-main');
    } catch {
      console.warn('WARNING: Failed to set agents.defaults.sandbox.mode');
      sandboxConfigOk = false;
    }
    
    try {
      runRuntimeCli('current', 'no-deps', 'config', 'set', 'agents.defaults.sandbox.scope', 'agent');
    } catch {
      console.warn('WARNING: Failed to set agents.defaults.sandbox.scope');
      sandboxConfigOk = false;
    }
    
    try {
      runRuntimeCli('current', 'no-deps', 'config', 'set', 'agents.defaults.sandbox.workspaceAccess', 'none');
    } catch {
      console.warn('WARNING: Failed to set agents.defaults.sandbox.workspaceAccess');
      sandboxConfigOk = false;
    }

    if (sandboxConfigOk) {
      console.log('Sandbox enabled: mode=non-main, scope=agent, workspaceAccess=none');
      console.log('Docs: https://docs.openclaw.ai/gateway/sandboxing');
      spawnSync('docker', ['compose', ...COMPOSE_ARGS, 'up', '-d', 'openclaw-gateway'], { stdio: 'inherit' });
    } else {
      console.warn('WARNING: Sandbox config was partially applied. Check errors above.');
      console.warn('  Skipping gateway restart to avoid exposing Docker socket without a full sandbox policy.');
      
      try {
        runRuntimeCli('base', 'no-deps', 'config', 'set', 'agents.defaults.sandbox.mode', 'off');
        console.log('Sandbox mode rolled back to off due to partial sandbox config failure.');
      } catch {
        console.warn('WARNING: Failed to roll back agents.defaults.sandbox.mode to off');
      }
      
      const sandboxComposeFile = join(ROOT_DIR, 'docker-compose.sandbox.yml');
      if (require('fs').existsSync(sandboxComposeFile)) {
        require('fs').unlinkSync(sandboxComposeFile);
      }
      
      spawnSync('docker', ['compose', ...BASE_COMPOSE_ARGS, 'up', '-d', '--force-recreate', 'openclaw-gateway'], { stdio: 'inherit' });
    }
  } else {
    try {
      runRuntimeCli('current', 'with-deps', 'config', 'set', 'agents.defaults.sandbox.mode', 'off');
    } catch {
      console.warn('WARNING: Failed to reset agents.defaults.sandbox.mode to off');
    }
    
    const sandboxComposeFile = join(ROOT_DIR, 'docker-compose.sandbox.yml');
    if (require('fs').existsSync(sandboxComposeFile)) {
      require('fs').unlinkSync(sandboxComposeFile);
    }
  }

  console.log('');
  console.log('Gateway running with host port mapping.');
  console.log('Access from tailnet devices via the host\'s tailnet IP.');
  console.log(`Config: ${OPENCLAW_CONFIG_DIR}`);
  console.log(`Workspace: ${OPENCLAW_WORKSPACE_DIR}`);
  console.log(`Token: ${process.env.OPENCLAW_GATEWAY_TOKEN}`);
  console.log('');
  console.log('Commands:');
  console.log(`  docker compose ${COMPOSE_FILES.map(f => `-f ${f}`).join(' ')} logs -f openclaw-gateway`);
  console.log(`  docker compose ${COMPOSE_FILES.map(f => `-f ${f}`).join(' ')} exec openclaw-gateway node dist/index.js health --token "${process.env.OPENCLAW_GATEWAY_TOKEN}"`);
})();
