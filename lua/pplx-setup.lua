#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "7dba85fb45acb0d2ed45d6bf8138134edc5361d62696d6d4a05a7efd83d93d6a", "source_sha256": "d32ac11e0dc05ad59745834c2a59aec92d846417b8f7f07d0d21d66ae469c743", "target_language": "lua"}
-- pplx-setup.sh — portiert nach lua
-- Quelle: shell, OpenClaw@main:scripts/pplx-tools/pplx-setup.sh
-- Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

-- One-time (idempotent): make sure the Perplexity VS Code extension daemon can
-- find a Chromium. The daemon uses its OWN bundled patchright, which pins a
-- specific chromium revision; install exactly that revision.

local function execute_command(command)
    local handle = io.popen(command .. " 2>/dev/null", "r")
    if not handle then
        return nil
    end
    local result = handle:read("*a")
    handle:close()
    return result and result:gsub("%s+$", "") or nil
end

local function file_exists(path)
    local file = io.open(path, "r")
    if file then
        file:close()
        return true
    else
        return false
    end
end

local function find_latest_patchright()
    local home = os.getenv("HOME")
    local pattern = home .. "/.vscode-remote/extensions/nskha.perplexity-vscode-*/dist/node_modules/patchright"
    
    -- Use shell globbing to find directories
    local command = "ls -d " .. pattern .. " 2>/dev/null | sort -V | tail -1"
    local result = execute_command(command)
    
    return result and result ~= "" and result or nil
end

local extpr = find_latest_patchright()

if not extpr then
    print("[setup] extension patchright not found — is the Perplexity extension installed?")
    os.exit(0)
end

-- Get the expected chromium path
local get_exec_path_cmd = string.format('node -e "const {chromium}=require(\'%s\');console.log(chromium.executablePath())"', extpr)
local exp = execute_command(get_exec_path_cmd)

if exp and exp ~= "" and file_exists(exp) then
    print("[setup] daemon browser already present: " .. exp)
    os.exit(0)
end

print("[setup] installing matching chromium for the extension daemon (expected: " .. (exp or "unknown") .. ")...")
local install_cmd = string.format('node "%s/cli.js" install chromium', extpr)
os.execute(install_cmd)
print("[setup] done.")
