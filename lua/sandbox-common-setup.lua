#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "774e8517b491e607a58025b5af2b763ae6a2a7745186dd6dbaf1b6cf07cf1000", "source_sha256": "b31f1bce542d41c8328b88079d7d58fa9d018f246f3f05fa532df8fe4ef6e153", "target_language": "lua"}
-- sandbox-common-setup.sh — portiert nach lua
-- Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/sandbox-common-setup.sh
-- Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

local function getenv(var, default)
  return os.getenv(var) or default
end

local BASE_IMAGE = getenv("BASE_IMAGE", "openclaw-sandbox:bookworm-slim")
local TARGET_IMAGE = getenv("TARGET_IMAGE", "openclaw-sandbox-common:bookworm-slim")
local PACKAGES = getenv("PACKAGES", "curl wget jq coreutils grep nodejs npm python3 git ca-certificates golang-go rustc cargo unzip pkg-config libasound2-dev build-essential file")
local INSTALL_PNPM = getenv("INSTALL_PNPM", "1")
local INSTALL_BUN = getenv("INSTALL_BUN", "1")
local BUN_INSTALL_DIR = getenv("BUN_INSTALL_DIR", "/opt/bun")
local INSTALL_BREW = getenv("INSTALL_BREW", "1")
local BREW_INSTALL_DIR = getenv("BREW_INSTALL_DIR", "/home/linuxbrew/.linuxbrew")
local FINAL_USER = getenv("FINAL_USER", "sandbox")
local OPENCLAW_DOCKER_BUILD_USE_BUILDX = getenv("OPENCLAW_DOCKER_BUILD_USE_BUILDX", "0")
local OPENCLAW_DOCKER_BUILD_CACHE_FROM = getenv("OPENCLAW_DOCKER_BUILD_CACHE_FROM", "")
local OPENCLAW_DOCKER_BUILD_CACHE_TO = getenv("OPENCLAW_DOCKER_BUILD_CACHE_TO", "")

-- Check if base image exists
local function image_exists(image_name)
  local cmd = string.format("docker image inspect %q >/dev/null 2>&1", image_name)
  return os.execute(cmd) == 0
end

if not image_exists(BASE_IMAGE) then
  print("Base image missing: " .. BASE_IMAGE)
  print("Building base image via scripts/sandbox-setup.sh...")
  os.execute("scripts/sandbox-setup.sh")
end

print("Building " .. TARGET_IMAGE .. " with: " .. PACKAGES)

local build_cmd = {"docker", "build"}
if OPENCLAW_DOCKER_BUILD_USE_BUILDX == "1" then
  build_cmd = {"docker", "buildx", "build", "--load"}
  if OPENCLAW_DOCKER_BUILD_CACHE_FROM ~= "" then
    table.insert(build_cmd, "--cache-from")
    table.insert(build_cmd, OPENCLAW_DOCKER_BUILD_CACHE_FROM)
  end
  if OPENCLAW_DOCKER_BUILD_CACHE_TO ~= "" then
    table.insert(build_cmd, "--cache-to")
    table.insert(build_cmd, OPENCLAW_DOCKER_BUILD_CACHE_TO)
  end
end

local build_command = table.concat(build_cmd, " ") ..
  " -t " .. TARGET_IMAGE ..
  " -f Dockerfile.sandbox-common" ..
  " --build-arg BASE_IMAGE=" .. BASE_IMAGE ..
  " --build-arg PACKAGES=" .. PACKAGES ..
  " --build-arg INSTALL_PNPM=" .. INSTALL_PNPM ..
  " --build-arg INSTALL_BUN=" .. INSTALL_BUN ..
  " --build-arg BUN_INSTALL_DIR=" .. BUN_INSTALL_DIR ..
  " --build-arg INSTALL_BREW=" .. INSTALL_BREW ..
  " --build-arg BREW_INSTALL_DIR=" .. BREW_INSTALL_DIR ..
  " --build-arg FINAL_USER=" .. FINAL_USER ..
  " ."

os.execute(build_command)

print(string.format([[
Built %s.
To use it, set agents.defaults.sandbox.docker.image to "%s" and restart.
If you want a clean re-create, remove old sandbox containers:
  docker rm -f $(docker ps -aq --filter label=openclaw.sandbox=1)
]], TARGET_IMAGE, TARGET_IMAGE))
