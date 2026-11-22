#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "a0c218a6c4aa6eaf11e47a9ea2740a508c670da2658c7b6cb8b809cd334ff1cb", "source_sha256": "8f102a03732002cacc77d2ffc6fb4210aabf44652bfa80af3f96aab371d0679c", "target_language": "javascript"}
// run.sh — portiert nach javascript
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/docker/install-sh-smoke/run.sh
// Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

'use strict';

const fs = require('fs');
const path = require('path');
const { spawnSync, execSync } = require('child_process');

// Environment variables with defaults
const INSTALL_URL = process.env.OPENCLAW_INSTALL_URL || 'https://openclaw.bot/install.sh';
const SMOKE_MODE = process.env.OPENCLAW_INSTALL_SMOKE_MODE || 'install';
const SMOKE_PREVIOUS_VERSION = process.env.OPENCLAW_INSTALL_SMOKE_PREVIOUS || '';
const SKIP_PREVIOUS = process.env.OPENCLAW_INSTALL_SMOKE_SKIP_PREVIOUS || '0';
const DEFAULT_PACKAGE = 'openclaw';
const PACKAGE_NAME = process.env.OPENCLAW_INSTALL_PACKAGE || DEFAULT_PACKAGE;
const FRESH_VERSION = process.env.OPENCLAW_INSTALL_FRESH_VERSION || '';
const FRESH_TAG_URL = process.env.OPENCLAW_INSTALL_FRESH_TAG_URL || '';
const UPDATE_BASELINE_VERSION = process.env.OPENCLAW_INSTALL_UPDATE_BASELINE || '2026.4.10';
const UPDATE_BASELINE_TAG_URL = process.env.OPENCLAW_INSTALL_UPDATE_BASELINE_TAG_URL || '';
const UPDATE_EXPECT_VERSION = process.env.OPENCLAW_INSTALL_UPDATE_EXPECT_VERSION || '';
const UPDATE_TAG_URL = process.env.OPENCLAW_INSTALL_UPDATE_TAG_URL || '';

// Get script directory
const SCRIPT_DIR = __dirname;

// Load CLI verification functions
const cliVerifyPath = path.join(SCRIPT_DIR, '../install-sh-common/cli-verify.js');
if (!fs.existsSync(cliVerifyPath)) {
  console.error(`ERROR: Cannot find cli-verify.js at ${cliVerifyPath}`);
  process.exit(1);
}
const { verifyInstalledCli } = require(cliVerifyPath);

function quietNpm(args) {
  const result = spawnSync('npm', args, {
    stdio: ['pipe', 'pipe', 'pipe'],
    env: { ...process.env, npm_config_loglevel: 'silent' }
  });
  
  if (result.error) {
    throw new Error(`npm command failed: ${result.error.message}`);
  }
  
  if (result.status !== 0) {
    throw new Error(`npm command exited with code ${result.status}: ${result.stderr.toString()}`);
  }
  
  return result.stdout.toString().trim();
}

