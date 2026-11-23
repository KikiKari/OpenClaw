#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "8c58479772079325bb713d630fe5f37b29e193729f68e60826bb43df56b3631d", "source_sha256": "cb5f3c66f2f8ef6dd2ba9a71832aceb3d4c3af596567dad4241cf94d8e3fd8ba", "target_language": "javascript"}
// setup-auth-system.sh — portiert nach javascript
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/setup-auth-system.sh
// Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

// Setup OpenClaw Auth Management System
// Run this once to set up:
// 1. Long-lived Claude Code token
// 2. Auth monitoring with notifications
// 3. Instructions for Termux widgets

import { execSync } from 'child_process';
import { writeFileSync, readFileSync, existsSync, mkdirSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import readline from 'readline';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

function question(prompt) {
  return new Promise((resolve) => {
    rl.question(prompt, resolve);
  });
}

function runCommand(command) {
  try {
    return execSync(command, { encoding: 'utf8', stdio: 'pipe' });
  } catch (error) {
    return error.stdout || '';
  }
}

async function main() {
  console.log("=== OpenClaw Auth System Setup ===\n");

  // Step 1: Check current auth status
  console.log("Step 1: Checking current auth status...");
  runCommand(`"${join(__dirname, 'claude-auth-status.sh')}" full`);
  console.log("");

  // Step 2: Set up long-lived token
  console.log("Step 2: Long-lived token setup\n");
  console.log("Option A: Use 'claude setup-token' (recommended)");
  console.log("  - Creates a long-lived API token");
  console.log("  - No daily re-auth needed");
  console.log("  - Run: claude setup-token\n");

  const setupToken = await question("Would you like to set up a long-lived token now? [y/N] ");
  
  if (setupToken.toLowerCase().startsWith('y')) {
    console.log("\nOpening https://console.anthropic.com/settings/api-keys");
    console.log("Create a new key or copy existing one, then paste below.\n");
    
    try {
      execSync('claude setup-token', { stdio: 'inherit' });
    } catch (error) {
      console.error("Error running claude setup-token");
    }
  }

  console.log("");

  // Step 3: Set up auth monitoring
  console.log("Step 3: Auth monitoring setup\n");
  console.log("The auth monitor checks expiry every 30 minutes and notifies you.\n");
  console.log("Configure notification channels:\n");

  // Check for ntfy
  console.log("  ntfy.sh: Free push notifications to your phone");
  console.log("  1. Install ntfy app on your phone");
  console.log("  2. Subscribe to a topic (e.g., 'openclaw-alerts')\n");
  
  const ntfyTopic = await question("Enter ntfy.sh topic (or leave blank to skip): ");

  // Phone notification
  console.log("");
  console.log("  OpenClaw message: Send warning via OpenClaw itself");
  const phoneNumber = await question("Enter your phone number for alerts (or leave blank to skip): ");

  // Update service file
  const serviceFile = join(__dirname, 'systemd', 'openclaw-auth-monitor.service');
  let serviceContent = readFileSync(serviceFile, 'utf8');

  if (ntfyTopic.trim()) {
    serviceContent = serviceContent.replace(
      /# Environment=NOTIFY_NTFY=.*/,
      `Environment=NOTIFY_NTFY=${ntfyTopic}`
    );
  }

  if (phoneNumber.trim()) {
    serviceContent = serviceContent.replace(
      /# Environment=NOTIFY_PHONE=.*/,
      `Environment=NOTIFY_PHONE=${phoneNumber}`
    );
  }

  writeFileSync(serviceFile, serviceContent);

  // Install systemd units
  console.log("\nInstalling systemd timer...");
  const systemdDir = join(process.env.HOME, '.config', 'systemd', 'user');
  mkdirSync(systemdDir, { recursive: true });

  const sourceService = join(__dirname, 'systemd', 'openclaw-auth-monitor.service');
  const sourceTimer = join(__dirname, 'systemd', 'openclaw-auth-monitor.timer');
  const destService = join(systemdDir, 'openclaw-auth-monitor.service');
  const destTimer = join(systemdDir, 'openclaw-auth-monitor.timer');

  writeFileSync(destService, readFileSync(sourceService));
  writeFileSync(destTimer, readFileSync(sourceTimer));

  try {
    execSync('systemctl --user daemon-reload', { stdio: 'ignore' });
    execSync('systemctl --user enable --now openclaw-auth-monitor.timer', { stdio: 'ignore' });
    console.log("Auth monitor installed and running.");
  } catch (error) {
    console.error("Failed to install systemd services");
  }

  console.log("");

  // Step 4: Termux widget setup
  console.log("Step 4: Termux widget setup (for phone)\n");
  console.log("To set up quick auth from your phone:");
  console.log("");
  console.log("1. Install Termux and Termux:Widget from F-Droid");
  console.log("2. Create ~/.shortcuts/ directory in Termux:");
  console.log("   mkdir -p ~/.shortcuts");
  console.log("");
  console.log("3. Copy the widget scripts:");
  console.log(`   scp ${join(__dirname, 'termux-quick-auth.sh')} phone:~/.shortcuts/ClawdAuth`);
  console.log(`   scp ${join(__dirname, 'termux-auth-widget.sh')} phone:~/.shortcuts/ClawdAuth-Full`);
  console.log("");
  console.log("4. Make them executable on phone:");
  console.log("   ssh phone 'chmod +x ~/.shortcuts/Clawd*'");
  console.log("");
  console.log("5. Add Termux:Widget to your home screen");
  console.log("6. Tap the widget to see your auth scripts");
  console.log("");
  console.log("The quick widget (ClawdAuth) shows status and opens auth URL if needed.");
  console.log("The full widget (ClawdAuth-Full) provides guided re-auth flow.");
  console.log("");

  // Summary
  console.log("=== Setup Complete ===\n");
  console.log("What's configured:");
  console.log(`  - Auth status: ${join(__dirname, 'claude-auth-status.sh')}`);
  console.log(`  - Mobile re-auth: ${join(__dirname, 'mobile-reauth.sh')}`);
  console.log("  - Auth monitor: systemctl --user status openclaw-auth-monitor.timer\n");
  console.log("Quick commands:");
  console.log(`  Check auth:  ${join(__dirname, 'claude-auth-status.sh')}`);
  console.log(`  Re-auth:     ${join(__dirname, 'mobile-reauth.sh')}`);
  console.log(`  Test monitor: ${join(__dirname, 'auth-monitor.sh')}\n`);

  rl.close();
}

main().catch(console.error);
