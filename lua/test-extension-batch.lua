#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "1e8ca7b22ed881c62b50773713f89d7f2ca0bcdfe0ff214738cf81a3efa73bdc", "source_sha256": "fe4ef822110d5a3d05561b87f0634182183de94f1130dc41ba19fd74bdff1653", "target_language": "lua"}
-- test-extension-batch.mjs — portiert nach lua
-- Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/test-extension-batch.mjs
-- Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

local path = require("path")
local fs = require("fs")
local child_process = require("child_process")

-- Simuliere import aus anderen Modulen
local extension_test_plan = dofile(path.resolve(".", "lib", "extension-test-plan.lua"))
local vitest_batch_runner = dofile(path.resolve(".", "lib", "vitest-batch-runner.lua"))

local resolveExtensionBatchPlan = extension_test_plan.resolveExtensionBatchPlan
local isDirectScriptRun = vitest_batch_runner.isDirectScriptRun
local runVitestBatch = vitest_batch_runner.runVitestBatch

function printUsage()
  io.stderr:write("Usage: pnpm test:extensions:batch <extension[,extension...]> [vitest args...]\n")
  io.stderr:write("       node scripts/test-extension-batch.mjs <extension[,extension...]> [vitest args...]\n")
end

function parseExtensionIds(rawArgs)
  local args = {}
  for i, v in ipairs(rawArgs) do
    args[i] = v
  end
  local extensionIds = {}

  while args[1] and not string.sub(args[1], 1, 1) == "-" do
    local firstArg = table.remove(args, 1)
    for part in string.gmatch(firstArg, "[^,]+") do
      local trimmed = string.match(part, "^%s*(.-)%s*$")
      if trimmed ~= "" then
        table.insert(extensionIds, trimmed)
      end
    end
  end

  return { extensionIds = extensionIds, passthroughArgs = args }
end

function arrayContains(array, value)
  for _, v in ipairs(array) do
    if v == value then
      return true
    end
  end
  return false
end

function filterArray(array, predicate)
  local result = {}
  for _, v in ipairs(array) do
    if predicate(v) then
      table.insert(result, v)
    end
  end
  return result
end

function run()
  local rawArgs = {}
  for i = 1, #arg do
    rawArgs[i] = arg[i]
  end

  if arrayContains(rawArgs, "--help") or arrayContains(rawArgs, "-h") then
    printUsage()
    os.exit(0)
  end

  local passthroughArgs = filterArray(rawArgs, function(argValue)
    return argValue ~= "--"
  end)

  local parsed = parseExtensionIds(passthroughArgs)
  local extensionIds = parsed.extensionIds
  local vitestArgs = parsed.passthroughArgs

  if #extensionIds == 0 then
    printUsage()
    os.exit(1)
  end

  local batchPlan = resolveExtensionBatchPlan({ cwd = ".", extensionIds = extensionIds })
  if not batchPlan.hasTests then
    print("[test-extension-batch] No tests found for the requested extensions. Skipping.")
    return
  end

  print(string.format(
    "[test-extension-batch] Running %d test files across %d extensions",
    batchPlan.testFileCount,
    batchPlan.extensionCount
  ))

  for _, group in ipairs(batchPlan.planGroups) do
    print(string.format(
      "[test-extension-batch] %s: %s (%d files)",
      group.config,
      table.concat(group.extensionIds, ", "),
      group.testFileCount
    ))
    
    local exitCode = runVitestBatch({
      args = vitestArgs,
      config = group.config,
      env = os.getenv,
      targets = group.roots,
    })
    
    if exitCode ~= 0 then
      os.exit(exitCode)
    end
  end
end

if isDirectScriptRun(debug.getinfo(1).source) then
  run()
end
