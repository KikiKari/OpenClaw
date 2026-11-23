#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "3496f1be8aafbec329bf261de218ed5171d680a5257a310a365807b410d0c684", "source_sha256": "df77fd3273a53bf6d33c1c4df50c24d9526e06de477779a9b7a58f5b8ce3ed1d", "target_language": "lua"}
-- test-cleanup-docker.sh — portiert nach lua
-- Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/test-cleanup-docker.sh
-- Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

local function execute_command(command)
  local handle = io.popen(command .. " 2>&1")
  local result = handle:read("*a")
  local success, _, exit_code = handle:close()
  return success, result, exit_code
end

local function run_logged(name, command)
  print("Running: " .. name)
  print("Command: " .. command)
  
  local success, output, exit_code = execute_command(command)
  
  if not success then
    print("Error running " .. name .. ": " .. output)
    os.exit(exit_code or 1)
  end
  
  print(output)
end

-- Get script directory and root directory
local script_dir = arg[0]:match("(.*/)") or "./"
local root_dir = script_dir .. "../"

-- Normalize paths
root_dir = root_dir:gsub("/%./", "/"):gsub("//", "/")
if root_dir:sub(-1) == "/" then
  root_dir = root_dir:sub(1, -2)
end

-- Source the logging library functionality (simplified implementation)
-- In the original script it sources docker-e2e-logs.sh but we implement the needed function here

local image_name = os.getenv("OPENCLAW_CLEANUP_SMOKE_IMAGE") or "openclaw-cleanup-smoke:local"
local platform = os.getenv("OPENCLAW_CLEANUP_SMOKE_PLATFORM") or "linux/amd64"

print("==> Build image: " .. image_name)

local build_command = string.format(
  "docker build -t %s -f %s %s", 
  image_name, 
  root_dir .. "/scripts/docker/cleanup-smoke/Dockerfile", 
  root_dir
)

run_logged("cleanup-build", build_command)

print("==> Run cleanup smoke test")

local run_command = string.format(
  "docker run --rm --platform %s -t %s", 
  platform, 
  image_name
)

local success, output, exit_code = execute_command(run_command)

if not success then
  print("Error running cleanup smoke test: " .. output)
  os.exit(exit_code or 1)
end

print(output)
