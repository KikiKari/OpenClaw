#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "9eca0c665cfac59f99ed40cc2f139027d389538dc5779cb71d452aa71a220f69", "source_sha256": "fbf046d1988d19407db864ee85d468151b410a1dc1cab4374f1f8119c6fb9897", "target_language": "javascript"}
// restart-mac.sh — portiert nach javascript
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/restart-mac.sh
// Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

// Reset OpenClaw like Trimmy: kill running instances, rebuild, repackage, relaunch, verify.

'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawn, execSync } = require('child_process');

const ROOT_DIR = path.resolve(__dirname, '..');
const APP_BUNDLE = process.env.OPENCLAW_APP_BUNDLE || '';
const APP_PROCESS_PATTERN = 'OpenClaw.app/Contents/MacOS/OpenClaw';
const DEBUG_PROCESS_PATTERN = path.join(ROOT_DIR, 'apps/macos/.build/debug/OpenClaw');
const LOCAL_PROCESS_PATTERN = path.join(ROOT_DIR, 'apps/macos/.build-local/debug/OpenClaw');
const RELEASE_PROCESS_PATTERN = path.join(ROOT_DIR, 'apps/macos/.build/release/OpenClaw');
const LAUNCH_AGENT = path.join(os.homedir(), 'Library/LaunchAgents/ai.openclaw.mac.plist');
const LOCK_KEY = require('crypto').createHash('sha256').update(ROOT_DIR).digest('hex').substring(0, 8);
const LOCK_DIR = path.join(process.env.TMPDIR || '/tmp', `openclaw-restart-${LOCK_KEY}`);
const LOCK_PID_FILE = path.join(LOCK_DIR, 'pid');
let WAIT_FOR_LOCK = false;
const LOG_PATH = process.env.OPENCLAW_RESTART_LOG || '/tmp/openclaw-restart.log';
let NO_SIGN = false;
let SIGN = false;
let AUTO_DETECT_SIGNING = true;
const GATEWAY_WAIT_SECONDS = parseInt(process.env.OPENCLAW_GATEWAY_WAIT_SECONDS || '0', 10);
const LAUNCHAGENT_DISABLE_MARKER = path.join(os.homedir(), '.openclaw/disable-launchagent');
let ATTACH_ONLY = true;

const log = (...args) => console.log(...args);
const fail = (...args) => {
  console.error('ERROR:', ...args);
  process.exit(1);
};

// Ensure local node binaries (rolldown, pnpm) are discoverable for the steps below.
process.env.PATH = `${path.join(ROOT_DIR, 'node_modules/.bin')}:${process.env.PATH}`;

const runStep = (label, command, args = [], options = {}) => {
  log(`==> ${label}`);
  return new Promise((resolve, reject) => {
    const proc = spawn(command, args, { ...options, stdio: 'inherit' });
    proc.on('close', (code) => {
      if (code === 0) {
        resolve();
      } else {
        reject(new Error(`${label} failed`));
      }
    });
  });
};

const cleanup = () => {
  if (fs.existsSync(LOCK_DIR)) {
    fs.rmSync(LOCK_DIR, { recursive: true, force: true });
  }
};

process.on('exit', cleanup);
process.on('SIGINT', () => {
  cleanup();
  process.exit(1);
});
process.on('SIGTERM', () => {
  cleanup();
  process.exit(1);
});

const acquireLock = () => {
  while (true) {
    try {
      fs.mkdirSync(LOCK_DIR);
      fs.writeFileSync(LOCK_PID_FILE, process.pid.toString());
      return;
    } catch (err) {
      // Ignore error if directory already exists
    }

    let existingPid = '';
    if (fs.existsSync(LOCK_PID_FILE)) {
      try {
        existingPid = fs.readFileSync(LOCK_PID_FILE, 'utf8').trim();
      } catch (err) {
        // Ignore read error
      }
    }

    if (existingPid && !isNaN(parseInt(existingPid))) {
      try {
        process.kill(parseInt(existingPid), 0); // Check if process exists
        if (WAIT_FOR_LOCK) {
          log(`==> Another restart is running (pid ${existingPid}); waiting...`);
          while (true) {
            try {
              process.kill(parseInt(existingPid), 0);
              require('child_process').execSync('sleep 1');
            } catch (err) {
              break;
            }
          }
          continue;
        }
        log(`==> Another restart is running (pid ${existingPid}); re-run with --wait.`);
        process.exit(0);
      } catch (err) {
        // Process doesn't exist, remove lock and continue
        fs.rmSync(LOCK_DIR, { recursive: true, force: true });
        continue;
      }
    }

    fs.rmSync(LOCK_DIR, { recursive: true, force: true });
  }
};

