#!/usr/bin/env python3
# openclaw-maintenance.sh — portiert nach python
# Quelle: shell, OpenClaw@gateway2:scripts/openclaw-maintenance.sh
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

import os
import subprocess
import sys

OPENCLAW_BIN = os.environ.get('OPENCLAW_BIN', os.path.expanduser('~/.local/bin/openclaw'))

if not os.path.isfile(OPENCLAW_BIN) or not os.access(OPENCLAW_BIN, os.X_OK):
    print(f"ERROR: OpenClaw binary not found: {OPENCLAW_BIN}", file=sys.stderr)
    sys.exit(1)

def run_command(command):
    """Helper function to run a command and print its output."""
    try:
        result = subprocess.run(command, check=True, text=True, capture_output=True)
        print(result.stdout)
    except subprocess.CalledProcessError as e:
        print(f"Command failed: {' '.join(e.cmd)}", file=sys.stderr)
        print(e.stderr, file=sys.stderr)
        sys.exit(e.returncode)

# Print version of OpenClaw
print("Using OpenClaw:", end=" ")
run_command([OPENCLAW_BIN, "--version"])

# === 1. Service-/Config-Drift ===
run_command([OPENCLAW_BIN, "doctor"])

# === 2. Plugin-Stage (Registry refresh only; updates are explicit/manual) ===
run_command([OPENCLAW_BIN, "plugins", "registry", "--refresh"])
if os.environ.get("RUN_PLUGIN_UPDATE") == "1":
    run_command([OPENCLAW_BIN, "plugins", "update", "--all"])
else:
    print("Skipping plugin update. Run with RUN_PLUGIN_UPDATE=1 to enable.")

# === 3. Tasks ===
run_command([OPENCLAW_BIN, "tasks", "maintenance", "--apply"])

# === 4. Sessions – alle Agents auf einmal ===
run_command([OPENCLAW_BIN, "sessions", "cleanup", "--enforce", "--all-agents"])

# === 5. Memory – status/index decken alle Agents ab ===
run_command([OPENCLAW_BIN, "memory", "status", "--deep", "--fix"])
run_command([OPENCLAW_BIN, "memory", "index", "--force"])

# === 6. Memory promote – MUSS pro Agent ===
agents = ["main", "knecht", "docs", "ops-hub", "cron"]
for agent in agents:
    run_command([OPENCLAW_BIN, "memory", "promote", "--apply", "--agent", agent])

# === 7. Secrets ===
run_command([OPENCLAW_BIN, "secrets", "reload"])
