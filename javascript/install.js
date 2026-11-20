#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "ad2bfadd50ef296c3c88c682ca3a871bc354749ebbe7a38b8ce3f591aca9db87", "source_sha256": "4a2907e2ea521dc1e81ebd6e57ee9ab2269d633101a5fe398c3b55dfc0d99040", "target_language": "javascript"}
// install.ps1 — portiert nach javascript
// Quelle: powershell, workspace@local:skills/github-clones/openclaw/scripts/install.ps1
// Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

// OpenClaw Installer for Windows (Node.js)
// Usage: node install.js
// Or: node install.js --no-onboard

const fs = require('fs');
const path = require('path');
const { spawn, execSync } = require('child_process');
const os = require('os');

// CLI arguments
const args = process.argv.slice(2);
let installMethod = 'npm';
let tag = 'latest';
let gitDir = path.join(os.homedir(), 'openclaw');
let noOnboard = false;
let noGitUpdate = false;
let dryRun = false;

for (let i = 0; i < args.length; i++) {
  switch (args[i]) {
    case '--install-method':
      installMethod = args[++i];
      break;
    case '--tag':
      tag = args[++i];
      break;
    case '--git-dir':
      gitDir = args[++i];
      break;
    case '--no-onboard':
      noOnboard = true;
      break;
    case '--no-git-update':
      noGitUpdate = true;
      break;
    case '--dry-run':
      dryRun = true;
      break;
  }
}

// Colors
const ACCENT = '\x1b[38;2;255;77;77m';    // coral-bright
const SUCCESS = '\x1b[38;2;0;229;204m';   // cyan-bright
const WARN = '\x1b[38;2;255;176;32m';     // amber
const ERROR = '\x1b[38;2;230;57;70m';     // coral-mid
const MUTED = '\x1b[38;2;90;100;128m';    // text-muted
const NC = '\x1b[0m';                     // No Color

function writeHost(message, level = 'info') {
  let msg;
  switch (level) {
    case 'success':
      msg = `${SUCCESS}✓${NC} ${message}`;
      break;
    case 'warn':
      msg = `${WARN}!${NC} ${message}`;
      break;
    case 'error':
      msg = `${ERROR}✗${NC} ${message}`;
      break;
    default:
      msg = `${MUTED}·${NC} ${message}`;
  }
  console.log(msg);
}

function writeBanner() {
  writeHost('');
  writeHost(`${ACCENT}  🦞 OpenClaw Installer${NC}`, 'info');
  writeHost(`${MUTED}  All your chats, one OpenClaw.${NC}`, 'info');
  writeHost('');
}

function getNodeVersion() {
  try {
    const version = execSync('node --version', { stdio: 'pipe' }).toString().trim();
    return version.replace(/^v/, '');
  } catch (e) {
    return null;
  }
}

function getNpmVersion() {
  try {
    return execSync('npm --version', { stdio: 'pipe' }).toString().trim();
  } catch (e) {
    return null;
  }
}

function installNode() {
  writeHost('Node.js not found', 'info');
  writeHost('Please install Node.js 22+ manually from: https://nodejs.org', 'info');
  return false;
}

function ensureNode() {
  const nodeVersion = getNodeVersion();
  if (nodeVersion) {
    const major = parseInt(nodeVersion.split('.')[0], 10);
    if (major >= 22) {
      writeHost(`Node.js v${nodeVersion} found`, 'success');
      return true;
    }
    writeHost(`Node.js v${nodeVersion} found, but need v22+`, 'warn');
  }
  return installNode();
}

function getGitVersion() {
  try {
    return execSync('git --version', { stdio: 'pipe' }).toString().trim();
  } catch (e) {
    return null;
  }
}

function installGit() {
  writeHost('Git not found', 'info');
  writeHost('Please install Git for Windows from: https://git-scm.com', 'error');
  return false;
}

function ensureGit() {
  const gitVersion = getGitVersion();
  if (gitVersion) {
    writeHost(`${gitVersion} found`, 'success');
    return true;
  }
  return installGit();
}

