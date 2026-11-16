#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "1e72dac992c022b54e558ee1b561f3781719f3e3444c494ae7072d80f47f6a24", "source_sha256": "8537e4253cc6ca148bc7b8cee5f458bfd0843576263cad8e98ca2c46fa47f2f1", "target_language": "lua"}
-- build-stamp.mjs — portiert nach lua
-- Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/build-stamp.mjs
-- Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

local uv = require("uv")
local fs = require("fs")
local path = require("path")
local json = require("json")

local function resolveGitHead(params)
  params = params or {}
  local cwd = params.cwd or uv.cwd()
  local spawnSyncImpl = params.spawnSync or uv.spawn

  local success, result = pcall(function()
    local stdout = {}
    local stderr = {}
    local options = {
      args = {"rev-parse", "HEAD"},
      cwd = cwd,
      stdio = {"ignore", stdout, stderr}
    }
    
    local status = spawnSyncImpl("git", options)
    
    if status ~= 0 then
      return nil
    end
    
    local head = table.concat(stdout):gsub("^%s*(.-)%s*$", "%1")
    return head ~= "" and head or nil
  end)
  
  if success then
    return result
  else
    return nil
  end
end

local function writeBuildStamp(params)
  params = params or {}
  local cwd = params.cwd or uv.cwd()
  local fsImpl = params.fs or fs
  local now = params.now or function() return os.time() end
  
  local distRoot = path.join(cwd, "dist")
  local buildStampPath = path.join(distRoot, ".buildstamp")
  local head = resolveGitHead({
    cwd = cwd,
    spawnSync = params.spawnSync
  })
  
  fsImpl.mkdirSync(distRoot, { recursive = true })
  
  local buildData = {
    builtAt = now(),
    head = head
  }
  
  fsImpl.writeFileSync(buildStampPath, json.stringify(buildData) .. "\n", "utf8")
  return buildStampPath
end

-- Prüfe ob das Skript direkt ausgeführt wird
if arg and arg[0] and arg[0]:match("build%-stamp%.mjs$") then
  local success, err = pcall(function()
    writeBuildStamp()
  end)
  
  if not success then
    print(err)
    os.exit(1)
  end
end

return {
  resolveGitHead = resolveGitHead,
  writeBuildStamp = writeBuildStamp
}
