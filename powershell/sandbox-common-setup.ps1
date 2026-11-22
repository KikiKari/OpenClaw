#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "1c1c67d85f7f2d22a48c0de44044d5912044a7e5c1e760c2e0754471060744ac", "source_sha256": "b31f1bce542d41c8328b88079d7d58fa9d018f246f3f05fa532df8fe4ef6e153", "target_language": "powershell"}
# sandbox-common-setup.sh — portiert nach powershell
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/sandbox-common-setup.sh
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

$ErrorActionPreference = "Stop"

$BASE_IMAGE = if ($env:BASE_IMAGE) { $env:BASE_IMAGE } else { "openclaw-sandbox:bookworm-slim" }
$TARGET_IMAGE = if ($env:TARGET_IMAGE) { $env:TARGET_IMAGE } else { "openclaw-sandbox-common:bookworm-slim" }
$PACKAGES = if ($env:PACKAGES) { $env:PACKAGES } else { "curl wget jq coreutils grep nodejs npm python3 git ca-certificates golang-go rustc cargo unzip pkg-config libasound2-dev build-essential file" }
$INSTALL_PNPM = if ($env:INSTALL_PNPM) { $env:INSTALL_PNPM } else { "1" }
$INSTALL_BUN = if ($env:INSTALL_BUN) { $env:INSTALL_BUN } else { "1" }
$BUN_INSTALL_DIR = if ($env:BUN_INSTALL_DIR) { $env:BUN_INSTALL_DIR } else { "/opt/bun" }
$INSTALL_BREW = if ($env:INSTALL_BREW) { $env:INSTALL_BREW } else { "1" }
$BREW_INSTALL_DIR = if ($env:BREW_INSTALL_DIR) { $env:BREW_INSTALL_DIR } else { "/home/linuxbrew/.linuxbrew" }
$FINAL_USER = if ($env:FINAL_USER) { $env:FINAL_USER } else { "sandbox" }
$OPENCLAW_DOCKER_BUILD_USE_BUILDX = if ($env:OPENCLAW_DOCKER_BUILD_USE_BUILDX) { $env:OPENCLAW_DOCKER_BUILD_USE_BUILDX } else { "0" }
$OPENCLAW_DOCKER_BUILD_CACHE_FROM = if ($env:OPENCLAW_DOCKER_BUILD_CACHE_FROM) { $env:OPENCLAW_DOCKER_BUILD_CACHE_FROM } else { "" }
$OPENCLAW_DOCKER_BUILD_CACHE_TO = if ($env:OPENCLAW_DOCKER_BUILD_CACHE_TO) { $env:OPENCLAW_DOCKER_BUILD_CACHE_TO } else { "" }

try {
    $null = docker image inspect $BASE_IMAGE 2>$null
} catch {
    Write-Host "Base image missing: $BASE_IMAGE"
    Write-Host "Building base image via scripts/sandbox-setup.sh..."
    & scripts/sandbox-setup.sh
}

Write-Host "Building $TARGET_IMAGE with: $PACKAGES"

$build_cmd = @("docker", "build")
if ($OPENCLAW_DOCKER_BUILD_USE_BUILDX -eq "1") {
    $build_cmd = @("docker", "buildx", "build", "--load")
    if ($OPENCLAW_DOCKER_BUILD_CACHE_FROM -ne "") {
        $build_cmd += "--cache-from", $OPENCLAW_DOCKER_BUILD_CACHE_FROM
    }
    if ($OPENCLAW_DOCKER_BUILD_CACHE_TO -ne "") {
        $build_cmd += "--cache-to", $OPENCLAW_DOCKER_BUILD_CACHE_TO
    }
}

& $build_cmd `
  "-t", $TARGET_IMAGE `
  "-f", "Dockerfile.sandbox-common" `
  "--build-arg", "BASE_IMAGE=$BASE_IMAGE" `
  "--build-arg", "PACKAGES=$PACKAGES" `
  "--build-arg", "INSTALL_PNPM=$INSTALL_PNPM" `
  "--build-arg", "INSTALL_BUN=$INSTALL_BUN" `
  "--build-arg", "BUN_INSTALL_DIR=$BUN_INSTALL_DIR" `
  "--build-arg", "INSTALL_BREW=$INSTALL_BREW" `
  "--build-arg", "BREW_INSTALL_DIR=$BREW_INSTALL_DIR" `
  "--build-arg", "FINAL_USER=$FINAL_USER" `
  "."

Write-Host @"
Built $TARGET_IMAGE.
To use it, set agents.defaults.sandbox.docker.image to "$TARGET_IMAGE" and restart.
If you want a clean re-create, remove old sandbox containers:
  docker rm -f `$(docker ps -aq --filter label=openclaw.sandbox=1)
"@
