#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "494f04add2856a5aef040db5bdcc0508c9fd2403dd09dfeb6a48fb15e9145862", "source_sha256": "0f2bb155d699e769ad3eb99a6500cc6dbb27948a57f7493a3b98c731200853d4", "target_language": "lua"}
-- test-extension.mjs — portiert nach lua
-- Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/test-extension.mjs
-- Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

local error_format = require("./lib/error-format.lua")
local extension_test_plan = require("./lib/extension-test-plan.lua")
local vitest_batch_runner = require("./lib/vitest-batch-runner.lua")

local function printUsage()
  io.stderr:write("Usage: pnpm test:extension <extension-name|path> [vitest args...]\n")
  io.stderr:write("       node scripts/test-extension.mjs [extension-name|path] [vitest args...]\n")
end

local function printNoTestsMessage(plan)
  print("[test-extension] No tests found for " .. plan.extensionDir .. ". Skipping.")
end

local function run()
  local rawArgs = {}
  for i = 3, #arg do
    table.insert(rawArgs, arg[i])
  end

  if vim.fn.index(rawArgs, "--help") ~= -1 or vim.fn.index(rawArgs, "-h") ~= -1 then
    printUsage()
    return
  end

  local passthroughArgs = {}
  for _, arg in ipairs(rawArgs) do
    if arg ~= "--" then
      table.insert(passthroughArgs, arg)
    end
  end

  local targetArg
  if passthroughArgs[1] and not string.sub(passthroughArgs[1], 1, 1) == "-" then
    targetArg = table.remove(passthroughArgs, 1)
  end

  local plan
  local status, err = pcall(function()
    plan = extension_test_plan.resolveExtensionTestPlan({ cwd = vim.fn.getcwd(), targetArg = targetArg })
  end)

  if not status then
    printUsage()
    io.stderr:write(error_format.formatErrorMessage(err) .. "\n")
    os.exit(1)
  end

  if not plan.hasTests then
    printNoTestsMessage(plan)
    return
  end

  print("[test-extension] Running " .. plan.testFileCount .. " test files for " .. plan.extensionId)
  
  local exitCode = vitest_batch_runner.runVitestBatch({
    args = passthroughArgs,
    config = plan.config,
    env = vim.fn.environ(),
    targets = plan.roots,
  })
  
  os.exit(exitCode)
end

if vim.fn.expand("%:p") == arg[0] then
  run()
end
