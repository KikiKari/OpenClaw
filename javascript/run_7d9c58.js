#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "7780e7eb39e2ca790fdd332e0a20b744ac6e1aabfaebb68e26944d50cc575e54", "source_sha256": "7d9c583822b7f56d89ce608cb8d469719c8a0d1dda7229ea2e4bbf717e511afe", "target_language": "javascript"}
// run.sh — portiert nach javascript
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/docker/install-sh-e2e/run.sh
// Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

'use strict';

const fs = require('node:fs');
const path = require('node:path');
const cp = require('node:child_process');
const os = require('node:os');
const https = require('node:https');
const zlib = require('node:zlib');
const crypto = require('node:crypto');

// Environment variables with defaults
const SCRIPT_DIR = path.dirname(process.argv[1]);
let VERIFY_HELPER_PATH = '/usr/local/install-sh-common/version-parse.sh';
if (!fs.existsSync(VERIFY_HELPER_PATH)) {
  VERIFY_HELPER_PATH = path.join(SCRIPT_DIR, '../install-sh-common/version-parse.sh');
}

const INSTALL_URL = process.env.OPENCLAW_INSTALL_URL || 'https://openclaw.bot/install.sh';
const MODELS_MODE = process.env.OPENCLAW_E2E_MODELS || 'both'; // both|openai|anthropic
const INSTALL_TAG = process.env.OPENCLAW_INSTALL_TAG || 'latest';
const E2E_PREVIOUS_VERSION = process.env.OPENCLAW_INSTALL_E2E_PREVIOUS || '';
const SKIP_PREVIOUS = process.env.OPENCLAW_INSTALL_E2E_SKIP_PREVIOUS === '1';
const OPENAI_API_KEY = process.env.OPENAI_API_KEY || '';
const ANTHROPIC_API_KEY = process.env.ANTHROPIC_API_KEY || '';
const ANTHROPIC_API_TOKEN = process.env.ANTHROPIC_API_TOKEN || '';

// Set up npm prefix and path
const NPM_CONFIG_PREFIX = process.env.NPM_CONFIG_PREFIX || path.join(os.homedir(), '.npm-global');
fs.mkdirSync(NPM_CONFIG_PREFIX, { recursive: true });
process.env.PATH = `${NPM_CONFIG_PREFIX}/bin:${process.env.PATH}`;

// Validate MODELS_MODE
if (!['both', 'openai', 'anthropic'].includes(MODELS_MODE)) {
  console.error('ERROR: OPENCLAW_E2E_MODELS must be one of: both|openai|anthropic');
  process.exit(2);
}

// Validate API keys based on mode
if ((MODELS_MODE === 'both' || MODELS_MODE === 'openai') && !OPENAI_API_KEY) {
  console.error('ERROR: OPENCLAW_E2E_MODELS=both or openai requires OPENAI_API_KEY.');
  process.exit(2);
}

if ((MODELS_MODE === 'both' || MODELS_MODE === 'anthropic') && 
    !ANTHROPIC_API_TOKEN && !ANTHROPIC_API_KEY) {
  console.error('ERROR: OPENCLAW_E2E_MODELS=both or anthropic requires ANTHROPIC_API_TOKEN or ANTHROPIC_API_KEY.');
  process.exit(2);
}

// Helper functions
function execSync(cmd, options = {}) {
  try {
    const result = cp.execSync(cmd, { ...options, stdio: ['pipe', 'pipe', 'pipe'] });
    return result.toString().trim();
  } catch (error) {
    throw new Error(`Command failed: ${cmd}\n${error.stderr ? error.stderr.toString() : error.message}`);
  }
}

function quiet_npm(args) {
  return execSync(`npm ${args}`, { env: { ...process.env, NPM_CONFIG_LOGLEVEL: 'silent' } });
}