function installOpenClawNpm(target) {
  const installSpec = resolvePackageInstallSpec(target);
  writeHost(`Installing OpenClaw (${installSpec})...`, 'info');
  
  return new Promise((resolve) => {
    const npm = spawn('npm', ['install', '-g', installSpec, '--no-fund', '--no-audit'], {
      stdio: 'inherit',
      shell: true
    });
    
    npm.on('close', (code) => {
      if (code === 0) {
        writeHost('OpenClaw installed', 'success');
        resolve(true);
      } else {
        writeHost(`npm install failed with code ${code}`, 'error');
        resolve(false);
      }
    });
  });
}

function installOpenClawGit(repoDir, update) {
  writeHost('Installing OpenClaw from git...', 'info');
  
  if (!fs.existsSync(repoDir)) {
    writeHost('  Cloning repository...', 'info');
    execSync(`git clone https://github.com/openclaw/openclaw.git "${repoDir}"`, { stdio: 'inherit' });
  } else if (update) {
    writeHost('  Updating repository...', 'info');
    execSync(`git -C "${repoDir}" pull --rebase`, { stdio: 'inherit' });
  }
  
  // Install pnpm if not present
  try {
    execSync('pnpm --version', { stdio: 'ignore' });
  } catch (e) {
    writeHost('  Installing pnpm...', 'info');
    execSync('npm install -g pnpm', { stdio: 'inherit' });
  }
  
  // Install dependencies
  writeHost('  Installing dependencies...', 'info');
  execSync(`pnpm install --dir "${repoDir}"`, { stdio: 'inherit' });
  
  // Build
  writeHost('  Building...', 'info');
  execSync(`pnpm --dir "${repoDir}" build`, { stdio: 'inherit' });
  
  // Create wrapper
  const wrapperDir = path.join(os.homedir(), '.local', 'bin');
  if (!fs.existsSync(wrapperDir)) {
    fs.mkdirSync(wrapperDir, { recursive: true });
  }
  
  const wrapperContent = `@echo off\nnode "%~dp0..\\openclaw\\dist\\entry.js" %*\n`;
  fs.writeFileSync(path.join(wrapperDir, 'openclaw.cmd'), wrapperContent);
  
  writeHost('OpenClaw installed', 'success');
  return true;
}

function testExplicitPackageInstallSpec(target) {
  if (!target || target.trim() === '') {
    return false;
  }
  
  return target.includes('://') ||
         target.includes('#') ||
         /^(file|github|git\+ssh|git\+https|git\+http|git\+file|npm):/.test(target);
}

function resolvePackageInstallSpec(target = 'latest') {
  const trimmed = target.trim();
  if (!trimmed) {
    return 'openclaw@latest';
  }
  if (trimmed.toLowerCase() === 'main') {
    return 'github:openclaw/openclaw#main';
  }
  if (testExplicitPackageInstallSpec(trimmed)) {
    return trimmed;
  }
  return `openclaw@${trimmed}`;
}

function addToPath(newPath) {
  const currentPath = process.env.PATH || '';
  if (!currentPath.includes(newPath)) {
    process.env.PATH += `;${newPath}`;
    writeHost(`Added ${newPath} to PATH`, 'info');
  }
}

async function main() {
  writeBanner();
  writeHost('Windows detected', 'success');
  
  if (!ensureNode()) {
    process.exit(1);
  }
  
  if (installMethod === 'git') {
    if (!ensureGit()) {
      process.exit(1);
    }
    
    if (dryRun) {
      writeHost(`[DRY RUN] Would install OpenClaw from git to ${gitDir}`, 'info');
    } else {
      installOpenClawGit(gitDir, !noGitUpdate);
    }
  } else {
    // npm method
    if (!ensureGit()) {
      writeHost('Git is required for npm installs. Please install Git and try again.', 'warn');
    }
    
    if (dryRun) {
      writeHost(`[DRY RUN] Would install OpenClaw via npm (${resolvePackageInstallSpec(tag)})`, 'info');
    } else {
      if (!(await installOpenClawNpm(tag))) {
        process.exit(1);
      }
    }
  }
  
  // Try to add npm global bin to PATH
  try {
    const npmPrefix = execSync('npm config get prefix', { stdio: 'pipe' }).toString().trim();
    if (npmPrefix) {
      addToPath(npmPrefix);
    }
  } catch (e) {}
  
  if (!noOnboard && !dryRun) {
    writeHost('');
    writeHost("Run 'openclaw onboard' to complete setup", 'info');
  }
  
  writeHost('');
  writeHost('🦞 OpenClaw installed successfully!', 'success');
}

main();
