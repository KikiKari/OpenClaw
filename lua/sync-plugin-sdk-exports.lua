#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "2d814c4747c573e09729bea35cbedf050105d695a3476de626d3809f58f9ae84", "source_sha256": "44c9196ec2dbaf8ef45323397e44f66d128313ddae44f9dfc8bba7439fe6e844", "target_language": "lua"}
-- sync-plugin-sdk-exports.mjs — portiert nach lua
-- Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/sync-plugin-sdk-exports.mjs
-- Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

local fs = require("fs")
local path = require("path")
local buildPluginSdkPackageExports = require("./lib/plugin-sdk-entries.lua")

local checkOnly = false
for _, arg in ipairs(arg) do
  if arg == "--check" then
    checkOnly = true
    break
  end
end

local packageJsonPath = path.join(os.getenv("PWD"), "package.json")
local packageJsonContent = fs.readFileSync(packageJsonPath, "utf8")
local packageJson = JSON.parse(packageJsonContent)
local currentExports = packageJson.exports or {}
local syncedPluginSdkExports = buildPluginSdkPackageExports()

local nextExports = {}
local insertedPluginSdkExports = false
for key, value in pairs(currentExports) do
  if string.sub(key, 1, 12) == "./plugin-sdk" then
    if not insertedPluginSdkExports then
      for k, v in pairs(syncedPluginSdkExports) do
        nextExports[k] = v
      end
      insertedPluginSdkExports = true
    end
  else
    nextExports[key] = value
    if key == "." and not insertedPluginSdkExports then
      for k, v in pairs(syncedPluginSdkExports) do
        nextExports[k] = v
      end
      insertedPluginSdkExports = true
    end
  end
end

if not insertedPluginSdkExports then
  for k, v in pairs(syncedPluginSdkExports) do
    nextExports[k] = v
  end
end

local nextExportsJson = JSON.stringify(nextExports)
local currentExportsJson = JSON.stringify(currentExports)
if checkOnly then
  if currentExportsJson ~= nextExportsJson then
    print("plugin-sdk exports out of sync. Run `pnpm plugin-sdk:sync-exports`.")
    os.exit(1)
  end
  print("plugin-sdk exports synced.")
  os.exit(0)
end

packageJson.exports = nextExports
fs.writeFileSync(packageJsonPath, JSON.stringify(packageJson, nil, 2) .. "\n", "utf8")
