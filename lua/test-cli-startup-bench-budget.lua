#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "e69da1fc0897013858d5e65606d28b6c1f7ac64a94ac26ba5223ee19aee50b01", "source_sha256": "c6c7301dda8709e6c39c53f79a83f8f7938854384f4e21e1114095d876e51a6d", "target_language": "lua"}
-- test-cli-startup-bench-budget.mjs — portiert nach lua
-- Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/test-cli-startup-bench-budget.mjs
-- Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

local fs = require("lfs")
local json = require("cjson")

local function readEnvNumber(name)
  local value = os.getenv(name)
  if value then
    return tonumber(value)
  end
  return nil
end

local function formatMs(value)
  return string.format("%.1fms", value)
end

local function formatMb(value)
  return string.format("%.1fMB", value)
end

local function readFile(path)
  local file = io.open(path, "r")
  if not file then
    error("Could not read file: " .. path)
  end
  local content = file:read("*a")
  file:close()
  return content
end

local function readJsonFile(path)
  local content = readFile(path)
  return json.decode(content)
end

local function writeJsonFile(path, data)
  local file = io.open(path, "w")
  if not file then
    error("Could not write file: " .. path)
  end
  file:write(json.encode(data))
  file:close()
end

local function mkdirp(path)
  local parts = {}
  for part in string.gmatch(path, "[^/]+") do
    table.insert(parts, part)
    local partial = table.concat(parts, "/")
    if partial ~= "" and not fs.attributes(partial) then
      local success, err = fs.mkdir(partial)
      if not success then
        error("Failed to create directory: " .. partial .. " - " .. err)
      end
    end
  end
end

local function spawnSync(command, args, options)
  local argString = ""
  for _, arg in ipairs(args) do
    argString = argString .. " " .. arg
  end
  
  local fullCommand = command .. argString
  local exitCode = os.execute(fullCommand)
  
  return {
    status = exitCode
  }
end

local CLI_STARTUP_BENCH_FIXTURE_PATH = "test/fixtures/cli-startup-bench.json"

local args = {...}
local showHelp = false
local opts = {
  baseline = CLI_STARTUP_BENCH_FIXTURE_PATH,
  report = "",
  entry = "openclaw.mjs",
  preset = "all",
  runs = 1,
  warmup = 0,
  timeoutMs = 30000,
  maxDurationRegressionPct = readEnvNumber("OPENCLAW_STARTUP_BENCH_MAX_DURATION_REGRESSION_PCT") or 20,
  maxRssRegressionPct = readEnvNumber("OPENCLAW_STARTUP_BENCH_MAX_RSS_REGRESSION_PCT") or 20
}

for i = 1, #args do
  local arg = args[i]
  if arg == "--help" then
    showHelp = true
  elseif arg == "--baseline" and args[i+1] then
    opts.baseline = args[i+1]
    i = i + 1
  elseif arg == "--report" and args[i+1] then
    opts.report = args[i+1]
    i = i + 1
  elseif arg == "--entry" and args[i+1] then
    opts.entry = args[i+1]
    i = i + 1
  elseif arg == "--preset" and args[i+1] then
    opts.preset = args[i+1]
    i = i + 1
  elseif arg == "--runs" and args[i+1] then
    opts.runs = tonumber(args[i+1])
    i = i + 1
  elseif arg == "--warmup" and args[i+1] then
    opts.warmup = tonumber(args[i+1])
    i = i + 1
  elseif arg == "--timeout-ms" and args[i+1] then
    opts.timeoutMs = tonumber(args[i+1])
    i = i + 1
  elseif arg == "--max-duration-regression-pct" and args[i+1] then
    opts.maxDurationRegressionPct = tonumber(args[i+1])
    i = i + 1
  elseif arg == "--max-rss-regression-pct" and args[i+1] then
    opts.maxRssRegressionPct = tonumber(args[i+1])
    i = i + 1
  end
end

