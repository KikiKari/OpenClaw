#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "aa9c3a56d1303463336281594019b75de8fdd81937da804569c95b7b65218734", "source_sha256": "b31f1bce542d41c8328b88079d7d58fa9d018f246f3f05fa532df8fe4ef6e153", "target_language": "python"}
# sandbox-common-setup.sh — portiert nach python
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/sandbox-common-setup.sh
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

import os
import subprocess
import sys

BASE_IMAGE = os.environ.get('BASE_IMAGE', 'openclaw-sandbox:bookworm-slim')
TARGET_IMAGE = os.environ.get('TARGET_IMAGE', 'openclaw-sandbox-common:bookworm-slim')
PACKAGES = os.environ.get('PACKAGES', 'curl wget jq coreutils grep nodejs npm python3 git ca-certificates golang-go rustc cargo unzip pkg-config libasound2-dev build-essential file')
INSTALL_PNPM = os.environ.get('INSTALL_PNPM', '1')
INSTALL_BUN = os.environ.get('INSTALL_BUN', '1')
BUN_INSTALL_DIR = os.environ.get('BUN_INSTALL_DIR', '/opt/bun')
INSTALL_BREW = os.environ.get('INSTALL_BREW', '1')
BREW_INSTALL_DIR = os.environ.get('BREW_INSTALL_DIR', '/home/linuxbrew/.linuxbrew')
FINAL_USER = os.environ.get('FINAL_USER', 'sandbox')
OPENCLAW_DOCKER_BUILD_USE_BUILDX = os.environ.get('OPENCLAW_DOCKER_BUILD_USE_BUILDX', '0')
OPENCLAW_DOCKER_BUILD_CACHE_FROM = os.environ.get('OPENCLAW_DOCKER_BUILD_CACHE_FROM', '')
OPENCLAW_DOCKER_BUILD_CACHE_TO = os.environ.get('OPENCLAW_DOCKER_BUILD_CACHE_TO', '')

try:
    subprocess.run(['docker', 'image', 'inspect', BASE_IMAGE], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
except subprocess.CalledProcessError:
    print(f"Base image missing: {BASE_IMAGE}")
    print("Building base image via scripts/sandbox-setup.sh...")
    subprocess.run(['scripts/sandbox-setup.sh'], check=True)

print(f"Building {TARGET_IMAGE} with: {PACKAGES}")

build_cmd = ['docker', 'build']
if OPENCLAW_DOCKER_BUILD_USE_BUILDX == '1':
    build_cmd = ['docker', 'buildx', 'build', '--load']
    if OPENCLAW_DOCKER_BUILD_CACHE_FROM:
        build_cmd.extend(['--cache-from', OPENCLAW_DOCKER_BUILD_CACHE_FROM])
    if OPENCLAW_DOCKER_BUILD_CACHE_TO:
        build_cmd.extend(['--cache-to', OPENCLAW_DOCKER_BUILD_CACHE_TO])

build_args = [
    '-t', TARGET_IMAGE,
    '-f', 'Dockerfile.sandbox-common',
    '--build-arg', f'BASE_IMAGE={BASE_IMAGE}',
    '--build-arg', f'PACKAGES={PACKAGES}',
    '--build-arg', f'INSTALL_PNPM={INSTALL_PNPM}',
    '--build-arg', f'INSTALL_BUN={INSTALL_BUN}',
    '--build-arg', f'BUN_INSTALL_DIR={BUN_INSTALL_DIR}',
    '--build-arg', f'INSTALL_BREW={INSTALL_BREW}',
    '--build-arg', f'BREW_INSTALL_DIR={BREW_INSTALL_DIR}',
    '--build-arg', f'FINAL_USER={FINAL_USER}',
    '.'
]

subprocess.run(build_cmd + build_args, check=True)

note = f"""
Built {TARGET_IMAGE}.
To use it, set agents.defaults.sandbox.docker.image to "{TARGET_IMAGE}" and restart.
If you want a clean re-create, remove old sandbox containers:
  docker rm -f $(docker ps -aq --filter label=openclaw.sandbox=1)
"""

print(note)
