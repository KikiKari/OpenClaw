#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "435ca9a94bdfb04129a2e3964b221050f93c9f436eba5f67b736544b186cd9c6", "source_sha256": "2516612af0a0435eb92af19fa6d322dbf03b3c95168e1f623ea14087f9e79413", "target_language": "lua"}
-- run-vitest.mjs — portiert nach lua
-- Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/run-vitest.mjs
-- Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

local uv = require("uv")
local fs = require("fs")
local path = require("path")
local os = require("os")

local pnpm_runner = require("./pnpm-runner.lua")
local vitest_process_group = require("./vitest-process-group.lua")

local TRUTHY_ENV_VALUES = {
  ["1"] = true,
  ["true"] = true,
  ["yes"] = true,
  ["on"] = true
}

local SUPPRESSED_VITEST_STDERR_PATTERNS = {
  "[PLUGIN_TIMINGS] Warning:"
}

local function isTruthyEnvValue(value)
  if not value then return false end
  return TRUTHY_ENV_VALUES[string.lower(string.gsub(value, "%s+", ""))] or false
end

local function resolveVitestNodeArgs(env)
  env = env or os.getenv()
  if isTruthyEnvValue(env.OPENCLAW_VITEST_ENABLE_MAGLEV) then
    return {}
  end
  return {"--no-maglev"}
end

local function resolveVitestCliEntry()
  -- In Lua, we need to find the vitest installation differently
  -- This is a simplified approach - you might need to adjust based on your setup
  local vitestPath = "./node_modules/vitest/vitest.mjs"
  if fs.existsSync(vitestPath) then
    return vitestPath
  end
  error("Could not find vitest CLI entry point")
end

local function resolveVitestSpawnParams(env, platform)
  env = env or os.getenv()
  platform = platform or os.platform()
  return {
    env = env,
    detached = vitest_process_group.shouldUseDetachedVitestProcessGroup(platform),
    stdio = {"inherit", "pipe", "pipe"}
  }
end

local function shouldSuppressVitestStderrLine(line)
  for _, pattern in ipairs(SUPPRESSED_VITEST_STDERR_PATTERNS) do
    if string.find(line, pattern, 1, true) then
      return true
    end
  end
  return false
end

local function forwardVitestOutput(stream, target, shouldSuppressLine)
  if not stream then
    return
  end

  shouldSuppressLine = shouldSuppressLine or function() return false end

  local buffered = ""
  stream:read_start(function(err, chunk)
    if err then
      print("Stream error:", err)
      return
    end
    
    if not chunk then
      -- Stream ended
      if #buffered > 0 and not shouldSuppressLine(buffered) then
        target:write(buffered)
      end
      return
    end

    buffered = buffered .. chunk
    while true do
      local newlineIndex = string.find(buffered, "\n")
      if not newlineIndex then
        break
      end
      
      local line = string.sub(buffered, 1, newlineIndex)
      buffered = string.sub(buffered, newlineIndex + 1)
      
      if not shouldSuppressLine(line) then
        target:write(line)
      end
    end
  end)
end

local function main(argv, env)
  argv = argv or arg
  env = env or os.getenv()
  
  if #argv == 0 then
    io.stderr:write("usage: lua scripts/run-vitest.lua <vitest args...>\n")
    os.exit(1)
  end

  local spawnParams = resolveVitestSpawnParams(env)
  local vitestNodeArgs = resolveVitestNodeArgs(env)
  local vitestCliEntry = resolveVitestCliEntry()
  
  -- Build pnpmArgs array
  local pnpmArgs = {"exec", "node"}
  for _, arg in ipairs(vitestNodeArgs) do
    table.insert(pnpmArgs, arg)
  end
  table.insert(pnpmArgs, vitestCliEntry)
  for _, arg in ipairs(argv) do
    table.insert(pnpmArgs, arg)
  end

  local child = pnpm_runner.spawnPnpmRunner({
    pnpmArgs = pnpmArgs,
    env = spawnParams.env,
    detached = spawnParams.detached,
    stdio = spawnParams.stdio
  })
  
  local teardownChildCleanup = vitest_process_group.installVitestProcessGroupCleanup({child = child})
  
  forwardVitestOutput(child.stdout, process.stdout)
  forwardVitestOutput(child.stderr, process.stderr, shouldSuppressVitestStderrLine)

  child:on("exit", function(code, signal)
    teardownChildCleanup()
    if signal then
      -- In Lua, process signaling works differently
      -- You might need to implement this based on your environment
      os.exit(128 + signal)
    end
    os.exit(code or 1)
  end)

  child:on("error", function(error)
    teardownChildCleanup()
    io.stderr:write(tostring(error) .. "\n")
    os.exit(1)
  end)
end

-- Check if this script is being run directly
if arg and arg[0] and string.find(arg[0], "run-vitest.lua") then
  main()
end
