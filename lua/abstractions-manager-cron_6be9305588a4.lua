#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "b826fc98b2980a340780d4b3545562c668316fffdd13818c4813694e3403b957", "source_sha256": "1b01ca0f5943b16d3905faf557953600ee54f15ecf1dc18c1461585eba94d376", "target_language": "lua"}
-- abstractions-manager-cron.sh — portiert nach lua
-- Quelle: shell, OpenClaw@gateway1:scripts/abstractions-manager-cron.sh
-- Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

-- Set error handling to strict mode
package.path = "/home/openclaw/.local/bin/?.lua;" .. package.path

-- Set environment variables
os.execute("export PATH='/home/openclaw/.local/bin:/usr/local/bin:/usr/bin:/bin'")

-- Load environment file
local env_file = io.open("/home/openclaw/.openclaw/.env", "r")
if not env_file then
    error(".env file could not be opened")
end

for line in env_file:lines() do
    if not line:match("^%s*#") and line:find("=") then
        local key, value = line:match("^([^=]+)=(.*)$")
        if key and value then
            os.setenv(key, value)
        end
    end
end
env_file:close()

-- Check required environment variable
if not os.getenv("OPENROUTER_API_KEY") then
    error("OPENROUTER_API_KEY missing")
end

-- Set GITHUB_TOKEN with fallback values
local github_token = os.getenv("GITHUB_TOKEN") or os.getenv("GH_TOKEN") or os.getenv("GH_ACCESS_TOKEN")
if github_token then
    os.setenv("GITHUB_TOKEN", github_token)
end

-- Execute the locked command
local lockfile = "/home/openclaw/.openclaw/locks/abstractions-manager.lock"
local script = "/home/openclaw/.openclaw/workspace/skills/script-abstractions-manager/scripts/ABSTRACTIONS_MANAGER.py"

-- Use a simple file locking mechanism since flock is not available in Lua standard library
local function try_lock(file)
    local f = io.open(file, "w")
    if f then
        f:write(tostring(os.time()))
        f:close()
        return true
    end
    return false
end

-- Try to acquire lock
if try_lock(lockfile .. ".tmp") then
    -- Move temp lock file to actual lock file atomically
    os.rename(lockfile .. ".tmp", lockfile)
    
    -- Execute Python script with arguments
    local args = {...}
    local cmd = "python3 " .. script
    for _, arg in ipairs(args) do
        cmd = cmd .. " " .. arg
    end
    
    local success, exit_code, exit_reason = os.execute(cmd)
    
    -- Remove lock file after execution
    os.remove(lockfile)
    
    -- Exit with the same code as the executed command
    if success then
        os.exit(0)
    else
        os.exit(exit_code or 1)
    end
else
    -- Could not acquire lock, exit with error
    os.exit(1)
end
