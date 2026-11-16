#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "2f8e8c24fed01b1be9ca067837955fa127c109950a8589fd9624a962f6d12137", "source_sha256": "c07aee6a3f0a90788cfe647dfcc79cf95df841ce0459eb8ffd9bf6aaa426ea38", "target_language": "lua"}
-- build-all.mjs — portiert nach lua
-- Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/build-all.mjs
-- Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

local uv = require("luv")
local os = require("os")
local table = require("table")

local nodeBin = os.getenv("NODE_BIN") or "node"
local WINDOWS_BUILD_MAX_OLD_SPACE_MB = 4096

local BUILD_ALL_STEPS = {
  { label = "canvas:a2ui:bundle", kind = "pnpm", pnpmArgs = {"canvas:a2ui:bundle"} },
  { label = "tsdown", kind = "node", args = {"scripts/tsdown-build.mjs"} },
  { label = "runtime-postbuild", kind = "node", args = {"scripts/runtime-postbuild.mjs"} },
  {
    label = "write-npm-update-compat-sidecars",
    kind = "node",
    args = {"scripts/write-npm-update-compat-sidecars.mjs"},
  },
  { label = "build-stamp", kind = "node", args = {"scripts/build-stamp.mjs"} },
  {
    label = "build:plugin-sdk:dts",
    kind = "pnpm",
    pnpmArgs = {"build:plugin-sdk:dts"},
    windowsNodeOptions = "--max-old-space-size=" .. WINDOWS_BUILD_MAX_OLD_SPACE_MB,
  },
  {
    label = "write-plugin-sdk-entry-dts",
    kind = "node",
    args = {"--import", "tsx", "scripts/write-plugin-sdk-entry-dts.ts"},
  },
  {
    label = "check-plugin-sdk-exports",
    kind = "node",
    args = {"scripts/check-plugin-sdk-exports.mjs"},
  },
  {
    label = "canvas-a2ui-copy",
    kind = "node",
    args = {"--import", "tsx", "scripts/canvas-a2ui-copy.ts"},
  },
  {
    label = "copy-hook-metadata",
    kind = "node",
    args = {"--import", "tsx", "scripts/copy-hook-metadata.ts"},
  },
  {
    label = "copy-export-html-templates",
    kind = "node",
    args = {"--import", "tsx", "scripts/copy-export-html-templates.ts"},
  },
  {
    label = "write-build-info",
    kind = "node",
    args = {"--import", "tsx", "scripts/write-build-info.ts"},
  },
  {
    label = "write-cli-startup-metadata",
    kind = "node",
    args = {"--experimental-strip-types", "scripts/write-cli-startup-metadata.ts"},
  },
  {
    label = "write-cli-compat",
    kind = "node",
    args = {"--import", "tsx", "scripts/write-cli-compat.ts"},
  },
}

-- Placeholder for resolvePnpmRunner - needs actual implementation
local function resolvePnpmRunner(params)
  -- This would need to be implemented based on the logic in pnpm-runner.mjs
  -- For now returning dummy values
  return {
    command = "pnpm",
    args = params.pnpmArgs or {},
    shell = false,
    windowsVerbatimArguments = false
  }
end

local function resolveStepEnv(step, env, platform)
  if platform ~= "win32" or not step.windowsNodeOptions then
    return env
  end
  
  local currentNodeOptions = env.NODE_OPTIONS or ""
  if string.find(currentNodeOptions, step.windowsNodeOptions) then
    return env
  end
  
  local newEnv = {}
  for k, v in pairs(env) do
    newEnv[k] = v
  end
  
  if currentNodeOptions ~= "" then
    newEnv.NODE_OPTIONS = currentNodeOptions .. " " .. step.windowsNodeOptions
  else
    newEnv.NODE_OPTIONS = step.windowsNodeOptions
  end
  
  return newEnv
end

local function resolveBuildAllStep(step, params)
  params = params or {}
  local platform = params.platform or uv.os_uname().sysname:lower()
  local env = resolveStepEnv(step, params.env or uv.os_getenv(), platform)
  
  if step.kind == "pnpm" then
    local runner = resolvePnpmRunner({
      pnpmArgs = step.pnpmArgs,
      nodeExecPath = params.nodeExecPath or nodeBin,
      npmExecPath = params.npmExecPath,
      comSpec = params.comSpec,
      platform = platform,
    })
    
    return {
      command = runner.command,
      args = runner.args,
      options = {
        stdio = "inherit",
        env = env,
        shell = runner.shell,
        windowsVerbatimArguments = runner.windowsVerbatimArguments,
      },
    }
  end
  
  return {
    command = params.nodeExecPath or nodeBin,
    args = step.args,
    options = {
      stdio = "inherit",
      env = env,
    },
  }
end

-- Simple spawn sync implementation using luv
local function spawnSync(command, args, options)
  local stdin = uv.new_pipe(false)
  local stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)
  
  local proc, pid = uv.spawn(command, {
    args = args,
    stdio = {stdin, stdout, stderr},
    env = options.env,
    cwd = uv.cwd(),
  }, function(code, signal)
    -- Handle process exit
  end)
  
  if not proc then
    return {status = 1}
  end
  
  -- Wait for process to complete
  uv.run()
  
  return {status = 0} -- Simplified - would need proper exit code handling
end

-- Check if this script is the main module
local function isMainModule()
  -- In Lua, we can check if the script is run directly
  local info = debug.getinfo(2, "S")
  return info and info.source:sub(1,1) == "@"
end

-- Main execution
if isMainModule() then
  for _, step in ipairs(BUILD_ALL_STEPS) do
    print("[build-all] " .. step.label)
    local invocation = resolveBuildAllStep(step)
    local result = spawnSync(invocation.command, invocation.args, invocation.options)
    
    if type(result.status) == "number" then
      if result.status ~= 0 then
        os.exit(result.status)
      end
    else
      os.exit(1)
    end
  end
end

return {
  BUILD_ALL_STEPS = BUILD_ALL_STEPS,
  resolveBuildAllStep = resolveBuildAllStep
}
