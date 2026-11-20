#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "e9fbaf95747b59ec2c45ce7c1656d020d9957ce47803dc489675dcd841e84ff7", "source_sha256": "2ca708f3e5a694b78eb83d1e37cf5eefe3e601ebec3e31d771a7ebd4246aa33c", "target_language": "javascript"}
// ios-beta-prepare.sh — portiert nach javascript
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/ios-beta-prepare.sh
// Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

'use strict';

const fs = require('fs');
const path = require('path');
const { spawnSync, execSync } = require('child_process');

function usage() {
  console.log(`
Usage:
  OPENCLAW_PUSH_RELAY_BASE_URL=https://relay.example.com \\
    scripts/ios-beta-prepare.sh --build-number 7 [--team-id TEAMID]

Prepares local beta-release inputs without touching local signing overrides:
- reads apps/ios/version.json and writes apps/ios/build/Version.xcconfig
- writes apps/ios/build/BetaRelease.xcconfig with canonical bundle IDs
- configures the beta build for relay-backed APNs registration
- regenerates apps/ios/OpenClaw.xcodeproj via xcodegen
`);
}

const ROOT_DIR = path.resolve(__dirname, '..');
const IOS_DIR = path.join(ROOT_DIR, 'apps', 'ios');
const BUILD_DIR = path.join(IOS_DIR, 'build');
const BETA_XCCONFIG = path.join(BUILD_DIR, 'BetaRelease.xcconfig');
const TEAM_HELPER = path.join(ROOT_DIR, 'scripts', 'ios-team-id.sh');
const VERSION_HELPER = path.join(ROOT_DIR, 'scripts', 'ios-write-version-xcconfig.sh');
const IOS_VERSION_HELPER = path.join(ROOT_DIR, 'scripts', 'ios-version.ts');
const VERSION_SYNC_HELPER = path.join(ROOT_DIR, 'scripts', 'ios-sync-versioning.ts');

let BUILD_NUMBER = '';
let TEAM_ID = process.env.IOS_DEVELOPMENT_TEAM || '';
let PUSH_RELAY_BASE_URL = process.env.OPENCLAW_PUSH_RELAY_BASE_URL || process.env.IOS_PUSH_RELAY_BASE_URL || '';
let PUSH_RELAY_BASE_URL_XCCONFIG = '';
let IOS_VERSION = '';

function prepareBuildDir() {
  if (fs.existsSync(BUILD_DIR) && fs.lstatSync(BUILD_DIR).isSymbolicLink()) {
    console.error(`Refusing to use symlinked build directory: ${BUILD_DIR}`);
    process.exit(1);
  }
  fs.mkdirSync(BUILD_DIR, { recursive: true });
}

function writeGeneratedFile(outputPath, content) {
  if (fs.existsSync(outputPath) && fs.lstatSync(outputPath).isSymbolicLink()) {
    console.error(`Refusing to overwrite symlinked file: ${outputPath}`);
    process.exit(1);
  }
  fs.writeFileSync(outputPath, content);
}

function validatePushRelayBaseUrl(value) {
  if (/\s/.test(value)) {
    console.error('Invalid OPENCLAW_PUSH_RELAY_BASE_URL: whitespace is not allowed.');
    process.exit(1);
  }

  if (/[\$\(\)\=]/.test(value)) {
    console.error('Invalid OPENCLAW_PUSH_RELAY_BASE_URL: contains forbidden xcconfig characters.');
    process.exit(1);
  }

  const urlRegex = /^https:\/\/[A-Za-z0-9.\-]+(:([0-9]{1,5}))?(\/[A-Za-z0-9._~!&*+,;:@%\/\-]*)?$/;
  const match = value.match(urlRegex);
  if (!match) {
    console.error('Invalid OPENCLAW_PUSH_RELAY_BASE_URL: expected https://host[:port][/path].');
    process.exit(1);
  }

  const port = match[2];
  if (port && parseInt(port, 10) > 65535) {
    console.error('Invalid OPENCLAW_PUSH_RELAY_BASE_URL: port must be between 1 and 65535.');
    process.exit(1);
  }
}

function runCommand(command, args = [], options = {}) {
  const result = spawnSync(command, args, { ...options, stdio: 'inherit' });
  if (result.error) {
    throw result.error;
  }
  if (result.status !== 0) {
    process.exit(result.status);
  }
  return result;
}

