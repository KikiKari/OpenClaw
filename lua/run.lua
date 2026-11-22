#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "bba6f1750a1f3171fc01c81288c2672f6a941519cea344dbac94a9c3f28912db", "source_sha256": "9bab70cc20775da1defcfadbbbef9ceb0f983a51d1a3988a76a20843d64c8471", "target_language": "lua"}
-- run.sh — portiert nach lua
-- Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/docker/install-sh-nonroot/run.sh
-- Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

local function execute_command(command)
  local handle = io.popen(command .. " 2>/dev/null", "r")
  if not handle then
    return nil
  end
  local result = handle:read("*a")
  handle:close()
  return result and result:gsub("%s+$", "")
end

local function command_exists(command)
  return os.execute("command -v " .. command .. " >/dev/null 2>&1") == 0
end

local function fail(message)
  io.stderr:write(message .. "\n")
  os.exit(1)
end

-- Environment variables with defaults
local INSTALL_URL = os.getenv("OPENCLAW_INSTALL_URL") or "https://openclaw.bot/install.sh"
local DEFAULT_PACKAGE = "openclaw"
local PACKAGE_NAME = os.getenv("OPENCLAW_INSTALL_PACKAGE") or DEFAULT_PACKAGE
local EXPECTED_VERSION = os.getenv("OPENCLAW_INSTALL_EXPECT_VERSION") or ""

print("==> Pre-flight: ensure git absent")
if command_exists("git") then
  fail("git is present unexpectedly")
end

print("==> Pre-flight: ensure supported Node is already present")

-- Check Node.js version
local node_version_output = execute_command("node -v")
if not node_version_output then
  fail("Node.js not found")
end

local version_string = node_version_output:gsub("^v", "")
local major, minor = version_string:match("(%d+)%.(%d+)")

if not major or not minor then
  fail("Could not parse Node.js version")
end

major, minor = tonumber(major), tonumber(minor)

if major < 22 or (major == 22 and minor < 16) then
  fail("unsupported node " .. version_string)
end

if not command_exists("npm") then
  fail("npm not found")
end

print("==> Run installer (non-root user)")

-- Download and execute install script
local install_result = os.execute("curl -fsSL " .. INSTALL_URL .. " | bash")
if install_result ~= 0 then
  fail("Installer failed")
end

-- Set PATH to include user npm prefix
local home_dir = os.getenv("HOME")
local npm_bin_path = home_dir .. "/.npm-global/bin"
local current_path = os.getenv("PATH") or ""
os.setenv("PATH", npm_bin_path .. ":" .. current_path)

print("==> Verify git installed")
if not command_exists("git") then
  fail("git not installed after installation")
end

-- Get latest version
local LATEST_VERSION
if EXPECTED_VERSION ~= "" then
  LATEST_VERSION = EXPECTED_VERSION
else
  local npm_view_cmd = string.format('npm view "%s" version', PACKAGE_NAME)
  LATEST_VERSION = execute_command(npm_view_cmd)
  if not LATEST_VERSION then
    fail("Could not determine package version")
  end
end

print("==> Verify CLI installed")

-- Verify installed CLI version
local installed_version = execute_command(PACKAGE_NAME .. " --version")
if not installed_version then
  installed_version = execute_command(PACKAGE_NAME .. " -v")
  if not installed_version then
    fail("Could not get installed CLI version")
  end
end

-- Compare versions (simple comparison)
if installed_version ~= LATEST_VERSION then
  fail(string.format("Version mismatch: expected %s, got %s", LATEST_VERSION, installed_version))
end

print("OK")
