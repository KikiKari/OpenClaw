#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "f647d9440a8a9c2ce90689d3ba558c1fda541e173fb4634354fe452b7235e50f", "source_sha256": "b6d33ba222e838d8ea4e8f134b161c60019978c5abaa86299906dfe095635a2b", "target_language": "lua"}
-- callsite-guard.mjs — portiert nach lua
-- Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/callsite-guard.mjs
-- Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

local fs = require("fs")
local path = require("path")
local ts_guard_utils = require("./ts-guard-utils")

local function runCallsiteGuard(params)
  local repoRoot = ts_guard_utils.resolveRepoRoot(params.importMetaUrl)
  local sourceRoots = ts_guard_utils.resolveSourceRoots(repoRoot, params.sourceRoots)
  local files = ts_guard_utils.collectTypeScriptFilesFromRoots(sourceRoots, {
    extraTestSuffixes = params.extraTestSuffixes,
  })
  local violations = {}

  for _, filePath in ipairs(files) do
    local relPath = path.relative(repoRoot, filePath):gsub(path.sep, "/")
    if params.skipRelativePath and params.skipRelativePath(relPath) then
      goto continue
    end
    local content = fs.readFileSync(filePath, "utf8")
    for _, line in ipairs(params.findCallLines(content, filePath)) do
      local callsite = relPath .. ":" .. line
      if params.allowCallsite and params.allowCallsite(callsite) then
        goto continue
      end
      table.insert(violations, callsite)
    end
    ::continue::
  end

  if #violations == 0 then
    return
  end

  print(params.header)
  local output = violations
  if params.sortViolations ~= false then
    table.sort(output)
  end
  for _, violation in ipairs(output) do
    print("- " .. violation)
  end
  if params.footer then
    print(params.footer)
  end
  os.exit(1)
end

return {
  runCallsiteGuard = runCallsiteGuard
}
