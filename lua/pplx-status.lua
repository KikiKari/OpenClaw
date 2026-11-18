#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "71ff2cf7a038a798f900f60bad5a9a98d447a75a4cdcf6fadfb897323f04646a", "source_sha256": "0d861748edb257fc44db6425a576fa977cd0d18c0ffb8eefa390f0b87a3116c8", "target_language": "lua"}
-- pplx-status.sh — portiert nach lua
-- Quelle: shell, OpenClaw@main:scripts/pplx-tools/pplx-status.sh
-- Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

-- Quick status of the codespace Perplexity daemon session.
local CFG = os.getenv("PERPLEXITY_CONFIG_DIR") or (os.getenv("HOME") .. "/.perplexity-mcp")
local PROFILE = os.getenv("PERPLEXITY_PROFILE") or "codespace"
local STAT = CFG .. "/profiles/" .. PROFILE .. "/daemon-status.json"

local function file_exists(name)
  local f = io.open(name, "r")
  if f ~= nil then
    io.close(f)
    return true
  else
    return false
  end
end

if file_exists(STAT) then
  local handle = io.popen("cat " .. STAT .. " | jq '.' 2>/dev/null || cat " .. STAT)
  local result = handle:read("*a")
  handle:close()
  print(result)
else
  print("no daemon-status.json at " .. STAT)
end

print("--- recent auth lines ---")
local handle = io.popen("grep -iE 'Authenticated as user|Account tier|Injected .* cookies|Reinit requested|not-logged-in' " .. CFG .. "/daemon.log 2>/dev/null | tail -6")
local result = handle:read("*a")
handle:close()
print(result)
