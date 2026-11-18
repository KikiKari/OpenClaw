#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "ab615dfe03c7b82a4877919ca04cec968a3c88d0fd090f2f1991c8268edfd003", "source_sha256": "5fc2c92995e4c87536b6317eba7c9959c9babc16a20ce4476804921089ee2e34", "target_language": "lua"}
-- copy-plugin-sdk-root-alias.mjs — portiert nach lua
-- Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/copy-plugin-sdk-root-alias.mjs
-- Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

local fs = require("fs")
local path = require("path")
local runtime_postbuild_shared = require("./runtime-postbuild-shared.lua")

function copyPluginSdkRootAlias(params)
  params = params or {}
  local cwd = params.cwd or fs.cwd()
  local source = path.resolve(cwd, "src/plugin-sdk/root-alias.cjs")
  local target = path.resolve(cwd, "dist/plugin-sdk/root-alias.cjs")

  runtime_postbuild_shared.writeTextFileIfChanged(target, fs.readFileSync(source, "utf8"))
end

if arg and arg[0] == ... then
  copyPluginSdkRootAlias()
end

return {
  copyPluginSdkRootAlias = copyPluginSdkRootAlias
}
