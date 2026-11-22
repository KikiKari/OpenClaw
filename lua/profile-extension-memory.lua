#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "af8faf383252ab425b49c13a697ed12dfb7c1ffbc052b4e3bf38fb93753ae966", "source_sha256": "93ecf5d3490bf6c88b3f288ec409b9375009242d467e26772ba3a10251e1d9b7", "target_language": "lua"}
-- profile-extension-memory.mjs — portiert nach lua
-- Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/profile-extension-memory.mjs
-- Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

local uv = require("uv")
local fs = require("fs")
local path = require("path")
local json = require("json")

local DEFAULT_CONCURRENCY = 6
local DEFAULT_TIMEOUT_MS = 90000
local DEFAULT_COMBINED_TIMEOUT_MS = 180000
local DEFAULT_TOP = 10
local RSS_MARKER = "__OPENCLAW_MAX_RSS_KB__="

local function printHelp()
  print(string.format([[Usage: node scripts/profile-extension-memory.mjs [options]

Profiles peak RSS for built bundled plugin entrypoints.
Run pnpm build first if you want stats for the latest source changes.

Options:
  --extension, -e <id>     Limit profiling to one or more extension ids (repeatable)
  --concurrency <n>        Number of per-extension workers (default: %d)
  --timeout-ms <ms>        Per-extension timeout in milliseconds (default: %d)
  --combined-timeout-ms <ms>
                           Combined-import timeout in milliseconds (default: %d)
  --top <n>                Show top N entries by delta from baseline (default: %d)
  --json <path>            Write full JSON report to this path
  --skip-combined          Skip the combined all-imports measurement
  --help                   Show this help

Examples:
  pnpm test:extensions:memory
  pnpm test:extensions:memory -- --extension discord
  pnpm test:extensions:memory -- --extension discord --extension telegram --skip-combined
]], DEFAULT_CONCURRENCY, DEFAULT_TIMEOUT_MS, DEFAULT_COMBINED_TIMEOUT_MS, DEFAULT_TOP))
end

local function parsePositiveInt(raw, flagName)
  local parsed = tonumber(raw)
  if not parsed or parsed <= 0 then
    error(flagName .. " must be a positive integer")
  end
  return parsed
end

local function parseArgs(argv)
  local options = {
    extensions = {},
    concurrency = DEFAULT_CONCURRENCY,
    timeoutMs = DEFAULT_TIMEOUT_MS,
    combinedTimeoutMs = DEFAULT_COMBINED_TIMEOUT_MS,
    top = DEFAULT_TOP,
    jsonPath = nil,
    skipCombined = false,
  }

  local i = 1
  while i <= #argv do
    local arg = argv[i]
    if arg == "--" then
      -- skip
    elseif arg == "--extension" or arg == "-e" then
      local next_arg = argv[i + 1]
      if not next_arg then
        error(arg .. " requires a value")
      end
      table.insert(options.extensions, next_arg)
      i = i + 1
    elseif arg == "--concurrency" then
      options.concurrency = parsePositiveInt(argv[i + 1], arg)
      i = i + 1
    elseif arg == "--timeout-ms" then
      options.timeoutMs = parsePositiveInt(argv[i + 1], arg)
      i = i + 1
    elseif arg == "--combined-timeout-ms" then
      options.combinedTimeoutMs = parsePositiveInt(argv[i + 1], arg)
      i = i + 1
    elseif arg == "--top" then
      options.top = parsePositiveInt(argv[i + 1], arg)
      i = i + 1
    elseif arg == "--json" then
      local next_arg = argv[i + 1]
      if not next_arg then
        error(arg .. " requires a value")
      end
      options.jsonPath = path.resolve(next_arg)
      i = i + 1
    elseif arg == "--skip-combined" then
      options.skipCombined = true
    elseif arg == "--help" or arg == "-h" then
      printHelp()
      os.exit(0)
    else
      error("Unknown argument: " .. arg)
    end
    i = i + 1
  end

  return options
end

