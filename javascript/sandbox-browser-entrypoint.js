#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "d57b3a14fc416f61c50c871aa980d684d8dad0af24627173108cc7a6795f5145", "source_sha256": "29aab8d3e497ddaa7ec77edf107b153fe17970d064df8a91d7cfcedb7e30a7fd", "target_language": "javascript"}
// sandbox-browser-entrypoint.sh — portiert nach javascript
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/sandbox-browser-entrypoint.sh
// Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

const fs = require('fs');
const path = require('path');
const { spawn, execSync } = require('child_process');

process.on('uncaughtException', (err) => {
  console.error('[sandbox] Uncaught exception:', err);
  process.exit(1);
});

// Environment setup
process.env.DBUS_SESSION_BUS_ADDRESS = '/dev/null';

process.env.DISPLAY = ':1';
process.env.HOME = '/tmp/openclaw-home';
process.env.XDG_CONFIG_HOME = path.join(process.env.HOME, '.config');
process.env.XDG_CACHE_HOME = path.join(process.env.HOME, '.cache');

const CDP_PORT = parseInt(process.env.OPENCLAW_BROWSER_CDP_PORT || '9222', 10);
const CDP_SOURCE_RANGE = process.env.OPENCLAW_BROWSER_CDP_SOURCE_RANGE || '';
const VNC_PORT = parseInt(process.env.OPENCLAW_BROWSER_VNC_PORT || '5900', 10);
const NOVNC_PORT = parseInt(process.env.OPENCLAW_BROWSER_NOVNC_PORT || '6080', 10);
const ENABLE_NOVNC = (process.env.OPENCLAW_BROWSER_ENABLE_NOVNC || '1') === '1';
const HEADLESS = (process.env.OPENCLAW_BROWSER_HEADLESS || '0') === '1';
const ALLOW_NO_SANDBOX = (process.env.OPENCLAW_BROWSER_NO_SANDBOX || '0') === '1';
let NOVNC_PASSWORD = process.env.OPENCLAW_BROWSER_NOVNC_PASSWORD || '';

const DISABLE_GRAPHICS_FLAGS = (process.env.OPENCLAW_BROWSER_DISABLE_GRAPHICS_FLAGS || '1').toLowerCase();
const DISABLE_EXTENSIONS = (process.env.OPENCLAW_BROWSER_DISABLE_EXTENSIONS || '1').toLowerCase();
const RENDERER_PROCESS_LIMIT = process.env.OPENCLAW_BROWSER_RENDERER_PROCESS_LIMIT ? parseInt(process.env.OPENCLAW_BROWSER_RENDERER_PROCESS_LIMIT, 10) : 2;
const AUTO_START_TIMEOUT_MS = parseInt(process.env.OPENCLAW_BROWSER_AUTO_START_TIMEOUT_MS || '12000', 10);

function validateUint(name, value, min = 0, max = 4294967295) {
  if (!Number.isInteger(value)) {
    console.error(`[sandbox] ERROR: ${name} must be an integer, got: ${value}`);
    process.exit(1);
  }
  if (value < min || value > max) {
    console.error(`[sandbox] ERROR: ${name} out of range (${min}..${max}), got: ${value}`);
    process.exit(1);
  }
}

validateUint("CDP_PORT", CDP_PORT, 1, 65535);
validateUint("VNC_PORT", VNC_PORT, 1, 65535);
validateUint("NOVNC_PORT", NOVNC_PORT, 1, 65535);
validateUint("AUTO_START_TIMEOUT_MS", AUTO_START_TIMEOUT_MS, 1, 2147483647);
if (process.env.OPENCLAW_BROWSER_RENDERER_PROCESS_LIMIT) {
  validateUint("RENDERER_PROCESS_LIMIT", RENDERER_PROCESS_LIMIT, 0, 2147483647);
}

// Process tracking
const processes = {
  XVFB_PID: null,
  CHROME_PID: null,
  SOCAT_PID: null,
  X11VNC_PID: null,
  WEBSOCKIFY_PID: null
};