const checkSigningKeys = () => {
  try {
    const result = execSync('security find-identity -p codesigning -v 2>/dev/null', { encoding: 'utf8' });
    return /(Developer ID Application|Apple Distribution|Apple Development)/.test(result);
  } catch (err) {
    return false;
  }
};

// Parse arguments
process.argv.slice(2).forEach(arg => {
  switch (arg) {
    case '--wait':
    case '-w':
      WAIT_FOR_LOCK = true;
      break;
    case '--no-sign':
      NO_SIGN = true;
      AUTO_DETECT_SIGNING = false;
      break;
    case '--sign':
      SIGN = true;
      AUTO_DETECT_SIGNING = false;
      break;
    case '--attach-only':
      ATTACH_ONLY = true;
      break;
    case '--no-attach-only':
      ATTACH_ONLY = false;
      break;
    case '--help':
    case '-h':
      log(`Usage: ${path.basename(__filename)} [--wait] [--no-sign] [--sign] [--attach-only|--no-attach-only]`);
      log('  --wait    Wait for other restart to complete instead of exiting');
      log('  --no-sign Force no code signing (fastest for development)');
      log('  --sign    Force code signing (will fail if no signing key available)');
      log('  --attach-only    Launch app with --attach-only (skip launchd install)');
      log('  --no-attach-only Launch app without attach-only override');
      log('');
      log('Env:');
      log('  OPENCLAW_GATEWAY_WAIT_SECONDS=0  Wait time before gateway port check (unsigned only)');
      log('');
      log('Unsigned recovery:');
      log('  node openclaw.mjs daemon install --force --runtime node');
      log('  node openclaw.mjs daemon restart');
      log('');
      log('Reset unsigned overrides:');
      log('  rm ~/.openclaw/disable-launchagent');
      log('');
      log('Default behavior: Auto-detect signing keys, fallback to --no-sign if none found');
      process.exit(0);
      break;
    default:
      break;
  }
});

if (NO_SIGN && SIGN) {
  fail('Cannot use --sign and --no-sign together');
}

// Setup logging
fs.mkdirSync(path.dirname(LOG_PATH), { recursive: true });
if (fs.existsSync(LOG_PATH)) {
  fs.unlinkSync(LOG_PATH);
}

const logStream = fs.createWriteStream(LOG_PATH, { flags: 'a' });
console.log(`==> Log: ${LOG_PATH}`);
if (NO_SIGN) {
  log('==> Using --no-sign (unsigned flow enabled)');
}
if (ATTACH_ONLY) {
  log('==> Using --attach-only (skip launchd install)');
}

// Redirect stdout and stderr to log file
process.stdout.write = (data) => {
  process.stdout._write(data, 'utf8', () => {});
  logStream.write(data);
  return true;
};

process.stderr.write = (data) => {
  process.stderr._write(data, 'utf8', () => {});
  logStream.write(data);
  return true;
};

acquireLock();