function runInstallSmoke() {
  if (FRESH_VERSION && FRESH_TAG_URL) {
    console.log(`package=${PACKAGE_NAME} latest=${FRESH_VERSION} source=${FRESH_TAG_URL}`);
    console.log('==> Install latest release tarball');
    quietNpm(['install', '-g', '--omit=optional', FRESH_TAG_URL]);

    console.log('==> Verify installed version');
    if (process.env.OPENCLAW_INSTALL_LATEST_OUT) {
      fs.writeFileSync(process.env.OPENCLAW_INSTALL_LATEST_OUT, FRESH_VERSION);
    }
    verifyInstalledCli(PACKAGE_NAME, FRESH_VERSION);

    console.log('OK');
    return 0;
  }

  console.log('==> Resolve npm versions');
  let LATEST_VERSION, PREVIOUS_VERSION;

  if (SKIP_PREVIOUS === '1') {
    LATEST_VERSION = quietNpm(['view', PACKAGE_NAME, 'version']);
    PREVIOUS_VERSION = LATEST_VERSION;
  } else if (SMOKE_PREVIOUS_VERSION) {
    LATEST_VERSION = quietNpm(['view', PACKAGE_NAME, 'version']);
    PREVIOUS_VERSION = SMOKE_PREVIOUS_VERSION;
  } else {
    LATEST_VERSION = quietNpm(['view', PACKAGE_NAME, 'dist-tags.latest']);
    const VERSIONS_JSON = quietNpm(['view', PACKAGE_NAME, 'versions', '--json']);
    
    const script = `
const latest = String(process.env.LATEST_VERSION || "");
const raw = process.env.VERSIONS_JSON || "[]";
let versions;
try {
  versions = JSON.parse(raw);
} catch {
  versions = raw ? [raw] : [];
}
if (!Array.isArray(versions)) {
  versions = [versions];
}
if (versions.length === 0 || latest.length === 0) {
  process.exit(1);
}
const latestIndex = versions.lastIndexOf(latest);
if (latestIndex <= 0) {
  process.stdout.write(latest);
  process.exit(0);
}
process.stdout.write(String(versions[latestIndex - 1] ?? latest));
`;
    
    const result = spawnSync('node', ['-e', script], {
      env: {
        ...process.env,
        LATEST_VERSION: LATEST_VERSION,
        VERSIONS_JSON: VERSIONS_JSON
      },
      stdio: 'pipe'
    });
    
    if (result.status !== 0) {
      throw new Error(`Version resolution failed: ${result.stderr.toString()}`);
    }
    
    PREVIOUS_VERSION = result.stdout.toString().trim();
  }

  console.log(`package=${PACKAGE_NAME} latest=${LATEST_VERSION} previous=${PREVIOUS_VERSION}`);

  if (SKIP_PREVIOUS === '1') {
    console.log('==> Skip preinstall previous (OPENCLAW_INSTALL_SMOKE_SKIP_PREVIOUS=1)');
  } else {
    console.log('==> Preinstall previous (forces installer upgrade path)');
    quietNpm(['install', '-g', `${PACKAGE_NAME}@${PREVIOUS_VERSION}`]);
  }

  console.log('==> Run official installer one-liner');
  const curlResult = spawnSync('curl', ['-fsSL', INSTALL_URL], { stdio: 'pipe' });
  if (curlResult.status !== 0) {
    throw new Error(`curl failed: ${curlResult.stderr.toString()}`);
  }
  
  const bashResult = spawnSync('bash', ['-s', '--', '--no-prompt'], {
    input: curlResult.stdout,
    stdio: 'inherit'
  });
  
  if (bashResult.status !== 0) {
    throw new Error(`bash script failed with exit code ${bashResult.status}`);
  }

  console.log('==> Verify installed version');
  if (process.env.OPENCLAW_INSTALL_LATEST_OUT) {
    fs.writeFileSync(process.env.OPENCLAW_INSTALL_LATEST_OUT, LATEST_VERSION);
  }
  verifyInstalledCli(PACKAGE_NAME, LATEST_VERSION);

  console.log('OK');
}

