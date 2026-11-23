#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "38200d263830bbb3e5373da1f86dedffa9c40c9a3b5f760f2e11fd99c51e43f0", "source_sha256": "df77fd3273a53bf6d33c1c4df50c24d9526e06de477779a9b7a58f5b8ce3ed1d", "target_language": "python"}
# test-cleanup-docker.sh — portiert nach python
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/test-cleanup-docker.sh
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

import os
import subprocess
import sys

def run_logged(name, *args):
    """Run a command and log its execution"""
    print(f"[{name}] Running: {' '.join(args)}", file=sys.stderr)
    result = subprocess.run(args, cwd=ROOT_DIR)
    if result.returncode != 0:
        print(f"[{name}] Failed with exit code {result.returncode}", file=sys.stderr)
        sys.exit(result.returncode)

# Get the root directory
script_dir = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR = os.path.normpath(os.path.join(script_dir, ".."))

# Source the docker-e2e-logs.sh functionality (simulated here)
# In the original script, this defines run_logged function which we've implemented above

# Get environment variables with defaults
IMAGE_NAME = os.environ.get("OPENCLAW_CLEANUP_SMOKE_IMAGE", "openclaw-cleanup-smoke:local")
PLATFORM = os.environ.get("OPENCLAW_CLEANUP_SMOKE_PLATFORM", "linux/amd64")

print(f"==> Build image: {IMAGE_NAME}")

# Build the docker image
run_logged(
    "cleanup-build",
    "docker", "build",
    "-t", IMAGE_NAME,
    "-f", os.path.join(ROOT_DIR, "scripts/docker/cleanup-smoke/Dockerfile"),
    ROOT_DIR
)

print("==> Run cleanup smoke test")

# Run the docker container
result = subprocess.run([
    "docker", "run", "--rm", "--platform", PLATFORM, "-t", IMAGE_NAME
])

sys.exit(result.returncode)