const killAllOpenclaw = () => {
  for (let i = 0; i < 10; i++) {
    try {
      execSync(`pkill -f "${APP_PROCESS_PATTERN}" 2>/dev/null`, { stdio: 'ignore' });
    } catch (err) {
      // Ignore error
    }
    try {
      execSync(`pkill -f "${DEBUG_PROCESS_PATTERN}" 2>/dev/null`, { stdio: 'ignore' });
    } catch (err) {
      // Ignore error
    }
    try {
      execSync(`pkill -f "${LOCAL_PROCESS_PATTERN}" 2>/dev/null`, { stdio: 'ignore' });
    } catch (err) {
      // Ignore error
    }
    try {
      execSync(`pkill -f "${RELEASE_PROCESS_PATTERN}" 2>/dev/null`, { stdio: 'ignore' });
    } catch (err) {
      // Ignore error
    }
    try {
      execSync('pkill -x "OpenClaw" 2>/dev/null', { stdio: 'ignore' });
    } catch (err) {
      // Ignore error
    }

    let hasProcess = false;
    try {
      execSync(`pgrep -f "${APP_PROCESS_PATTERN}" >/dev/null 2>&1`, { stdio: 'ignore' });
      hasProcess = true;
    } catch (err) {
      // Ignore error
    }
    try {
      execSync(`pgrep -f "${DEBUG_PROCESS_PATTERN}" >/dev/null 2>&1`, { stdio: 'ignore' });
      hasProcess = true;
    } catch (err) {
      // Ignore error
    }
    try {
      execSync(`pgrep -f "${LOCAL_PROCESS_PATTERN}" >/dev/null 2>&1`, { stdio: 'ignore' });
      hasProcess = true;
    } catch (err) {
      // Ignore error
    }
    try {
      execSync(`pgrep -f "${RELEASE_PROCESS_PATTERN}" >/dev/null 2>&1`, { stdio: 'ignore' });
      hasProcess = true;
    } catch (err) {
      // Ignore error
    }
    try {
      execSync('pgrep -x "OpenClaw" >/dev/null 2>&1', { stdio: 'ignore' });
      hasProcess = true;
    } catch (err) {
      // Ignore error
    }

    if (!hasProcess) {
      return;
    }

    execSync('sleep 0.3');
  }
};

const stopLaunchAgent = () => {
  try {
    execSync(`launchctl bootout gui/"${process.getuid()}/ai.openclaw.mac" 2>/dev/null`, { stdio: 'ignore' });
  } catch (err) {
    // Ignore error
  }
};

// 1) Kill all running instances first.
log('==> Killing existing OpenClaw instances');
killAllOpenclaw();
stopLaunchAgent();