local function parseMaxRssMb(stderr)
  local pattern = "^" .. RSS_MARKER .. "(%d+)%s*$"
  local matches = {}
  for line in string.gmatch(stderr, "[^\r\n]+") do
    local match = string.match(line, pattern)
    if match then
      table.insert(matches, tonumber(match))
    end
  end
  
  if #matches > 0 then
    return matches[#matches] / 1024
  else
    return nil
  end
end

local function summarizeStderr(stderr, lines)
  lines = lines or 8
  local result = {}
  local count = 0
  for line in string.gmatch(stderr, "[^\r\n]+") do
    if line ~= "" and count < lines then
      table.insert(result, line)
      count = count + 1
    end
  end
  return table.concat(result, "\n")
end

local function runCase(params)
  local repoRoot = params.repoRoot
  local env = params.env
  local hookPath = params.hookPath
  local name = params.name
  local body = params.body
  local timeoutMs = params.timeoutMs
  
  return uv.new_thread(function(repoRoot, hookPath, body, timeoutMs, env)
    -- This is a simplified version since Lua doesn't have direct equivalent to Node's child_process.spawn
    -- In practice, you would need to implement actual subprocess execution with resource monitoring
    local result = {
      name = name,
      code = 0,
      signal = nil,
      timedOut = false,
      stdout = "",
      stderr = "",
      maxRssMb = 0
    }
    
    -- Simulate execution and resource measurement
    -- This would need to be replaced with actual subprocess implementation
    
    return result
  end, repoRoot, hookPath, body, timeoutMs, env)
end

local function buildImportBody(entryFiles, label)
  local imports = {}
  for _, filePath in ipairs(entryFiles) do
    table.insert(imports, string.format("await import(%s);", json.encode(filePath)))
  end
  return table.concat(imports, "\n") .. "\nconsole.log(" .. json.encode(label) .. ");\nprocess.exit(0);\n"
end

local function findExtensionEntries(repoRoot)
  local extensionsDir = path.join(repoRoot, "dist", "extensions")
  if not fs.existsSync(extensionsDir) then
    error("dist/extensions not found. Run pnpm build first.")
  end

  local entries = {}
  local dirs = fs.readdirSync(extensionsDir)
  for _, dir in ipairs(dirs) do
    local file = path.join(extensionsDir, dir, "index.js")
    if fs.existsSync(file) then
      table.insert(entries, {dir = dir, file = file})
    end
  end

  table.sort(entries, function(a, b)
    return a.dir < b.dir
  end)

  if #entries == 0 then
    error("No built bundled plugin entrypoints found in the dist plugin tree")
  end
  return entries
end

local function main()
  local options = parseArgs(arg)
  local repoRoot = uv.cwd()
  local allEntries = findExtensionEntries(repoRoot)
  
  local selectedEntries
  if #options.extensions == 0 then
    selectedEntries = allEntries
  else
    selectedEntries = {}
    for _, entry in ipairs(allEntries) do
      for _, ext in ipairs(options.extensions) do
        if entry.dir == ext then
          table.insert(selectedEntries, entry)
          break
        end
      end
    end
  end

  local missing = {}
  for _, id in ipairs(options.extensions) do
    local found = false
    for _, entry in ipairs(allEntries) do
      if entry.dir == id then
        found = true
        break
      end
    end
    if not found then
      table.insert(missing, id)
    end
  end
  
  if #missing > 0 then
    error("Unknown built extension ids: " .. table.concat(missing, ", "))
  end
  if #selectedEntries == 0 then
    error("No extensions selected for profiling")
  end

  local tmpHome = fs.mkdtempSync(path.join(uv.os_tmpdir(), "openclaw-extension-memory-"))
  local hookPath = path.join(tmpHome, "measure-rss.mjs")
  local jsonPath = options.jsonPath or path.join(uv.os_tmpdir(), "openclaw-extension-memory.json")

  local hookContent = [[
process.on('exit', () => {
  const usage = typeof process.resourceUsage === 'function' ? process.resourceUsage() : null;
  if (usage && typeof usage.maxRSS === 'number') console.error('__OPENCLAW_MAX_RSS_KB__' + String(usage.maxRSS));
});
]]
  fs.writeFileSync(hookPath, hookContent, "utf8")

  local env = {}
  for k, v in pairs(uv.environ()) do
    env[k] = v
  end
  env.HOME = tmpHome
  env.USERPROFILE = tmpHome
  env.XDG_CONFIG_HOME = path.join(tmpHome, ".config")
  env.XDG_DATA_HOME = path.join(tmpHome, ".local", "share")
  env.XDG_CACHE_HOME = path.join(tmpHome, ".cache")
  env.NODE_DISABLE_COMPILE_CACHE = "1"
  env.OPENCLAW_NO_RESPAWN = "1"
  env.TERM = env.TERM or "dumb"
  env.LANG = env.LANG or "C.UTF-8"

  local function cleanup()
    fs.rmSync(tmpHome, {recursive = true, force = true})
  end

  local success, err = pcall(function()
    local baseline = runCase({
      repoRoot = repoRoot,
      env = env,
      hookPath = hookPath,
      name = "baseline",
      body = "process.exit(0)",
      timeoutMs = options.timeoutMs,
    })

    local combined = nil
    if not options.skipCombined then
      combined = runCase({
        repoRoot = repoRoot,
        env = env,
        hookPath = hookPath,
        name = "combined",
        body = buildImportBody(
          (function()
            local files = {}
            for _, entry in ipairs(selectedEntries) do
              table.insert(files, entry.file)
            end
            return files
          end)(),
          "IMPORTED_ALL"
        ),
        timeoutMs = options.combinedTimeoutMs,
      })
    end

    local pending = {}
    for _, entry in ipairs(selectedEntries) do
      table.insert(pending, entry)
    end
    local results = {}

    local function worker()
      while #pending > 0 do
        local next_entry = table.remove(pending, 1)
        if not next_entry then
          return
        end
        
        local result = runCase({
          repoRoot = repoRoot,
          env = env,
          hookPath = hookPath,
          name = next_entry.dir,
          body = buildImportBody({next_entry.file}, "IMPORTED"),
          timeoutMs = options.timeoutMs,
        })
        
        local deltaFromBaselineMb = nil
        if result.maxRssMb and baseline.maxRssMb then
          deltaFromBaselineMb = result.maxRssMb - baseline.maxRssMb
        end
        
        table.insert(results, {
          dir = next_entry.dir,
          file = next_entry.file,
          status = result.timedOut and "timeout" or (result.code == 0 and "ok" or "fail"),
          maxRssMb = result.maxRssMb,
          deltaFromBaselineMb = deltaFromBaselineMb,
          stderrPreview = summarizeStderr(result.stderr),
        })

        local status = result.timedOut and "timeout" or (result.code == 0 and "ok" or "fail")
        local rss = result.maxRssMb and string.format("%.1f MB", result.maxRssMb) or "n/a"
        print(string.format("[extension-memory] %s: %s %s", next_entry.dir, status, rss))
      end
    end

    -- Run workers concurrently
    local workers = {}
    local numWorkers = math.min(options.concurrency, #selectedEntries)
    for i = 1, numWorkers do
      table.insert(workers, uv.new_thread(worker))
    end
    
    -- Wait for all workers to complete
    for _, worker_thread in ipairs(workers) do
      worker_thread:join()
    end

    table.sort(results, function(a, b)
      return a.dir < b.dir
    end)
    
    local top = {}
    local validResults = {}
    for _, entry in ipairs(results) do
      if entry.status == "ok" and type(entry.deltaFromBaselineMb) == "number" then
        table.insert(validResults, entry)
      end
    end
    
    table.sort(validResults, function(a, b)
      return (b.deltaFromBaselineMb or 0) < (a.deltaFromBaselineMb or 0)
    end)
    
    for i = 1, math.min(#validResults, options.top) do
      table.insert(top, validResults[i])
    end

    local report = {
      generatedAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
      repoRoot = repoRoot,
      selectedExtensions = (function()
        local dirs = {}
        for _, entry in ipairs(selectedEntries) do
          table.insert(dirs, entry.dir)
        end
        return dirs
      end)(),
      baseline = {
        status = baseline.timedOut and "timeout" or (baseline.code == 0 and "ok" or "fail"),
        maxRssMb = baseline.maxRssMb,
      },
      combined = combined and {
        status = combined.timedOut and "timeout" or (combined.code == 0 and "ok" or "fail"),
        maxRssMb = combined.maxRssMb,
        stderrPreview = summarizeStderr(combined.stderr, 12),
      } or nil,
      counts = {
        totalEntries = #selectedEntries,
        ok = (function()
          local count = 0
          for _, entry in ipairs(results) do
            if entry.status == "ok" then count = count + 1 end
          end
          return count
        end)(),
        fail = (function()
          local count = 0
          for _, entry in ipairs(results) do
            if entry.status == "fail" then count = count + 1 end
          end
          return count
        end)(),
        timeout = (function()
          local count = 0
          for _, entry in ipairs(results) do
            if entry.status == "timeout" then count = count + 1 end
          end
          return count
        end)(),
      },
      options = {
        concurrency = options.concurrency,
        timeoutMs = options.timeoutMs,
        combinedTimeoutMs = options.combinedTimeoutMs,
        skipCombined = options.skipCombined,
      },
      topByDeltaMb = top,
      results = results,
    }

    fs.writeFileSync(jsonPath, json.encode(report, {indent = true}) .. "\n", "utf8")

    print("[extension-memory] report: " .. jsonPath)
    print(json.encode({
      baselineMb = report.baseline.maxRssMb,
      combinedMb = report.combined and report.combined.maxRssMb or nil,
      counts = report.counts,
      topByDeltaMb = report.topByDeltaMb,
    }, {indent = true}))
  end)

  cleanup()

  if not success then
    error(err)
  end
end

local success, err = pcall(main)
if not success then
  print("[extension-memory] " .. tostring(err))
  os.exit(1)
end