if showHelp then
  print([[
Usage: lua scripts/test-cli-startup-bench-budget.lua [options]

Compare current CLI benchmark results against the checked-in fixture.

Options:
  --baseline <path>             Baseline fixture path
  --report <path>               Reuse an existing current benchmark report
  --entry <path>                CLI entry to benchmark when report is omitted
  --preset <name>               startup | real | all (default: all)
  --runs <n>                    Measured runs per case (default: 1)
  --warmup <n>                  Warmup runs per case (default: 0)
  --timeout-ms <ms>             Per-run timeout (default: 30000)
  --max-duration-regression-pct <n>
                                Fail if avg duration regresses more than this percent
  --max-rss-regression-pct <n>  Fail if avg RSS regresses more than this percent
  --help                        Show this help text

Example:
  lua scripts/test-cli-startup-bench-budget.lua --preset real --max-duration-regression-pct 15
]])
  os.exit(0)
end

local function resolveCurrentReportPath()
  if opts.report ~= "" then
    return opts.report
  end
  local reportPath = ".artifacts/cli-startup-bench.current.json"
  mkdirp(".artifacts")
  local args = {
    "--import",
    "tsx",
    "scripts/bench-cli-startup.ts",
    "--entry",
    opts.entry,
    "--preset",
    opts.preset,
    "--runs",
    tostring(opts.runs),
    "--warmup",
    tostring(opts.warmup),
    "--timeout-ms",
    tostring(opts.timeoutMs),
    "--output",
    reportPath,
  }
  local run = spawnSync("node", args, {
    cwd = fs.currentdir(),
  })
  if run.status ~= 0 then
    os.exit(run.status or 1)
  end
  return reportPath
end

local function indexCases(report)
  local result = {}
  if report and report.primary and report.primary.cases then
    for _, entry in ipairs(report.primary.cases) do
      result[entry.id] = entry
    end
  end
  return result
end

local baseline = readJsonFile(opts.baseline)
local current = readJsonFile(resolveCurrentReportPath())
local baselineCases = indexCases(baseline)
local currentCases = indexCases(current)

local failed = false

for id, baselineCase in pairs(baselineCases) do
  local currentCase = currentCases[id]
  if not currentCase then
    print("[test-cli-startup-bench-budget] missing current case " .. tostring(id))
    failed = true
    goto continue
  end

  local baselineDuration = baselineCase.summary and baselineCase.summary.durationMs and baselineCase.summary.durationMs.avg
  local currentDuration = currentCase.summary and currentCase.summary.durationMs and currentCase.summary.durationMs.avg
  if type(baselineDuration) == "number" and type(currentDuration) == "number" and baselineDuration > 0 then
    local allowedDuration = baselineDuration * (1 + opts.maxDurationRegressionPct / 100)
    if currentDuration > allowedDuration then
      print(string.format(
        "[test-cli-startup-bench-budget] %s avg duration %s exceeded %s (baseline %s, +%s%%).",
        baselineCase.name,
        formatMs(currentDuration),
        formatMs(allowedDuration),
        formatMs(baselineDuration),
        tostring(opts.maxDurationRegressionPct)
      ))
      failed = true
    end
  end

  local baselineRss = baselineCase.summary and baselineCase.summary.maxRssMb and baselineCase.summary.maxRssMb.avg
  local currentRss = currentCase.summary and currentCase.summary.maxRssMb and currentCase.summary.maxRssMb.avg
  if type(baselineRss) == "number" and type(currentRss) == "number" and baselineRss > 0 then
    local allowedRss = baselineRss * (1 + opts.maxRssRegressionPct / 100)
    if currentRss > allowedRss then
      print(string.format(
        "[test-cli-startup-bench-budget] %s avg RSS %s exceeded %s (baseline %s, +%s%%).",
        baselineCase.name,
        formatMb(currentRss),
        formatMb(allowedRss),
        formatMb(baselineRss),
        tostring(opts.maxRssRegressionPct)
      ))
      failed = true
    end
  end

  local rssStr = "n/a"
  if type(currentRss) == "number" then
    rssStr = formatMb(currentRss)
  end
  
  local baselineRssStr = "n/a"
  if type(baselineRss) == "number" then
    baselineRssStr = formatMb(baselineRss)
  end
  
  print(string.format(
    "[test-cli-startup-bench-budget] %s duration=%s baseline=%s rss=%s baselineRss=%s",
    baselineCase.name,
    formatMs(currentDuration or 0),
    formatMs(baselineDuration or 0),
    rssStr,
    baselineRssStr
  ))

  ::continue::
end

if failed then
  os.exit(1)
end
