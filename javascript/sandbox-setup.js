#!/usr/bin/env node
// sandbox-setup.sh — portiert nach javascript
// Quelle: shell, Onboarding@main:scripts/sandbox-setup.sh
// Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

// Provisioniert die Claude-Code-Sandbox (Remote-Umgebung) reproduzierbar:
//   - Node-Dependencies (Frontend, npm)
//   - Python-Dependencies (Backend inkl. pytest)
//   - Medien-Tools: ffmpeg, ImageMagick, GIMP, Blender headless (apt) —
//     Fehlschlag blockiert die Session nicht; --skip-heavy laesst GIMP/Blender aus
// Idempotent: bereits Vorhandenes wird uebersprungen; der Container-Cache der
// Umgebung macht die apt-Installation zum Einmal-Aufwand.

const fs = require('fs');
const path = require('path');
const { spawnSync, execSync } = require('child_process');

const SKIP_HEAVY = process.argv.includes('--skip-heavy') ? 1 : 0;

process.chdir(path.join(__dirname, '..'));

function log(message) {
  console.log(`[sandbox-setup] ${message}`);
}

function runCommand(command, args = [], options = {}) {
  const result = spawnSync(command, args, { encoding: 'utf8', ...options });
  return {
    success: result.status === 0,
    output: result.stdout || result.stderr,
    error: result.error
  };
}

function commandExists(command) {
  return runCommand('which', [command]).success;
}

function getVersion(command, versionArg = '--version') {
  try {
    const result = spawnSync(command, [versionArg], { encoding: 'utf8' });
    return result.stdout.split('\n')[0] || result.stderr.split('\n')[0] || '';
  } catch (error) {
    return '';
  }
}

log("Node-Dependencies (npm install) …");
let result = runCommand('npm', ['install', '--no-audit', '--no-fund']);
if (!result.success) {
  log("FEHLER: npm install fehlgeschlagen");
  process.exit(1);
}

log("Python-Dependencies (backend/requirements-dev.txt) …");
result = runCommand('pip3', ['install', '--quiet', '-r', 'backend/requirements-dev.txt']);
if (!result.success) {
  log("FEHLER: pip install fehlgeschlagen");
  process.exit(1);
}

let APT_UPDATED = false;

function aptInstall(pkg, bin) {
  if (commandExists(bin)) {
    const versionInfo = getVersion(bin, ['-version']) || getVersion(bin, ['--version']) || '';
    log(`${pkg} bereits vorhanden (${versionInfo})`);
    return true;
  }
  
  log(`Installiere ${pkg} …`);
  try {
    if (!APT_UPDATED) {
      execSync('DEBIAN_FRONTEND=noninteractive apt-get update -qq', { stdio: 'pipe' });
      APT_UPDATED = true;
    }
    execSync(`DEBIAN_FRONTEND=noninteractive apt-get install -y -qq ${pkg}`, { stdio: 'pipe' });
    return true;
  } catch (error) {
    log(`WARNUNG: ${pkg} konnte nicht installiert werden (Netzwerk-Policy?) — Medien-Schritte ggf. eingeschraenkt`);
    return false;
  }
}

aptInstall('ffmpeg', 'ffmpeg');
aptInstall('imagemagick', 'convert');
if (SKIP_HEAVY === 0) {
  aptInstall('gimp', 'gimp');
  aptInstall('blender', 'blender');
}

// Visual QA tools
aptInstall('xvfb', 'Xvfb');
aptInstall('x11-utils', 'xdpyinfo');
aptInstall('libnss3-tools', 'certutil');

if (!commandExists('google-chrome-stable')) {
  log("Installiere Google Chrome Stable …");
  try {
    const tmpDeb = '/tmp/chrome.deb';
    execSync(`curl -fsSL -o ${tmpDeb} https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb`, { stdio: 'pipe' });
    execSync(`DEBIAN_FRONTEND=noninteractive apt-get install -y -qq ${tmpDeb}`, { stdio: 'pipe' });
    const chromeVersion = getVersion('google-chrome-stable', ['--version']);
    if (chromeVersion) {
      log(`Chrome installiert: ${chromeVersion}`);
    } else {
      log("WARNUNG: Chrome-Installation fehlgeschlagen");
    }
    fs.unlinkSync(tmpDeb);
  } catch (error) {
    log("WARNUNG: Chrome-Download fehlgeschlagen (Netzwerk-Policy?)");
  }
}

