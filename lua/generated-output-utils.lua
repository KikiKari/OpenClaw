#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "fa6f853c5600d081a5c99fe05d5ef95d1fb2c0f0f8638b07adc4ef80f654f65c", "source_sha256": "3c225928c07272d97d9f90c9c2134a117467308ab5be4a60ac9e89701f38b3e9", "target_language": "lua"}
-- generated-output-utils.mjs — portiert nach lua
-- Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/generated-output-utils.mjs
-- Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

local path = require("path")
local fs = require("fs")
local process = require("process")

local function writeTextFileIfChanged(filepath, content)
  local current = ""
  local file = io.open(filepath, "r")
  if file then
    current = file:read("*a")
    file:close()
  end

  if current == content then
    return false
  end

  file = io.open(filepath, "w")
  if file then
    file:write(content)
    file:close()
    return true
  else
    error("Failed to write file: " .. filepath)
  end
end

local function readIfExists(filepath)
  local file = io.open(filepath, "r")
  if file then
    local content = file:read("*a")
    file:close()
    return content
  end
  return nil
end

local function writeGeneratedOutput(params)
  local outputPath = path.resolve(params.repoRoot, params.outputPath)
  local current = readIfExists(outputPath)
  local changed = current ~= params.next

  if params.check then
    return {
      changed = changed,
      wrote = false,
      outputPath = outputPath,
    }
  end

  return {
    changed = changed,
    wrote = writeTextFileIfChanged(outputPath, params.next),
    outputPath = outputPath,
  }
end

local function reportGeneratedOutputCli(params)
  -- Lua doesn't have import.meta.url, so we simulate by checking arg[0]
  local scriptPath = arg[0] and fs.realpathSync(arg[0]) or ""
  if params.importMetaUrl ~= "file://" .. scriptPath then
    return
  end

  local check = false
  for _, v in ipairs(arg) do
    if v == "--check" then
      check = true
      break
    end
  end

  local result = params.run({ check = check })
  if not result.changed then
    return
  end

  local relativeOutputPath = path.relative(process.cwd(), result.outputPath)
  if check then
    io.stderr:write("[" .. params.label .. "] stale generated output at " .. relativeOutputPath .. "\n")
    os.exit(1)
    return
  end

  print("[" .. params.label .. "] wrote " .. relativeOutputPath)
end

return {
  writeGeneratedOutput = writeGeneratedOutput,
  reportGeneratedOutputCli = reportGeneratedOutputCli
}