function runUpdateSmoke() {
  if (!UPDATE_EXPECT_VERSION) {
    console.error('ERROR: OPENCLAW_INSTALL_UPDATE_EXPECT_VERSION is required for update mode');
    return 1;
  }
  if (!UPDATE_TAG_URL) {
    console.error('ERROR: OPENCLAW_INSTALL_UPDATE_TAG_URL is required for update mode');
    return 1;
  }

  console.log(`package=${PACKAGE_NAME} baseline=${UPDATE_BASELINE_VERSION} target=${UPDATE_EXPECT_VERSION}`);
  console.log('==> Install baseline release');
  
  if (UPDATE_BASELINE_TAG_URL) {
    quietNpm(['install', '-g', '--omit=optional', UPDATE_BASELINE_TAG_URL]);
  } else {
    quietNpm(['install', '-g', '--omit=optional', `${PACKAGE_NAME}@${UPDATE_BASELINE_VERSION}`]);
  }
  verifyInstalledCli(PACKAGE_NAME, UPDATE_BASELINE_VERSION);

  console.log('==> Run openclaw update from host-served tgz');
  
  const updateStderrFile = require('os').tmpdir() + '/openclaw-update-' + Date.now() + '.log';
  
  const env = {
    ...process.env,
    npm_config_omit: 'optional',
    NPM_CONFIG_OMIT: 'optional'
  };
  
  const updateResult = spawnSync('openclaw', ['update', '--tag', UPDATE_TAG_URL, '--yes', '--json'], {
    env: env,
    stdio: ['pipe', 'pipe', 'pipe']
  });
  
  const updateStderr = updateResult.stderr.toString();
  if (updateStderr) {
    console.error(updateStderr);
  }
  
  if (fs.existsSync(updateStderrFile)) {
    fs.unlinkSync(updateStderrFile);
  }
  
  if (updateResult.status !== 0) {
    console.error(`ERROR: openclaw update failed with exit code ${updateResult.status}`);
    return updateResult.status;
  }
  
  const UPDATE_JSON = updateResult.stdout.toString();
  console.log(UPDATE_JSON);
  
  const script = `
const payload = JSON.parse(process.env.UPDATE_JSON || "{}");
const expectedVersion = String(process.env.UPDATE_EXPECT_VERSION || "");
const baselineVersion = String(process.env.UPDATE_BASELINE_VERSION || "");
const expectedUrl = String(process.env.UPDATE_TAG_URL || "");
if (payload.status !== "ok") {
  throw new Error(\`expected update status ok, got \${JSON.stringify(payload.status)}\`);
}
if ((payload.before?.version ?? null) !== baselineVersion) {
  throw new Error(
    \`expected before.version \${baselineVersion}, got \${JSON.stringify(payload.before?.version)}\`,
  );
}
if ((payload.after?.version ?? null) !== expectedVersion) {
  throw new Error(
    \`expected after.version \${expectedVersion}, got \${JSON.stringify(payload.after?.version)}\`,
  );
}
if (payload.reason != null) {
  throw new Error(\`expected no failure reason, got \${JSON.stringify(payload.reason)}\`);
}
const steps = Array.isArray(payload.steps) ? payload.steps : [];
const updateStep = steps.find((step) => step?.name === "global update");
if (!updateStep) {
  throw new Error("missing global update step in update JSON");
}
if (Number(updateStep.exitCode ?? 1) !== 0) {
  throw new Error(\`global update step failed: \${JSON.stringify(updateStep)}\`);
}
if (typeof updateStep.command !== "string" || !updateStep.command.includes(expectedUrl)) {
  throw new Error(\`global update step missing expected tgz URL: \${JSON.stringify(updateStep)}\`);
}
`;
  
  const validationResult = spawnSync('node', ['-e', script], {
    env: {
      ...process.env,
      UPDATE_JSON: UPDATE_JSON,
      UPDATE_EXPECT_VERSION: UPDATE_EXPECT_VERSION,
      UPDATE_BASELINE_VERSION: UPDATE_BASELINE_VERSION,
      UPDATE_TAG_URL: UPDATE_TAG_URL
    },
    stdio: 'inherit'
  });
  
  if (validationResult.status !== 0) {
    throw new Error(`Update validation failed with exit code ${validationResult.status}`);
  }

  console.log('==> Verify updated version');
  verifyInstalledCli(PACKAGE_NAME, UPDATE_EXPECT_VERSION);

  console.log('OK');
}

// Main execution
try {
  switch (SMOKE_MODE) {
    case 'install':
      runInstallSmoke();
      break;
    case 'update':
      runUpdateSmoke();
      break;
    default:
      console.error(`ERROR: unsupported OPENCLAW_INSTALL_SMOKE_MODE=${SMOKE_MODE}`);
      process.exit(1);
  }
} catch (error) {
  console.error(error.message);
  process.exit(1);
}