// Proxy-CA in Chromes NSS-DB
if (commandExists('certutil') && fs.existsSync('/root/.ccr/ca-bundle.crt')) {
  const nssdbPath = path.join(process.env.HOME || '', '.pki/nssdb');
  try {
    fs.mkdirSync(nssdbPath, { recursive: true });
    execSync(`certutil -d sql:${nssdbPath} -N --empty-password`, { stdio: 'ignore' });
    
    try {
      execSync(`certutil -d sql:${nssdbPath} -L`, { stdio: 'pipe' });
      const certExists = execSync(`certutil -d sql:${nssdbPath} -L`, { encoding: 'utf8' }).includes('ccr-proxy-ca');
      if (!certExists) {
        execSync(`certutil -d sql:${nssdbPath} -A -t "C,," -n ccr-proxy-ca -i /root/.ccr/ca-bundle.crt`, { stdio: 'ignore' });
        log("Proxy-CA in Chrome-NSS-Store importiert");
      }
    } catch (error) {
      // continue regardless of error
    }
  } catch (error) {
    // continue regardless of error
  }
}

// Playwright installation
if (fs.existsSync('node_modules') && !fs.existsSync('node_modules/playwright')) {
  if (commandExists('npm')) {
    result = runCommand('npm', ['install', '--no-audit', '--no-fund', '--no-save', 'playwright'], { stdio: 'pipe' });
    if (result.success) {
      log("Playwright (Node) installiert");
    } else {
      log("WARNUNG: Playwright-npm-Install fehlgeschlagen");
    }
  }
}

// Git configuration
try {
  if (spawnSync('git', ['rev-parse', '--is-inside-work-tree'], { stdio: 'ignore' }).status === 0) {
    const pwd = process.cwd();
    execSync(`git config credential."https://x-access-token@github.com".helper "!${pwd}/.claude/git-credential-pat.sh"`, { stdio: 'ignore' });
    execSync('git remote set-url --push origin "https://x-access-token@github.com/KikiKari/Onboarding.git"', { stdio: 'ignore' });
    log("Git-Push-Route: direkt zu github.com (PAT via Credential-Helper)");
  }
} catch (error) {
  // continue regardless of error
}

// Docker daemon
if (commandExists('dockerd') && spawnSync('docker', ['info'], { stdio: 'ignore' }).status !== 0) {
  log("Starte Docker-Daemon (Registry-Mirror: mirror.gcr.io) …");
  try {
    fs.mkdirSync('/etc/docker', { recursive: true });
    const daemonJsonPath = '/etc/docker/daemon.json';
    if (!fs.existsSync(daemonJsonPath)) {
      fs.writeFileSync(daemonJsonPath, '{"registry-mirrors":["https://mirror.gcr.io"]}');
    }
    
    // Start docker daemon in background
    spawnSync('dockerd', [], { stdio: 'ignore', detached: true });
    
    // Wait for docker to start
    let dockerStarted = false;
    for (let i = 0; i < 15; i++) {
      if (spawnSync('docker', ['info'], { stdio: 'ignore' }).status === 0) {
        dockerStarted = true;
        break;
      }
      execSync('sleep 1', { stdio: 'ignore' });
    }
    
    if (dockerStarted) {
      log("Docker-Daemon laeuft");
    } else {
      log("WARNUNG: Docker-Daemon nicht gestartet");
    }
  } catch (error) {
    log("WARNUNG: Docker-Daemon nicht gestartet");
  }
}

log("Fertig. Versionen:");
console.log(`[sandbox-setup]   node ${getVersion('node')}`);
console.log(`[sandbox-setup]   ${getVersion('python3')}`);

if (commandExists('ffmpeg')) {
  console.log(`[sandbox-setup]   ${getVersion('ffmpeg', ['-version']).split('\n')[0]}`);
}
if (commandExists('convert')) {
  console.log(`[sandbox-setup]   ${getVersion('convert', ['-version']).split('\n')[0]}`);
}
if (commandExists('gimp')) {
  console.log(`[sandbox-setup]   ${getVersion('gimp', ['--version']).split('\n')[0]}`);
}
if (commandExists('blender')) {
  console.log(`[sandbox-setup]   ${getVersion('blender', ['--version']).split('\n')[0]}`);
}

process.exit(0);
