#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "a86ba83a1f283b85bf823fd48e63cc45a9a5964945ff21fc3e17f495a2a5c751", "source_sha256": "04f0268dc494793e85c15189558b4768a3e49a147b113ecc0fe3456b05d0eb20", "target_language": "lua"}
-- check-cli-startup-memory.mjs — portiert nach lua
-- Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-cli-startup-memory.mjs
-- Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

local uv = require("uv")
local fs = require("fs")
local path = require("path")
local os = require("os")
local child_process = require("child_process")

local isLinux = uv.os_uname().sysname == "Linux"
local isMac = uv.os_uname().sysname == "Darwin"

if not isLinux and not isMac then
  print("[startup-memory] Skipping on unsupported platform: " .. uv.os_uname().sysname)
  os.exit(0)
end

local repoRoot = uv.cwd()
local tmpHome = fs.mkdtempSync(path.join(uv.os_tmpdir(), "openclaw-startup-memory-"))
local tmpDir = os.getenv("TMPDIR") or os.getenv("TEMP") or os.getenv("TMP") or uv.os_tmpdir()
local rssHookPath = path.join(tmpHome, "measure-rss.lua")
local MAX_RSS_MARKER = "__OPENCLAW_MAX_RSS_KB__="

fs.writeFileSync(
  rssHookPath,
  table.concat({
    "process.on('exit', function()",
    "  local usage = type(process.resourceUsage) == 'function' and process.resourceUsage() or nil",
    "  if usage and type(usage.maxRSS) == 'number' then",
    "    io.stderr:write('" .. MAX_RSS_MARKER .. "' .. tostring(usage.maxRSS))",
    "  end",
    "end)",
    ""
  }, "\n"),
  "utf8"
)

local DEFAULT_LIMITS_MB = {
  help = 100,
  statusJson = 400,
  gatewayStatus = 500,
}

local cases = {
  {
    id = "help",
    label = "--help",
    args = {"openclaw.lua", "--help"},
    limitMb = tonumber(os.getenv("OPENCLAW_STARTUP_MEMORY_HELP_MB") or DEFAULT_LIMITS_MB.help),
  },
  {
    id = "statusJson",
    label = "status --json",
    args = {"openclaw.lua", "status", "--json"},
    limitMb = tonumber(os.getenv("OPENCLAW_STARTUP_MEMORY_STATUS_JSON_MB") or DEFAULT_LIMITS_MB.statusJson),
  },
  {
    id = "gatewayStatus",
    label = "gateway status",
    args = {"openclaw.lua", "gateway", "status"},
    limitMb = tonumber(os.getenv("OPENCLAW_STARTUP_MEMORY_GATEWAY_STATUS_MB") or DEFAULT_LIMITS_MB.gatewayStatus),
  },
}

local function formatFixGuidance(testCase, details)
  local command = "node " .. table.concat(testCase.args, " ")
  local guidance = {
    "[startup-memory] Fix guidance",
    "Case: " .. testCase.label,
    "Command: " .. command,
    "Next steps:",
    "1. Run `" .. command .. "` locally on the built tree.",
    "2. If this is an RSS overage, compare the startup import graph against the last passing commit and look for newly eager imports, bootstrap side effects, or plugin loading on the command path.",
    "3. If this is a non-zero exit, inspect the first transitive import/config error in stderr and fix that root cause before re-checking memory.",
    "LLM prompt:",
    "\"OpenClaw startup-memory CI failed for '" .. testCase.label .. "'. Analyze this failure, identify the first runtime/import side effect that makes startup heavier or broken, and propose the smallest safe patch. Failure output:\\n" .. details .. "\"",
  }
  return table.concat(guidance, "\n") .. "\n"
end

local function formatFailure(testCase, message, details)
  local trimmedDetails = string.gsub(details or "", "^%s*(.-)%s*$", "%1")
  local sections = {message}
  if trimmedDetails ~= "" then
    table.insert(sections, trimmedDetails)
  end
  table.insert(sections, formatFixGuidance(testCase, trimmedDetails ~= "" and trimmedDetails or message))
  return table.concat(sections, "\n\n")
