#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "1d4e396290f2ab176ac55cfcd5e4bf7343d31cad2d0ba8f48fe996ae22b5194f", "source_sha256": "5826d57477404d40d10bccd3a144f22f3f46ce4897073fa71d1d3868edfe8719", "target_language": "lua"}
-- format-generated-module.mjs — portiert nach lua
-- Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/format-generated-module.mjs
-- Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

local fs = require("fs")
local path = require("path")
local os = require("os")
local child_process = require("child_process")

function formatGeneratedModule(source, options)
  local repoRoot = options.repoRoot
  local outputPath = options.outputPath
  local errorLabel = options.errorLabel

  local resolvedRepoRoot = path.resolve(repoRoot)
  local resolvedOutputPath = path.resolve(
    resolvedRepoRoot,
    (path.isAbsolute(outputPath) and path.relative(resolvedRepoRoot, outputPath)) or outputPath
  )
  
  local directFormatterPath = path.join(resolvedRepoRoot, "node_modules", ".bin", "oxfmt")
  local useDirectFormatter = (package.config:sub(1,1) ~= "\\" and fs.existsSync(directFormatterPath))
  local command = useDirectFormatter and directFormatterPath or "pnpm"
  
  local tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "openclaw-generated-format-"))
  local tempOutputPath = path.join(tempDir, path.basename(resolvedOutputPath))

  local success, result = pcall(function()
    fs.writeFileSync(tempOutputPath, source, "utf8")
    local args = useDirectFormatter 
      and {"--write", tempOutputPath}
      or {"exec", "oxfmt", "--write", tempOutputPath}
    
    local opts = {
      cwd = resolvedRepoRoot,
      encoding = "utf8"
    }
    
    -- Windows requires a shell to launch package-manager shim scripts reliably.
    if package.config:sub(1,1) == "\\" then
      opts.shell = true
    end
    
    local formatter = child_process.spawnSync(command, args, opts)
    
    if formatter.status ~= 0 then
      local details = 
        (formatter.stderr and formatter.stderr:match("^%s*(.-)%s*$")) or
        (formatter.stdout and formatter.stdout:match("^%s*(.-)%s*$")) or
        (formatter.error and formatter.error.message) or
        "unknown formatter failure"
      error(string.format("failed to format generated %s: %s", errorLabel, details))
    end
    
    return fs.readFileSync(tempOutputPath, "utf8")
  end)

  -- Cleanup temp directory
  fs.rmSync(tempDir, { recursive = true, force = true })

  if not success then
    error(result)
  end
  
  return result
end

return {
  formatGeneratedModule = formatGeneratedModule
}