// Bundle Gateway-hosted Canvas A2UI assets.
(async () => {
  await runStep('bundle canvas a2ui', 'bash', ['-lc', `cd '${ROOT_DIR}' && pnpm canvas:a2ui:bundle`]);

  // 2) Rebuild into the same path the packager consumes (.build).
  await runStep('clean build cache', 'bash', ['-lc', `cd '${path.join(ROOT_DIR, 'apps/macos')}' && rm -rf .build .build-swift .swiftpm 2>/dev/null || true`]);
  await runStep('swift build', 'bash', ['-lc', `cd '${path.join(ROOT_DIR, 'apps/macos')}' && swift build -q --product OpenClaw`]);

  if (AUTO_DETECT_SIGNING) {
    if (checkSigningKeys()) {
      log('==> Signing keys detected, will code sign');
      SIGN = true;
    } else {
      log('==> No signing keys found, will skip code signing (--no-sign)');
      NO_SIGN = true;
    }
  }

  if (NO_SIGN) {
    process.env.ALLOW_ADHOC_SIGNING = '1';
    process.env.SIGN_IDENTITY = '-';
    fs.mkdirSync(path.join(os.homedir(), '.openclaw'), { recursive: true });
    await runStep('disable launchagent writes', 'touch', [LAUNCHAGENT_DISABLE_MARKER]);
  } else if (SIGN) {
    if (!checkSigningKeys()) {
      fail('No signing identity found. Use --no-sign or install a signing key.');
    }
    delete process.env.ALLOW_ADHOC_SIGNING;
    delete process.env.SIGN_IDENTITY;
  }

  // 3) Package app (no embedded gateway).
  await runStep('package app', 'bash', ['-lc', `cd '${ROOT_DIR}' && SKIP_TSC=${process.env.SKIP_TSC || 1} '${path.join(ROOT_DIR, 'scripts/package-mac-app.sh')}'`]);

  const chooseAppBundle = () => {
    if (APP_BUNDLE && fs.existsSync(APP_BUNDLE)) {
      return APP_BUNDLE;
    }

    const appInApplications = '/Applications/OpenClaw.app';
    if (fs.existsSync(appInApplications)) {
      return appInApplications;
    }

    const appInDist = path.join(ROOT_DIR, 'dist/OpenClaw.app');
    if (fs.existsSync(appInDist)) {
      if (!fs.existsSync(path.join(appInDist, 'Contents/Frameworks/Sparkle.framework'))) {
        fail('dist/OpenClaw.app missing Sparkle after packaging');
      }
      return appInDist;
    }

    fail('App bundle not found. Set OPENCLAW_APP_BUNDLE to your installed OpenClaw.app');
  };

  const selectedAppBundle = chooseAppBundle();

  // When signed, clear any previous launchagent override marker.
  if (!NO_SIGN && !ATTACH_ONLY && fs.existsSync(LAUNCHAGENT_DISABLE_MARKER)) {
    await runStep('clear launchagent disable marker', 'rm', ['-f', LAUNCHAGENT_DISABLE_MARKER]);
  }

  // When unsigned, ensure the gateway LaunchAgent targets the repo CLI (before the app launches).
  // This reduces noisy "could not connect" errors during app startup.
  if (NO_SIGN && !ATTACH_ONLY) {
    await runStep('install gateway launch agent (unsigned)', 'bash', ['-lc', `cd '${ROOT_DIR}' && node openclaw.mjs daemon install --force --runtime node`]);
    await runStep('restart gateway daemon (unsigned)', 'bash', ['-lc', `cd '${ROOT_DIR}' && node openclaw.mjs daemon restart`]);
    
    if (GATEWAY_WAIT_SECONDS > 0) {
      await runStep('wait for gateway (unsigned)', 'sleep', [GATEWAY_WAIT_SECONDS.toString()]);
    }

    let gatewayPort = '18789';
    try {
      const configPath = path.join(os.homedir(), '.openclaw', 'openclaw.json');
      if (fs.existsSync(configPath)) {
        const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
        if (config && config.gateway && typeof config.gateway.port === 'number') {
          gatewayPort = config.gateway.port.toString();
        }
      }
    } catch (err) {
      // Use default port
    }

    await runStep(`verify gateway port ${gatewayPort} (unsigned)`, 'bash', ['-lc', `lsof -iTCP:${gatewayPort} -sTCP:LISTEN | head -n 5 || true`]);
  }

  const attachOnlyArgs = ATTACH_ONLY ? ['--args', '--attach-only'] : [];

  // 4) Launch the installed app in the foreground so the menu bar extra appears.
  // LaunchServices can inherit a huge environment from this shell (secrets, prompt vars, etc.).
  // That can cause launchd spawn failures and is undesirable for a GUI app anyway.
  await runStep('launch app', 'env', [
    '-i',
    `HOME=${os.homedir()}`,
    `USER=${process.env.USER || require('child_process').execSync('id -un').toString().trim()}`,
    `LOGNAME=${process.env.LOGNAME || require('child_process').execSync('id -un').toString().trim()}`,
    `TMPDIR=${process.env.TMPDIR || '/tmp'}`,
    'PATH=/usr/bin:/bin:/usr/sbin:/sbin',
    `LANG=${process.env.LANG || 'en_US.UTF-8'}`,
    '/usr/bin/open',
    selectedAppBundle,
    ...attachOnlyArgs
  ]);

  // 5) Verify the app is alive.
  await new Promise(resolve => setTimeout(resolve, 1500));
  
  let isRunning = false;
  try {
    execSync(`pgrep -f "${APP_PROCESS_PATTERN}" >/dev/null 2>&1`, { stdio: 'ignore' });
    isRunning = true;
  } catch (err) {
    // Ignore error
  }

  if (isRunning) {
    log('OK: OpenClaw is running.');
  } else {
    fail(`App exited immediately. Check ${LOG_PATH} or Console.app (User Reports).`);
  }

  if (NO_SIGN && !ATTACH_ONLY) {
    await runStep('show gateway launch agent args (unsigned)', 'bash', ['-lc', `/usr/bin/plutil -p '${path.join(os.homedir(), 'Library/LaunchAgents/ai.openclaw.gateway.plist')}' | head -n 40 || true`]);
  }
})().catch(err => {
  fail(err.message);
});