function cleanup(code = 1) {
  process.removeAllListeners();

  const pids = Object.values(processes).filter(pid => pid !== null);
  
  if (pids.length > 0) {
    // Send TERM signal
    for (const pid of pids) {
      try {
        process.kill(pid, 'SIGTERM');
      } catch (e) {
        // Ignore errors
      }
    }

    // Wait for graceful termination
    let attempts = 0;
    const maxAttempts = 10;
    const checkInterval = 200;

    const waitForTermination = () => {
      let alive = false;
      for (const pid of pids) {
        try {
          process.kill(pid, 0); // Check if process exists
          alive = true;
          break;
        } catch (e) {
          // Process doesn't exist
        }
      }

      if (!alive || attempts >= maxAttempts) {
        // Kill remaining processes
        for (const pid of pids) {
          try {
            process.kill(pid, 'SIGKILL');
          } catch (e) {
            // Ignore errors
          }
        }
        process.exit(code);
      } else {
        attempts++;
        setTimeout(waitForTermination, checkInterval);
      }
    };

    waitForTermination();
  } else {
    process.exit(code);
  }
}

process.on('exit', () => cleanup(0));
process.on('SIGINT', () => cleanup(130));
process.on('SIGTERM', () => cleanup(143));

// Create directories
const dirs = [
  process.env.HOME,
  path.join(process.env.HOME, '.chrome'),
  process.env.XDG_CONFIG_HOME,
  process.env.XDG_CACHE_HOME
];

for (const dir of dirs) {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
}

// Start Xvfb
console.log('[sandbox] Starting Xvfb...');
const xvfb = spawn('Xvfb', [':1', '-screen', '0', '1280x800x24', '-ac', '-nolisten', 'tcp'], {
  stdio: 'ignore'
});
processes.XVFB_PID = xvfb.pid;
console.log(`[sandbox] Xvfb started (PID: ${xvfb.pid})`);

// Calculate Chrome CDP port
const CHROME_CDP_PORT = CDP_PORT >= 65535 ? CDP_PORT - 1 : CDP_PORT + 1;

// Build Chrome arguments
const CHROME_ARGS = [
  '--remote-debugging-address=127.0.0.1',
  `--remote-debugging-port=${CHROME_CDP_PORT}`,
  `--user-data-dir=${path.join(process.env.HOME, '.chrome')}`,
  '--no-first-run',
  '--no-default-browser-check',
  '--disable-dev-shm-usage',
  '--disable-background-networking',
  '--disable-breakpad',
  '--disable-crash-reporter',
  '--no-zygote',
  '--metrics-recording-only',
  '--password-store=basic',
  '--use-mock-keychain'
];

if (HEADLESS) {
  CHROME_ARGS.push('--headless=new');
}

if (ALLOW_NO_SANDBOX) {
  CHROME_ARGS.push('--no-sandbox', '--disable-setuid-sandbox');
}

if (['1', 'true', 'yes', 'on'].includes(DISABLE_GRAPHICS_FLAGS)) {
  CHROME_ARGS.push('--disable-3d-apis', '--disable-gpu', '--disable-software-rasterizer');
}

if (['1', 'true', 'yes', 'on'].includes(DISABLE_EXTENSIONS)) {
  CHROME_ARGS.push('--disable-extensions');
}

if (Number.isInteger(RENDERER_PROCESS_LIMIT) && RENDERER_PROCESS_LIMIT > 0) {
  CHROME_ARGS.push(`--renderer-process-limit=${RENDERER_PROCESS_LIMIT}`);
}

// Start Chromium
console.log('[sandbox] Starting Chromium...');
const chrome = spawn('chromium', [...CHROME_ARGS, 'about:blank'], {
  stdio: 'ignore'
});
processes.CHROME_PID = chrome.pid;
console.log(`[sandbox] Chromium started (PID: ${chrome.pid})`);

// Wait for CDP to be ready
const startTime = Date.now();
const deadline = startTime + AUTO_START_TIMEOUT_MS;
let cdpReady = false;
const probeUrl = `http://127.0.0.1:${CHROME_CDP_PORT}/json/version`;

console.log(`[sandbox] Waiting up to ${AUTO_START_TIMEOUT_MS}ms for CDP on port ${CHROME_CDP_PORT}...`);

