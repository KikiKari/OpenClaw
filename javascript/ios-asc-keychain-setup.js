#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "d68448a125112660db9484da3d4e94400f05002d0d01a3ec70acd472dcc4d063", "source_sha256": "3c82de39b963e31592918456342c499f4e6477d2ee7404f215a5685c6d02674c", "target_language": "javascript"}
// ios-asc-keychain-setup.sh — portiert nach javascript
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/ios-asc-keychain-setup.sh
// Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

import fs from 'fs';
import path from 'path';
import { execSync } from 'child_process';
import os from 'os';

const usage = () => {
  console.log(`
Usage:
  scripts/ios-asc-keychain-setup.sh --key-path /path/to/AuthKey_XXXXXX.p8 --issuer-id <issuer-uuid> [options]

Required:
  --key-path <path>      Path to App Store Connect API key (.p8)
  --issuer-id <uuid>     App Store Connect issuer ID

Optional:
  --key-id <id>          API key ID (auto-detected from AuthKey_<id>.p8 if omitted)
  --service <name>       Keychain service name (default: openclaw-asc-key)
  --account <name>       Keychain account name (default: $USER or $LOGNAME)
  --write-env            Upsert non-secret env vars into apps/ios/fastlane/.env
  --env-file <path>      Override env file path used with --write-env
  -h, --help             Show this help

Example:
  scripts/ios-asc-keychain-setup.sh \\
    --key-path "$HOME/keys/AuthKey_ABC1234567.p8" \\
    --issuer-id "00000000-1111-2222-3333-444444444444" \\
    --write-env
`);
};

const upsertEnvLine = (file, key, value) => {
  let lines = [];
  if (fs.existsSync(file)) {
    lines = fs.readFileSync(file, 'utf8').split('\n');
  }
  
  let found = false;
  const newLines = lines.map(line => {
    if (line.startsWith(`${key}=`)) {
      found = true;
      return `${key}=${value}`;
    }
    return line;
  });
  
  if (!found) {
    newLines.push(`${key}=${value}`);
  }
  
  fs.writeFileSync(file, newLines.filter(line => line !== '').join('\n') + '\n');
};

const deleteEnvLine = (file, key) => {
  if (!fs.existsSync(file)) {
    return;
  }
  
  const lines = fs.readFileSync(file, 'utf8').split('\n');
  const newLines = lines.filter(line => !line.startsWith(`${key}=`));
  
  fs.writeFileSync(file, newLines.filter(line => line !== '').join('\n') + '\n');
};

let KEY_PATH = "";
let KEY_ID = "";
let ISSUER_ID = "";
let SERVICE = "openclaw-asc-key";
let ACCOUNT = process.env.USER || process.env.LOGNAME || "";
let WRITE_ENV = false;
let ENV_FILE = "";

const REPO_ROOT = path.resolve(new URL('.', import.meta.url).pathname, "../..");
const DEFAULT_ENV_FILE = path.join(REPO_ROOT, "apps/ios/fastlane/.env");

const args = process.argv.slice(2);
let i = 0;

while (i < args.length) {
  switch (args[i]) {
    case "--key-path":
      KEY_PATH = args[i + 1] || "";
      i += 2;
      break;
    case "--key-id":
      KEY_ID = args[i + 1] || "";
      i += 2;
      break;
    case "--issuer-id":
      ISSUER_ID = args[i + 1] || "";
      i += 2;
      break;
    case "--service":
      SERVICE = args[i + 1] || "";
      i += 2;
      break;
    case "--account":
      ACCOUNT = args[i + 1] || "";
      i += 2;
      break;
    case "--write-env":
      WRITE_ENV = true;
      i += 1;
      break;
    case "--env-file":
      ENV_FILE = args[i + 1] || "";
      i += 2;
      break;
    case "-h":
    case "--help":
      usage();
      process.exit(0);
      break;
    default:
      console.error(`Unknown argument: ${args[i]}`);
      usage();
      process.exit(1);
  }
}

if (!KEY_PATH || !ISSUER_ID) {
  console.error("Missing required arguments.");
  usage();
  process.exit(1);
}

if (!fs.existsSync(KEY_PATH)) {
  console.error(`Key file not found: ${KEY_PATH}`);
  process.exit(1);
}

if (!KEY_ID) {
  const keyFilename = path.basename(KEY_PATH);
  const match = keyFilename.match(/^AuthKey_([A-Za-z0-9]+)\.p8$/);
  if (match) {
    KEY_ID = match[1];
  } else {
    console.error(`Could not infer --key-id from filename '${keyFilename}'. Pass --key-id explicitly.`);
    process.exit(1);
  }
}

if (!ACCOUNT) {
  console.error("Could not determine Keychain account. Pass --account explicitly.");
  process.exit(1);
}

const KEY_CONTENT = fs.readFileSync(KEY_PATH, 'utf8');
if (!KEY_CONTENT) {
  console.error(`Key file is empty: ${KEY_PATH}`);
  process.exit(1);
}

// Store in keychain using security command
try {
  execSync(
    `security add-generic-password -a "${ACCOUNT}" -s "${SERVICE}" -w "${KEY_CONTENT.replace(/"/g, '\\"')}" -U`,
    { stdio: 'pipe' }
  );
} catch (error) {
  console.error("Failed to store key in Keychain");
  process.exit(1);
}

console.log(`Stored ASC API private key in macOS Keychain (service='${SERVICE}', account='${ACCOUNT}').`);
console.log();
console.log("Export these vars for Fastlane:");
console.log(`ASC_KEY_ID=${KEY_ID}`);
console.log(`ASC_ISSUER_ID=${ISSUER_ID}`);
console.log(`ASC_KEYCHAIN_SERVICE=${SERVICE}`);
console.log(`ASC_KEYCHAIN_ACCOUNT=${ACCOUNT}`);

if (WRITE_ENV) {
  if (!ENV_FILE) {
    ENV_FILE = DEFAULT_ENV_FILE;
  }

  fs.mkdirSync(path.dirname(ENV_FILE), { recursive: true });
  if (!fs.existsSync(ENV_FILE)) {
    fs.writeFileSync(ENV_FILE, '');
  }

  upsertEnvLine(ENV_FILE, "ASC_KEY_ID", KEY_ID);
  upsertEnvLine(ENV_FILE, "ASC_ISSUER_ID", ISSUER_ID);
  upsertEnvLine(ENV_FILE, "ASC_KEYCHAIN_SERVICE", SERVICE);
  upsertEnvLine(ENV_FILE, "ASC_KEYCHAIN_ACCOUNT", ACCOUNT);
  // Remove file/path based keys so Keychain is used by default.
  deleteEnvLine(ENV_FILE, "ASC_KEY_PATH");
  deleteEnvLine(ENV_FILE, "ASC_KEY_CONTENT");
  deleteEnvLine(ENV_FILE, "APP_STORE_CONNECT_API_KEY_PATH");

  console.log();
  console.log(`Updated env file: ${ENV_FILE}`);
}