end

local function parseMaxRssMb(stderr)
  local pattern = "^" .. MAX_RSS_MARKER .. "(%d+)%s*$"
  local matches = {}
  for line in string.gmatch(stderr, "[^\r\n]+") do
    local match = string.match(line, pattern)
    if match then
      table.insert(matches, match)
    end
  end
  if #matches == 0 then
    return nil
  end
  return tonumber(matches[#matches]) / 1024
end

local function buildBenchEnv()
  local env = {
    HOME = tmpHome,
    USERPROFILE = tmpHome,
    XDG_CONFIG_HOME = path.join(tmpHome, ".config"),
    XDG_DATA_HOME = path.join(tmpHome, ".local", "share"),
    XDG_CACHE_HOME = path.join(tmpHome, ".cache"),
    PATH = os.getenv("PATH") or "",
    TMPDIR = tmpDir,
    TEMP = tmpDir,
    TMP = tmpDir,
    LANG = os.getenv("LANG") or "C.UTF-8",
    TERM = os.getenv("TERM") or "dumb",
  }

  if os.getenv("LC_ALL") then
    env.LC_ALL = os.getenv("LC_ALL")
  end
  if os.getenv("CI") then
    env.CI = os.getenv("CI")
  end
  if os.getenv("NODE_DISABLE_COMPILE_CACHE") then
    env.NODE_DISABLE_COMPILE_CACHE = os.getenv("NODE_DISABLE_COMPILE_CACHE")
  else
    -- Keep the regression check focused on app/runtime startup, not Node's
    -- one-shot compile cache overhead, which varies across runner builds.
    env.NODE_DISABLE_COMPILE_CACHE = "1"
  end
  -- Keep the benchmark on a single process so RSS reflects the actual command
  -- path rather than the warning-suppression respawn wrapper.
  env.OPENCLAW_NO_RESPAWN = "1"

  return env
end

local function runCase(testCase)
  local env = buildBenchEnv()
  local result = child_process.spawnSync("node", {"--import", rssHookPath, unpack(testCase.args)}, {
    cwd = repoRoot,
    env = env,
    encoding = "utf8",
    maxBuffer = 20 * 1024 * 1024,
  })
  local stderr = result.stderr or ""
  local maxRssMb = parseMaxRssMb(stderr)
  local matrixBootstrapWarning = string.find(string.lower(stderr), "matrix: crypto runtime bootstrap failed") ~= nil

  if result.status ~= 0 then
    error(formatFailure(
      testCase,
      testCase.label .. " exited with " .. tostring(result.status),
      string.gsub(stderr, "^%s*(.-)%s*$", "%1") ~= "" and stderr or (result.stdout or "")
    ))
  end
  if maxRssMb == nil then
    error(formatFailure(testCase, testCase.label .. " did not report max RSS", stderr))
  end
  if matrixBootstrapWarning then
    error(formatFailure(testCase, testCase.label .. " triggered Matrix crypto bootstrap during startup"))
  end
  if maxRssMb > testCase.limitMb then
    error(formatFailure(
      testCase,
      testCase.label .. " used " .. string.format("%.1f", maxRssMb) .. " MB RSS (limit " .. testCase.limitMb .. " MB)"
    ))
  end

  print("[startup-memory] " .. testCase.label .. ": " .. string.format("%.1f", maxRssMb) .. " MB RSS (limit " .. testCase.limitMb .. " MB)")
end

local function main()
  for _, testCase in ipairs(cases) do
    local success, err = pcall(runCase, testCase)
    if not success then
      print(err)
      fs.rmSync(tmpHome, { recursive = true, force = true })
      os.exit(1)
    end
  end
  fs.rmSync(tmpHome, { recursive = true, force = true })
end

main()
