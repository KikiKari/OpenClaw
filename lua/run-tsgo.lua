#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "e962387056ca43a100f0db534bfad1cc80ae1cd95b258e3ee9d27c4c8dce5950", "source_sha256": "5425378c778f4ef6ac0e8404ecffe774c2d3aea6bad539b4fd772554e566f469", "target_language": "lua"}
-- run-tsgo.mjs — portiert nach lua
-- Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/run-tsgo.mjs
-- Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

local fs = require("lfs")
local path = require("path")
local process = require("process")
local child_process = require("child_process")

-- Lade das lokale Modul (ersetzt die Imports)
local local_heavy_check_runtime = dofile("./lib/local-heavy-check-runtime.lua")
local acquireLocalHeavyCheckLockSync = local_heavy_check_runtime.acquireLocalHeavyCheckLockSync
local applyLocalTsgoPolicy = local_heavy_check_runtime.applyLocalTsgoPolicy

-- Funktion zum Lesen von Flag-Werten (äquivalent zu readFlagValue)
local function readFlagValue(args, name)
  for index = 1, #args do
    local arg = args[index]
    if arg == name then
      return args[index + 1]
    end
    if string.sub(arg, 1, #name + 1) == name .. "=" then
      return string.sub(arg, #name + 2)
    end
  end
  return nil
end

-- Wende die lokale TSGO-Policy an (ersetzt die Argumente und Umgebungsvariablen)
local policyResult = applyLocalTsgoPolicy({unpack(process.argv, 3)}, process.env)
local finalArgs = policyResult.args
local env = policyResult.env

-- Bestimme den Pfad zur tsgo-Binärdatei
local tsgoPath = path.resolve("node_modules", ".bin", "tsgo")

-- Lese den Wert für --tsBuildInfoFile
local tsBuildInfoFile = readFlagValue(finalArgs, "--tsBuildInfoFile")

-- Erstelle das Verzeichnis für die tsBuildInfoFile, falls notwendig
if tsBuildInfoFile then
  local dir = path.dirname(path.resolve(tsBuildInfoFile))
  local ok, err = fs.mkdir(dir, {recursive = true})
  if not ok then
    error("Fehler beim Erstellen des Verzeichnisses: " .. err)
  end
end

-- Erwerbe den Lock für die schwere Prüfung
local releaseLock = acquireLocalHeavyCheckLockSync({
  cwd = process.cwd(),
  env = env,
  toolName = "tsgo"
})

-- Führe tsgo aus
local success, result = pcall(function()
  local spawnResult = child_process.spawnSync(tsgoPath, finalArgs, {
    stdio = "inherit",
    env = env,
    shell = process.platform == "win32"
  })

  if spawnResult.error then
    error(spawnResult.error)
  end

  process.exitCode = spawnResult.status or 1
end)

-- Gebe den Lock immer frei
releaseLock()

-- Falls ein Fehler aufgetreten ist, wirf ihn erneut
if not success then
  error(result)
end
