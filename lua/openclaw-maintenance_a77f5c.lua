#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "4575e05b06ae456c0aa4dd14b51ec189b65e676e1db5526afda7e16f79d15aa2", "source_sha256": "a77f5c2629fe7fafac268cfbf2f0b3e77a194322aee8f9c06967eb6c33db043e", "target_language": "lua"}
-- openclaw-maintenance.sh — portiert nach lua
-- Quelle: shell, OpenClaw@gateway2:scripts/openclaw-maintenance.sh
-- Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

local OPENCLAW_BIN = os.getenv("OPENCLAW_BIN") or (os.getenv("HOME") .. "/.local/bin/openclaw")

-- Helper function to check if file is executable
local function is_executable(path)
  local handle = io.popen("test -x '" .. path .. "' && echo 'exists'")
  local result = handle:read("*a")
  handle:close()
  return result:match("exists") ~= nil
end

-- Check if OpenClaw binary exists and is executable
if not is_executable(OPENCLAW_BIN) then
  io.stderr:write("ERROR: OpenClaw binary not found: " .. OPENCLAW_BIN .. "\n")
  os.exit(1)
end

-- Print version
local version_handle = io.popen("'" .. OPENCLAW_BIN .. "' --version")
local version_output = version_handle:read("*a"):gsub("%s+$", "")
version_handle:close()
print("Using OpenClaw: " .. version_output)

-- === 1. Service-/Config-Drift ===
os.execute("'" .. OPENCLAW_BIN .. "' doctor")

-- === 2. Plugin-Stage (Registry refresh only; updates are explicit/manual) ===
os.execute("'" .. OPENCLAW_BIN .. "' plugins registry --refresh")

local run_plugin_update = os.getenv("RUN_PLUGIN_UPDATE") or "0"
if run_plugin_update == "1" then
  os.execute("'" .. OPENCLAW_BIN .. "' plugins update --all")
else
  print("Skipping plugin update. Run with RUN_PLUGIN_UPDATE=1 to enable.")
end

-- === 3. Tasks ===
os.execute("'" .. OPENCLAW_BIN .. "' tasks maintenance --apply")

-- === 4. Sessions – alle Agents auf einmal ===
os.execute("'" .. OPENCLAW_BIN .. "' sessions cleanup --enforce --all-agents")

-- === 5. Memory – status/index decken alle Agents ab ===
os.execute("'" .. OPENCLAW_BIN .. "' memory status --deep --fix")
os.execute("'" .. OPENCLAW_BIN .. "' memory index --force")

-- === 6. Memory promote – MUSS pro Agent ===
local agents = {"main", "knecht", "docs", "ops-hub", "cron"}
for _, agent in ipairs(agents) do
  os.execute("'" .. OPENCLAW_BIN .. "' memory promote --apply --agent '" .. agent .. "'")
end

-- === 7. Secrets ===
os.execute("'" .. OPENCLAW_BIN .. "' secrets reload")