function extract_openclaw_semver(versionString) {
  // Simple extraction of semver pattern
  const match = versionString.match(/(\d+\.\d+\.\d+(?:-[a-zA-Z0-9.-]+)?)/);
  return match ? match[1] : versionString;
}

console.log('==> Resolve npm versions');
let EXPECTED_VERSION = quiet_npm(`view "openclaw@${INSTALL_TAG}" version`);
if (!EXPECTED_VERSION || EXPECTED_VERSION === 'undefined' || EXPECTED_VERSION === 'null') {
  console.error(`ERROR: unable to resolve openclaw@${INSTALL_TAG} version`);
  process.exit(2);
}

let PREVIOUS_VERSION;
if (E2E_PREVIOUS_VERSION) {
  PREVIOUS_VERSION = E2E_PREVIOUS_VERSION;
} else {
  const VERSIONS_JSON = quiet_npm('view openclaw versions --json');
  const versions = JSON.parse(VERSIONS_JSON || '[]');
  if (!Array.isArray(versions) || versions.length === 0) {
    console.error('ERROR: Could not get versions list');
    process.exit(2);
  }
  PREVIOUS_VERSION = versions.length >= 2 ? versions[versions.length - 2] : versions[0];
}
console.log(`expected=${EXPECTED_VERSION} previous=${PREVIOUS_VERSION}`);

if (SKIP_PREVIOUS) {
  console.log('==> Skip preinstall previous (OPENCLAW_INSTALL_E2E_SKIP_PREVIOUS=1)');
} else {
  console.log('==> Preinstall previous (forces installer upgrade path; avoids read() prompt)');
  quiet_npm(`install -g "openclaw@${PREVIOUS_VERSION}"`);
}

console.log('==> Run official installer one-liner');
if (INSTALL_TAG === 'beta') {
  process.env.OPENCLAW_BETA = '1';
  cp.execSync(`curl -fsSL "${INSTALL_URL}" | bash`, { stdio: 'inherit' });
} else if (INSTALL_TAG !== 'latest') {
  process.env.OPENCLAW_VERSION = INSTALL_TAG;
  cp.execSync(`curl -fsSL "${INSTALL_URL}" | bash`, { stdio: 'inherit' });
} else {
  cp.execSync(`curl -fsSL "${INSTALL_URL}" | bash`, { stdio: 'inherit' });
}

console.log('==> Verify installed version');
let INSTALLED_VERSION = execSync('openclaw --version 2>/dev/null | head -n 1 | tr -d "\\r"');
INSTALLED_VERSION = extract_openclaw_semver(INSTALLED_VERSION);
console.log(`installed=${INSTALLED_VERSION} expected=${EXPECTED_VERSION}`);
if (INSTALLED_VERSION !== EXPECTED_VERSION) {
  console.error(`ERROR: expected openclaw@${EXPECTED_VERSION}, got openclaw@${INSTALLED_VERSION}`);
  process.exit(1);
}

function set_image_model(profile, candidates) {
  for (const candidate of candidates) {
    try {
      execSync(`openclaw --profile "${profile}" models set-image "${candidate}"`, { stdio: 'ignore' });
      return candidate;
    } catch (error) {
      // Continue trying other candidates
    }
  }
  throw new Error(`ERROR: could not set an image model (tried: ${candidates.join(', ')})`);
}

function set_agent_model(profile, candidates) {
  for (const candidate of candidates) {
    try {
      execSync(`openclaw --profile "${profile}" models set "${candidate}"`, { stdio: 'ignore' });
      return candidate;
    } catch (error) {
      // Continue trying other candidates
    }
  }
  throw new Error(`ERROR: could not set agent model (tried: ${candidates.join(', ')})`);
}