function execCommand(command, options = {}) {
  try {
    return execSync(command, { ...options, encoding: 'utf8' }).trim();
  } catch (error) {
    console.error(error.message);
    process.exit(1);
  }
}

const args = process.argv.slice(2);
while (args.length > 0) {
  const arg = args.shift();
  switch (arg) {
    case '--':
      break;
    case '--build-number':
      BUILD_NUMBER = args.shift() || '';
      break;
    case '--team-id':
      TEAM_ID = args.shift() || '';
      break;
    case '-h':
    case '--help':
      usage();
      process.exit(0);
      break;
    default:
      console.error(`Unknown argument: ${arg}`);
      usage();
      process.exit(1);
  }
}

if (!BUILD_NUMBER) {
  console.error('Missing required --build-number.');
  usage();
  process.exit(1);
}

if (!TEAM_ID) {
  const teamHelperResult = spawnSync('bash', [TEAM_HELPER], {
    env: { ...process.env, IOS_ALLOW_KEYCHAIN_TEAM_FALLBACK: '1' },
    encoding: 'utf8'
  });
  if (teamHelperResult.error) {
    console.error(teamHelperResult.error.message);
    process.exit(1);
  }
  TEAM_ID = teamHelperResult.stdout.trim();
}

if (!TEAM_ID) {
  console.error('Could not resolve Apple Team ID. Set IOS_DEVELOPMENT_TEAM or sign into Xcode.');
  process.exit(1);
}

if (!PUSH_RELAY_BASE_URL) {
  console.error('Missing OPENCLAW_PUSH_RELAY_BASE_URL (or IOS_PUSH_RELAY_BASE_URL) for beta relay registration.');
  process.exit(1);
}

validatePushRelayBaseUrl(PUSH_RELAY_BASE_URL);

// `.xcconfig` treats `//` as a comment opener. Break the URL with a helper setting
// so Xcode still resolves it back to `https://...` at build time.
PUSH_RELAY_BASE_URL_XCCONFIG = PUSH_RELAY_BASE_URL.replace(/\/\//g, '$(OPENCLAW_URL_SLASH)$(OPENCLAW_URL_SLASH)');

prepareBuildDir();

runCommand('node', ['--import', 'tsx', VERSION_SYNC_HELPER, '--check'], { cwd: ROOT_DIR });

IOS_VERSION = execCommand(`node --import tsx "${IOS_VERSION_HELPER}" --field canonicalVersion`, { cwd: ROOT_DIR });
if (!IOS_VERSION) {
  console.error(`Unable to resolve iOS version from ${path.join(ROOT_DIR, 'apps', 'ios', 'version.json')}.`);
  process.exit(1);
}

runCommand('bash', [VERSION_HELPER, '--build-number', BUILD_NUMBER]);

const betaConfigContent = `// Auto-generated by scripts/ios-beta-prepare.sh.
// Local beta-release override; do not commit.
OPENCLAW_CODE_SIGN_STYLE = Automatic
OPENCLAW_DEVELOPMENT_TEAM = ${TEAM_ID}
OPENCLAW_IOS_SELECTED_TEAM = ${TEAM_ID}
OPENCLAW_APP_BUNDLE_ID = ai.openclaw.client
OPENCLAW_SHARE_BUNDLE_ID = ai.openclaw.client.share
OPENCLAW_ACTIVITY_WIDGET_BUNDLE_ID = ai.openclaw.client.activitywidget
OPENCLAW_WATCH_APP_BUNDLE_ID = ai.openclaw.client.watchkitapp
OPENCLAW_WATCH_EXTENSION_BUNDLE_ID = ai.openclaw.client.watchkitapp.extension
OPENCLAW_APP_PROFILE =
OPENCLAW_SHARE_PROFILE =
OPENCLAW_PUSH_TRANSPORT = relay
OPENCLAW_PUSH_DISTRIBUTION = official
OPENCLAW_URL_SLASH = /
OPENCLAW_PUSH_RELAY_BASE_URL = ${PUSH_RELAY_BASE_URL_XCCONFIG}
OPENCLAW_PUSH_APNS_ENVIRONMENT = production
`;

writeGeneratedFile(BETA_XCCONFIG, betaConfigContent);

runCommand('xcodegen', ['generate'], { cwd: IOS_DIR });

console.log(`Prepared iOS beta release: version=${IOS_VERSION} build=${BUILD_NUMBER} team=${TEAM_ID}`);
console.log(`XCODE_XCCONFIG_FILE=${BETA_XCCONFIG}`);