function waitForCdp() {
  return new Promise((resolve, reject) => {
    const checkCdp = () => {
      if (Date.now() >= deadline) {
        reject(new Error(`CDP failed to start within ${AUTO_START_TIMEOUT_MS}ms.`));
        return;
      }

      // Check if Chrome is still running
      try {
        process.kill(chrome.pid, 0);
      } catch (e) {
        reject(new Error('Chromium exited before CDP became ready.'));
        return;
      }

      const curl = spawn('curl', ['-fsS', '--max-time', '0.5', probeUrl], {
        stdio: 'ignore'
      });

      curl.on('close', (code) => {
        if (code === 0) {
          resolve();
        } else {
          setTimeout(checkCdp, 200);
        }
      });
    };

    checkCdp();
  });
}

waitForCdp()
  .then(() => {
    console.log('[sandbox] CDP ready. Starting socat...');
    
    if (!CDP_SOURCE_RANGE) {
      console.warn('[sandbox-browser] WARNING: CDP_SOURCE_RANGE unset; socat CDP relay will not start.');
      console.warn('[sandbox-browser] Set OPENCLAW_BROWSER_CDP_SOURCE_RANGE to an explicit CIDR to enable CDP access.');
    } else {
      const socatListenAddr = `TCP-LISTEN:${CDP_PORT},fork,reuseaddr,bind=0.0.0.0,range=${CDP_SOURCE_RANGE}`;
      const socat = spawn('socat', [socatListenAddr, `TCP:127.0.0.1:${CHROME_CDP_PORT}`], {
        stdio: 'ignore'
      });
      processes.SOCAT_PID = socat.pid;
      console.log(`[sandbox] socat started (PID: ${socat.pid})`);
    }

    if (ENABLE_NOVNC && !HEADLESS) {
      if (!NOVNC_PASSWORD) {
        const uuid = fs.readFileSync('/proc/sys/kernel/random/uuid', 'utf8').trim();
        NOVNC_PASSWORD = uuid.replace(/-/g, '').substring(0, 8);
      }

      const vncDir = path.join(process.env.HOME, '.vnc');
      if (!fs.existsSync(vncDir)) {
        fs.mkdirSync(vncDir, { recursive: true });
      }

      // Store password
      const passwdFile = path.join(vncDir, 'passwd');
      const x11vncStore = spawn('x11vnc', ['-storepasswd', NOVNC_PASSWORD, passwdFile], {
        stdio: 'ignore'
      });

      x11vncStore.on('close', () => {
        fs.chmodSync(passwdFile, 0o600);

        // Start x11vnc
        const x11vnc = spawn('x11vnc', [
          '-display', ':1',
          '-rfbport', VNC_PORT.toString(),
          '-shared',
          '-forever',
          '-rfbauth', passwdFile,
          '-localhost'
        ], {
          stdio: 'ignore'
        });
        processes.X11VNC_PID = x11vnc.pid;
        console.log(`[sandbox] x11vnc started (PID: ${x11vnc.pid})`);

        // Start websockify
        const websockify = spawn('websockify', [
          '--web', '/usr/share/novnc/',
          NOVNC_PORT.toString(),
          `localhost:${VNC_PORT}`
        ], {
          stdio: 'ignore'
        });
        processes.WEBSOCKIFY_PID = websockify.pid;
        console.log(`[sandbox] websockify started (PID: ${websockify.pid})`);
      });
    }

    console.log('[sandbox] Container running. Monitoring all sub-processes...');
    
    // Monitor child processes
    let activeProcesses = Object.values(processes).filter(p => p !== null).length;
    
    const interval = setInterval(() => {
      let running = 0;
      for (const [name, pid] of Object.entries(processes)) {
        if (pid !== null) {
          try {
            process.kill(pid, 0);
            running++;
          } catch (e) {
            console.log(`[sandbox] Process ${name} (PID: ${pid}) exited.`);
            processes[name] = null;
          }
        }
      }
      
      if (running === 0) {
        clearInterval(interval);
        console.log('[sandbox] All processes exited.');
        process.exit(0);
      }
    }, 1000);
  })
  .catch((error) => {
    console.error(`[sandbox] ERROR: ${error.message}`);
    cleanup(1);
  });