function write_png_lr_rg(out) {
  const width = 96;
  const height = 64;

  const crcTable = (() => {
    const table = new Uint32Array(256);
    for (let i = 0; i < 256; i++) {
      let c = i;
      for (let k = 0; k < 8; k++) c = (c & 1) ? (0xedb88320 ^ (c >>> 1)) : (c >>> 1);
      table[i] = c >>> 0;
    }
    return table;
  })();

  function crc32(buf) {
    let c = 0xffffffff;
    for (let i = 0; i < buf.length; i++) c = crcTable[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
    return (c ^ 0xffffffff) >>> 0;
  }

  function chunk(type, data) {
    const typeBuf = Buffer.from(type, 'ascii');
    const len = Buffer.alloc(4);
    len.writeUInt32BE(data.length, 0);
    const crcBuf = Buffer.alloc(4);
    crcBuf.writeUInt32BE(crc32(Buffer.concat([typeBuf, data])), 0);
    return Buffer.concat([len, typeBuf, data, crcBuf]);
  }

  const sig = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8; // bit depth
  ihdr[9] = 2; // color type: truecolor
  ihdr[10] = 0; // compression
  ihdr[11] = 0; // filter
  ihdr[12] = 0; // interlace

  const rows = [];
  for (let y = 0; y < height; y++) {
    const row = Buffer.alloc(1 + width * 3);
    row[0] = 0; // filter: none
    for (let x = 0; x < width; x++) {
      const i = 1 + x * 3;
      const left = x < width / 2;
      row[i + 0] = left ? 255 : 0;
      row[i + 1] = left ? 0 : 255;
      row[i + 2] = 0;
    }
    rows.push(row);
  }
  const raw = Buffer.concat(rows);
  const idat = zlib.deflateSync(raw, { level: 9 });

  const png = Buffer.concat([
    sig,
    chunk('IHDR', ihdr),
    chunk('IDAT', idat),
    chunk('IEND', Buffer.alloc(0)),
  ]);
  fs.writeFileSync(out, png);
}

function run_agent_turn(profile, session_id, prompt, out_json) {
  // Installer E2E validates install + onboard + embedded agent tooling. It does
  // not need a paired Gateway control-plane hop, which is flaky/non-deterministic
  // in the isolated container and already covered by gateway-specific lanes.
  const cmd = `openclaw --profile "${profile}" agent --local --session-id "${session_id}" --message "${prompt}" --thinking off --json`;
  try {
    const output = cp.execSync(cmd, { encoding: 'utf8' });
    fs.writeFileSync(out_json, output);
  } catch (error) {
    fs.writeFileSync(out_json, error.stdout || error.message);
  }

  const raw = fs.readFileSync(out_json, 'utf8');

  function extractTrailingJsonObject(input) {
    const trimmed = input.trim();
    if (!trimmed) {
      throw new Error('agent output was empty');
    }
    try {
      return JSON.parse(trimmed);
    } catch {
      // Some local runs emit stderr diagnostics before the final JSON payload.
      // Walk backward and keep the last parseable top-level object.
      for (let index = trimmed.lastIndexOf('{'); index >= 0; index = trimmed.lastIndexOf('{', index - 1)) {
        const candidate = trimmed.slice(index);
        try {
          return JSON.parse(candidate);
        } catch {
          // keep scanning
        }
      }
      throw new Error(`could not extract JSON payload from agent output:\n${trimmed}`);
    }
  }

  const parsed = extractTrailingJsonObject(raw);
  fs.writeFileSync(out_json, `${JSON.stringify(parsed, null, 2)}\n`, 'utf8');
}

function assert_agent_json_has_text(path) {
  const p = JSON.parse(fs.readFileSync(path, 'utf8'));
  const payloads =
    Array.isArray(p?.result?.payloads) ? p.result.payloads :
    Array.isArray(p?.payloads) ? p.payloads :
    [];
  const texts = payloads.map((x) => String(x?.text ?? '').trim()).filter(Boolean);
  if (texts.length === 0) process.exit(1);
}

function assert_agent_json_ok(json_path, expect_provider) {
  const p = JSON.parse(fs.readFileSync(json_path, 'utf8'));

  if (typeof p?.status === 'string' && p.status !== 'ok' && p.status !== 'accepted') {
    console.error(`ERROR: gateway status=${p.status}`);
    process.exit(1);
  }

  const result = p?.result ?? p;
  const payloads = Array.isArray(result?.payloads) ? result.payloads : [];
  const anyError = payloads.some((pl) => pl && pl.isError === true);
  const combinedText = payloads.map((pl) => String(pl?.text ?? '')).filter(Boolean).join('\n').trim();
  if (anyError) {
    console.error(`ERROR: agent returned error payload: ${combinedText}`);
    process.exit(1);
  }
  if (/rate_limit_error/i.test(combinedText) || /^429\b/.test(combinedText)) {
    console.error(`ERROR: agent rate limited: ${combinedText}`);
    process.exit(1);
  }

  const meta = result?.meta;
  const provider =
    (typeof meta?.agentMeta?.provider === 'string' && meta.agentMeta.provider.trim()) ||
    (typeof meta?.provider === 'string' && meta.provider.trim()) ||
    '';
  if (expect_provider && provider && provider !== expect_provider) {
    console.error(`ERROR: expected provider=${expect_provider}, got provider=${provider}`);
    process.exit(1);
  }
}

function extract_matching_text(path, expected) {
  const p = JSON.parse(fs.readFileSync(path, 'utf8'));
  const expectedStr = String(expected ?? '');
  const payloads =
    Array.isArray(p?.result?.payloads) ? p.result.payloads :
    Array.isArray(p?.payloads) ? p.payloads :
    [];
  const texts = payloads.map((x) => String(x?.text ?? '').trim()).filter(Boolean);
  const match = texts.find((text) => text === expectedStr);
  return match ?? texts[0] ?? '';
}

function assert_session_used_tools(jsonl, requiredTools) {
  const raw = fs.readFileSync(jsonl, 'utf8');
  const lines = raw.split('\n').map((l) => l.trim()).filter(Boolean);
  const seen = new Set();

  const toolTypes = new Set([
    'tool_use',
    'tool_result',
    'tool',
    'tool-call',
    'tool_call',
    'tooluse',
    'tool-use',
    'toolresult',
    'tool-result',
  ]);

  function walk(node, parent) {
    if (!node) return;
    if (Array.isArray(node)) {
      for (const item of node) walk(item, node);
      return;
    }
    if (typeof node !== 'object') return;
    const obj = node;
    const t = typeof obj.type === 'string' ? obj.type : null;
    if (t && (toolTypes.has(t) || /tool/i.test(t))) {
      const name =
        typeof obj.name === 'string' ? obj.name :
        typeof obj.toolName === 'string' ? obj.toolName :
        typeof obj.tool_name === 'string' ? obj.tool_name :
        (obj.tool && typeof obj.tool.name === 'string') ? obj.tool.name :
        null;
      if (name) seen.add(name);
    }
    if (typeof obj.name === 'string' && typeof obj.input === 'object' && obj.input) {
      // Many tool-use blocks look like { type: "...", name: "exec", input: {...} }
      // but some transcripts omit/rename type.
      seen.add(obj.name);
    }
    // OpenAI-ish tool call shapes.
    if (Array.isArray(obj.tool_calls)) {
      for (const c of obj.tool_calls) {
        const fn = c?.function;
        if (fn && typeof fn.name === 'string') seen.add(fn.name);
      }
    }
    if (obj.function && typeof obj.function.name === 'string') seen.add(obj.function.name);
    for (const v of Object.values(obj)) walk(v, obj);
  }

  for (const line of lines) {
    try {
      const entry = JSON.parse(line);
      walk(entry, null);
    } catch {
      // ignore unparsable lines
    }
  }

  const missing = [...requiredTools].filter((t) => !seen.has(t));
  if (missing.length > 0) {
    console.error(`Missing tools in transcript: ${missing.join(', ')}`);
    console.error(`Seen tools: ${[...seen].sort().join(', ')}`);
    console.error('Transcript head:');
    console.error(lines.slice(0, 5).join('\n'));
    process.exit(1);
  }
}

async function run_profile(profile, port, workspace, agent_model_provider) {
  console.log(`==> Onboard (${profile})`);
  if (agent_model_provider === 'openai') {
    execSync(`openclaw --profile "${profile}" onboard \
      --non-interactive \
      --accept-risk \
      --flow quickstart \
      --auth-choice openai-api-key \
      --openai-api-key "${OPENAI_API_KEY}" \
      --gateway-port "${port}" \
      --gateway-bind loopback \
      --gateway-auth token \
      --workspace "${workspace}" \
      --skip-health`);
  } else if (ANTHROPIC_API_KEY) {
    execSync(`openclaw --profile "${profile}" onboard \
      --non-interactive \
      --accept-risk \
      --flow quickstart \
      --auth-choice apiKey \
      --anthropic-api-key "${ANTHROPIC_API_KEY}" \
      --gateway-port "${port}" \
      --gateway-bind loopback \
      --gateway-auth token \
      --workspace "${workspace}" \
      --skip-health`);
  } else if (ANTHROPIC_API_TOKEN) {
    execSync(`openclaw --profile "${profile}" onboard \
      --non-interactive \
      --accept-risk \
      --flow quickstart \
      --auth-choice token \
      --token-provider anthropic \
      --token "${ANTHROPIC_API_TOKEN}" \
      --gateway-port "${port}" \
      --gateway-bind loopback \
      --gateway-auth token \
      --workspace "${workspace}" \
      --skip-health`);
  } else {
    execSync(`openclaw --profile "${profile}" onboard \
      --non-interactive \
      --accept-risk \
      --flow quickstart \
      --auth-choice apiKey \
      --anthropic-api-key "${ANTHROPIC_API_KEY}" \
      --gateway-port "${port}" \
      --gateway-bind loopback \
      --gateway-auth token \
      --workspace "${workspace}" \
      --skip-health`);
  }

  console.log(`==> Verify workspace identity files (${profile})`);
  const identityFiles = [
    'AGENTS.md',
    'IDENTITY.md',
    'USER.md',
    'SOUL.md',
    'TOOLS.md'
  ];
  for (const file of identityFiles) {
    if (!fs.existsSync(path.join(workspace, file))) {
      throw new Error(`Missing file: ${file}`);
    }
  }

  console.log(`==> Configure models (${profile})`);
  let agent_model;
  let image_model;
  if (agent_model_provider === 'openai') {
    agent_model = set_agent_model(profile, [
      'openai/gpt-5.4',
      'openai/gpt-4o-mini',
      'openai/gpt-4o'
    ]);
    image_model = set_image_model(profile, [
      'openai/gpt-4o-mini',
      'openai/gpt-4o'
    ]);
  } else {
    agent_model = set_agent_model(profile, [
      'anthropic/claude-opus-4-6',
      'claude-opus-4-6'
    ]);
    image_model = set_image_model(profile, [
      'anthropic/claude-opus-4-6',
      'claude-opus-4-6'
    ]);
  }
  console.log(`model=${agent_model}`);
  console.log(`imageModel=${image_model}`);

  console.log(`==> Prepare tool fixtures (${profile})`);
  const PROOF_TXT = path.join(workspace, 'proof.txt');
  const PROOF_COPY = path.join(workspace, 'copy.txt');
  const HOSTNAME_TXT = path.join(workspace, 'hostname.txt');
  const IMAGE_PNG = path.join(workspace, 'proof.png');
  const IMAGE_TXT = path.join(workspace, 'image.txt');
  const SESSION_ID = `e2e-tools-${profile}`;
  const SESSION_JSONL = path.join(os.homedir(), `.openclaw-${profile}`, 'agents', 'main', 'sessions', `${SESSION_ID}.jsonl`);

  const PROOF_VALUE = crypto.randomBytes(16).toString('hex');
  fs.writeFileSync(PROOF_TXT, PROOF_VALUE);
  write_png_lr_rg(IMAGE_PNG);
  const EXPECTED_HOSTNAME = os.hostname().trim();

  console.log(`==> Start gateway (${profile})`);
  const GATEWAY_LOG = path.join(workspace, 'gateway.log');
  const gatewayProcess = cp.spawn('openclaw', [
    '--profile', profile,
    'gateway',
    '--port', port,
    '--bind', 'loopback'
  ], {
    stdio: ['ignore', fs.openSync(GATEWAY_LOG, 'w'), fs.openSync(GATEWAY_LOG, 'w')],
    detached: true
  });
  gatewayProcess.unref();

  const cleanup_profile = () => {
    try {
      if (gatewayProcess.pid) {
        process.kill(-gatewayProcess.pid, 'SIGTERM');
      }
    } catch (error) {
      // Ignore errors during cleanup
    }
  };

  process.on('exit', cleanup_profile);
  process.on('SIGINT', () => {
    cleanup_profile();
    process.exit();
  });

  console.log(`==> Wait for health (${profile})`);
  let healthCheckPassed = false;
  for (let i = 0; i < 240; i++) {
    try {
      execSync(`openclaw --profile "${profile}" health --timeout 5000 --json`, { stdio: 'ignore' });
      healthCheckPassed = true;
      break;
    } catch (error) {
      await new Promise(resolve => setTimeout(resolve, 250));
    }
  }
  
  if (!healthCheckPassed) {
    execSync(`openclaw --profile "${profile}" health --timeout 60000 --json`, { stdio: 'ignore' });
  }

  console.log(`==> Agent turns (${profile})`);
  const TURN1_JSON = `/tmp/agent-${profile}-1.json`;
  const TURN2_JSON = `/tmp/agent-${profile}-2.json`;
  const TURN2B_JSON = `/tmp/agent-${profile}-2b.json`;
  const TURN3_JSON = `/tmp/agent-${profile}-3.json`;
  const TURN3B_JSON = `/tmp/agent-${profile}-3b.json`;
  const TURN4_JSON = `/tmp/agent-${profile}-4.json`;

  run_agent_turn(profile, SESSION_ID,
    `Use the read tool (not exec) to read ${PROOF_TXT}. Reply with the exact contents only (no extra whitespace).`,
    TURN1_JSON);
  assert_agent_json_has_text(TURN1_JSON);
  assert_agent_json_ok(TURN1_JSON, agent_model_provider);
  let reply1 = extract_matching_text(TURN1_JSON, PROOF_VALUE).trim();
  if (reply1 !== PROOF_VALUE) {
    console.error(`ERROR: agent did not read proof.txt correctly (${profile}): ${reply1}`);
    process.exit(1);
  }

  const prompt2 = `Use the write tool (not exec) to write exactly this string into ${PROOF_COPY}:\n${reply1}\nReply with exactly: WROTE`;
  run_agent_turn(profile, SESSION_ID, prompt2, TURN2_JSON);
  assert_agent_json_has_text(TURN2_JSON);
  assert_agent_json_ok(TURN2_JSON, agent_model_provider);
  const copy_value = fs.readFileSync(PROOF_COPY, 'utf8').trim();
  if (copy_value !== PROOF_VALUE) {
    console.error(`ERROR: copy.txt did not match proof.txt (${profile})`);
    process.exit(1);
  }
  
  run_agent_turn(profile, SESSION_ID,
    `Use the read tool (not exec) to read ${PROOF_COPY}. Reply with the exact contents only (no extra whitespace).`,
    TURN2B_JSON);
  assert_agent_json_has_text(TURN2B_JSON);
  assert_agent_json_ok(TURN2B_JSON, agent_model_provider);
  let reply2 = extract_matching_text(TURN2B_JSON, PROOF_VALUE).trim();
  if (reply2 !== PROOF_VALUE) {
    console.error(`ERROR: agent did not read copy.txt correctly (${profile}): ${reply2}`);
    process.exit(1);
  }

  run_agent_turn(profile, SESSION_ID,
    'Use the exec tool to run this command: hostname. Reply with the exact stdout only (trim trailing newline).',
    TURN3_JSON);
  assert_agent_json_has_text(TURN3_JSON);
  assert_agent_json_ok(TURN3_JSON, agent_model_provider);
  let reply3 = extract_matching_text(TURN3_JSON, EXPECTED_HOSTNAME).trim();
  if (reply3 !== EXPECTED_HOSTNAME) {
    console.error(`ERROR: agent did not run hostname correctly (${profile}): ${reply3}`);
    process.exit(1);
  }
  
  const prompt3b = `Use the write tool to write exactly this string into ${HOSTNAME_TXT}:\n${reply3}\nReply with exactly: WROTE`;
  run_agent_turn(profile, SESSION_ID, prompt3b, TURN3B_JSON);
  assert_agent_json_has_text(TURN3B_JSON);
  assert_agent_json_ok(TURN3B_JSON, agent_model_provider);
  if (fs.readFileSync(HOSTNAME_TXT, 'utf8').trim() !== EXPECTED_HOSTNAME) {
    console.error(`ERROR: hostname.txt did not match hostname output (${profile})`);
    process.exit(1);
  }

  run_agent_turn(profile, SESSION_ID,
    `Use the image tool on ${IMAGE_PNG}. Determine which color is on the left half and which is on the right half. Then use the write tool to write exactly: LEFT=RED RIGHT=GREEN into ${IMAGE_TXT}. Reply with exactly: LEFT=RED RIGHT=GREEN`,
    TURN4_JSON);
  assert_agent_json_has_text(TURN4_JSON);
  assert_agent_json_ok(TURN4_JSON, agent_model_provider);
  if (fs.readFileSync(IMAGE_TXT, 'utf8').trim() !== 'LEFT=RED RIGHT=GREEN') {
    console.error(`ERROR: image.txt did not contain expected marker (${profile})`);
    process.exit(1);
  }
  
  let reply4 = extract_matching_text(TURN4_JSON, 'LEFT=RED RIGHT=GREEN');
  if (reply4 !== 'LEFT=RED RIGHT=GREEN') {
    console.error(`ERROR: agent reply did not contain expected marker (${profile}): ${reply4}`);
    process.exit(1);
  }

  console.log(`==> Verify tool usage via session transcript (${profile})`);
  // Give the gateway a moment to flush transcripts.
  await new Promise(resolve => setTimeout(resolve, 1000));
  if (!fs.existsSync(SESSION_JSONL)) {
    console.error(`ERROR: missing session transcript (${profile}): ${SESSION_JSONL}`);
    try {
      const sessionsDir = path.dirname(SESSION_JSONL);
      console.error(fs.readdirSync(sessionsDir).join('\n'));
    } catch (e) {
      console.error('Could not list sessions directory:', e.message);
    }
    process.exit(1);
  }
  assert_session_used_tools(SESSION_JSONL, ['read', 'write', 'exec', 'image']);

  cleanup_profile();
  process.removeListener('exit', cleanup_profile);
}

async function main() {
  if (MODELS_MODE === 'openai' || MODELS_MODE === 'both') {
    await run_profile('e2e-openai', '18789', '/tmp/openclaw-e2e-openai', 'openai');
  }

  if (MODELS_MODE === 'anthropic' || MODELS_MODE === 'both') {
    await run_profile('e2e-anthropic', '18799', '/tmp/openclaw-e2e-anthropic', 'anthropic');
  }

  console.log('OK');
}

main().catch(error => {
  console.error(error.message);
  process.exit(1);
});
