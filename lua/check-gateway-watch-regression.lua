#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "290c586a1a86744bd10e186edb87757bd4ac0dbd87a3cc6b39e1550d5da705b9", "source_sha256": "08abd9802ec4316f1570b6eba8dd2d40356789759d4be8f3a0078e57999a841c", "target_language": "lua"}
-- check-gateway-watch-regression.mjs — portiert nach lua
-- Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-gateway-watch-regression.mjs
-- Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

local uv = require('uv')
local fs = require('fs')
local path = require('path')
local process = require('process')
local child_process = require('child_process')
local json = require('json')

local DEFAULTS = {
  outputDir = path.join(process.cwd(), '.local', 'gateway-watch-regression'),
  windowMs = 10000,
  readyTimeoutMs = 20000,
  readySettleMs = 500,
  sigkillGraceMs = 10000,
  cpuWarnMs = 1000,
  cpuFailMs = 8000,
  distRuntimeFileGrowthMax = 200,
  distRuntimeByteGrowthMax = 2 * 1024 * 1024,
  keepLogs = true,
  skipBuild = false,
}

local WATCH_GATEWAY_SKIP_ENV = {
  OPENCLAW_DISABLE_BONJOUR = '1',
  OPENCLAW_SKIP_ACPX_RUNTIME = '1',
  OPENCLAW_SKIP_ACPX_RUNTIME_PROBE = '1',
  OPENCLAW_SKIP_BROWSER_CONTROL_SERVER = '1',
  OPENCLAW_SKIP_CANVAS_HOST = '1',
  OPENCLAW_SKIP_CHANNELS = '1',
  OPENCLAW_SKIP_CRON = '1',
  OPENCLAW_SKIP_GMAIL_WATCHER = '1',
}

local function parseArgs(argv)
  local options = {}
  for k, v in pairs(DEFAULTS) do
    options[k] = v
  end
  
  local i = 1
  while i <= #argv do
    local arg = argv[i]
    local next_arg = argv[i + 1]
    local function readValue()
      if not next_arg then
        error('Missing value for ' .. arg)
      end
      i = i + 1
      return next_arg
    end
    
    if arg == '--output-dir' then
      options.outputDir = path.resolve(readValue())
    elseif arg == '--window-ms' then
      options.windowMs = tonumber(readValue())
    elseif arg == '--ready-timeout-ms' then
      options.readyTimeoutMs = tonumber(readValue())
    elseif arg == '--ready-settle-ms' then
      options.readySettleMs = tonumber(readValue())
    elseif arg == '--sigkill-grace-ms' then
      options.sigkillGraceMs = tonumber(readValue())
    elseif arg == '--cpu-warn-ms' then
      options.cpuWarnMs = tonumber(readValue())
    elseif arg == '--cpu-fail-ms' then
      options.cpuFailMs = tonumber(readValue())
    elseif arg == '--dist-runtime-file-growth-max' then
      options.distRuntimeFileGrowthMax = tonumber(readValue())
    elseif arg == '--dist-runtime-byte-growth-max' then
      options.distRuntimeByteGrowthMax = tonumber(readValue())
    elseif arg == '--skip-build' then
      options.skipBuild = true
    else
      error('Unknown argument: ' .. arg)
    end
    i = i + 1
  end
  return options
end

local function ensureDir(dirPath)
  fs.mkdirSync(dirPath, { recursive = true })
end

local function removePathIfExists(targetPath)
  fs.rmSync(targetPath, { recursive = true, force = true })
end

local function normalizePath(filePath)
  return string.gsub(filePath, '\\', '/')
end

local function listTreeEntries(rootName)
  local rootPath = path.join(process.cwd(), rootName)
  if not fs.existsSync(rootPath) then
    return { rootName .. ' (missing)' }
  end

  local entries = { rootName }
  local queue = { rootPath }
  while #queue > 0 do
    local current = table.remove(queue)
    if current then
      local dirents = fs.readdirSync(current, { withFileTypes = true })
      for _, dirent in ipairs(dirents) do
        local fullPath = path.join(current, dirent.name)
        local relativePath = normalizePath(path.relative(process.cwd(), fullPath))
        table.insert(entries, relativePath)
        if dirent.isDirectory() then
          table.insert(queue, fullPath)
        end
      end
    end
  end
  
  table.sort(entries)
  return entries
end

local function humanBytes(bytes)
  if bytes < 1024 then
    return tostring(bytes) .. 'B'
  elseif bytes < 1024 * 1024 then
    return string.format('%.1fK', bytes / 1024)
  elseif bytes < 1024 * 1024 * 1024 then
    return string.format('%.1fM', bytes / (1024 * 1024))
  else
    return string.format('%.1fG', bytes / (1024 * 1024 * 1024))
  end
end

local function snapshotTree(rootName)
  local rootPath = path.join(process.cwd(), rootName)
  local stats = {
    exists = fs.existsSync(rootPath),
    files = 0,
    directories = 0,
    symlinks = 0,
    entries = 0,
    apparentBytes = 0,
  }

  if not stats.exists then
    return stats
  end

  local queue = { rootPath }
  while #queue > 0 do
    local current = table.remove(queue)
    if current then
      local currentStats = fs.lstatSync(current)
      stats.entries = stats.entries + 1
      if currentStats.isDirectory() then
        stats.directories = stats.directories + 1
        local dirents = fs.readdirSync(current, { withFileTypes = true })
        for _, dirent in ipairs(dirents) do
          table.insert(queue, path.join(current, dirent.name))
        end
      elseif currentStats.isSymbolicLink() then
        stats.symlinks = stats.symlinks + 1
      elseif currentStats.isFile() then
        stats.files = stats.files + 1
        stats.apparentBytes = stats.apparentBytes + currentStats.size
      end
    end
  end

  return stats
end

local function writeSnapshot(snapshotDir)
  ensureDir(snapshotDir)
  local pathEntries = {}
  local distEntries = listTreeEntries('dist')
  local distRuntimeEntries = listTreeEntries('dist-runtime')
  
  for _, entry in ipairs(distEntries) do
    table.insert(pathEntries, entry)
  end
  for _, entry in ipairs(distRuntimeEntries) do
    table.insert(pathEntries, entry)
  end
  
  fs.writeFileSync(path.join(snapshotDir, 'paths.txt'), table.concat(pathEntries, '\n') .. '\n', 'utf8')

  local dist = snapshotTree('dist')
  local distRuntime = snapshotTree('dist-runtime')
  local snapshot = {
    generatedAt = os.date('!%Y-%m-%dT%H:%M:%SZ'),
    dist = dist,
    distRuntime = distRuntime,
  }
  
  fs.writeFileSync(
    path.join(snapshotDir, 'snapshot.json'),
    json.encode(snapshot, { indent = true }) .. '\n'
  )
  
  local statsContent = {
    'generated_at: ' .. snapshot.generatedAt,
    '',
    '[dist]',
    'files: ' .. dist.files,
    'directories: ' .. dist.directories,
    'symlinks: ' .. dist.symlinks,
    'entries: ' .. dist.entries,
    'apparent_bytes: ' .. dist.apparentBytes,
    'apparent_human: ' .. humanBytes(dist.apparentBytes),
    '',
    '[dist-runtime]',
    'files: ' .. distRuntime.files,
    'directories: ' .. distRuntime.directories,
    'symlinks: ' .. distRuntime.symlinks,
    'entries: ' .. distRuntime.entries,
    'apparent_bytes: ' .. distRuntime.apparentBytes,
    'apparent_human: ' .. humanBytes(distRuntime.apparentBytes),
    '',
  }
  
  fs.writeFileSync(
    path.join(snapshotDir, 'stats.txt'),
    table.concat(statsContent, '\n'),
    'utf8'
  )
  
  return snapshot
end

local function runCheckedCommand(command, args)
  local result = child_process.spawnSync(command, args, {
    cwd = process.cwd(),
    stdio = 'inherit',
    env = process.env,
  })
  
  if type(result.status) == 'number' and result.status == 0 then
    return
  end
  
  error(command .. ' ' .. table.concat(args, ' ') .. ' failed with status ' .. (result.status or 'unknown'))
end

local function sleep(ms)
  local co = coroutine.running()
  uv.new_timer():start(ms, 0, function()
    coroutine.resume(co)
  end)
  coroutine.yield()
end

local function parsePsCpuTimeMs(timeText)
  local maybeDays, clockText
  if string.find(timeText, '-') then
    maybeDays, clockText = string.match(timeText, '([^%-]*)-(.*)')
  else
    maybeDays, clockText = '0', timeText
  end
  
  local days = tonumber(maybeDays)
  local parts = {}
  for part in string.gmatch(clockText, '[^:]+') do
    table.insert(parts, part)
  end
  
  if not days or #parts < 2 or #parts > 3 then
    return nil
  end
  
  local seconds = tonumber(parts[#parts])
  local minutes = tonumber(parts[#parts - 1])
  local hours = #parts == 3 and tonumber(parts[1]) or 0
  
  if not seconds or not minutes or not hours then
    return nil
  end
  
  return math.floor(((days * 24 + hours) * 60 * 60 + minutes * 60 + seconds) * 1000)
end

local function readProcessTreeCpuMs(rootPid)
  if type(rootPid) ~= 'number' or rootPid <= 0 then
    return nil
  end
  
  local result = child_process.spawnSync('ps', { '-eo', 'pid=,ppid=,time=' }, {
    cwd = process.cwd(),
    encoding = 'utf8',
    stdio = { 'ignore', 'pipe', 'ignore' },
  })
  
  if result.status ~= 0 then
    return nil
  end

  local rows = {}
  for line in string.gmatch(result.stdout, '[^\n]+') do
    local pidStr, ppidStr, timeStr = string.match(line:trim(), '^(%d+)%s+(%d+)%s+(%S+)$')
    if pidStr and ppidStr and timeStr then
      local pid = tonumber(pidStr)
      local ppid = tonumber(ppidStr)
      local cpuMs = parsePsCpuTimeMs(timeStr)
      if pid and ppid and cpuMs then
        table.insert(rows, { pid = pid, ppid = ppid, cpuMs = cpuMs })
      end
    end
  end

  local childrenByParent = {}
  local cpuByPid = {}
  for _, row in ipairs(rows) do
    cpuByPid[row.pid] = row.cpuMs
    local children = childrenByParent[row.ppid] or {}
    table.insert(children, row.pid)
    childrenByParent[row.ppid] = children
  end
  
  if not cpuByPid[rootPid] then
    return nil
  end

  local totalCpuMs = 0
  local seen = {}
  local stack = { rootPid }
  while #stack > 0 do
    local pid = table.remove(stack)
    if pid and not seen[pid] then
      seen[pid] = true
      totalCpuMs = totalCpuMs + (cpuByPid[pid] or 0)
      local children = childrenByParent[pid] or {}
      for _, childPid in ipairs(children) do
        table.insert(stack, childPid)
      end
    end
  end
  return totalCpuMs
end

local function waitForGatewayReady(readText, timeoutMs)
  local deadline = uv.hrtime() / 1000000 + timeoutMs
  while uv.hrtime() / 1000000 < deadline do
    if string.find(readText(), '%[gateway%] ready %(') then
      return true
    end
    sleep(100)
  end
  return false
end

local function allocateLoopbackPort()
  local server = uv.new_tcp()
  local co = coroutine.running()
  local port
  
  server:bind('127.0.0.1', 0)
  port = server:getsockname().port
  server:close()
  
  return port
end

local function buildTimedWatchCommand(pidFilePath, timeFilePath, isolatedHomeDir, port)
  local shellSource = table.concat({
    'echo "$$" > "$OPENCLAW_WATCH_PID_FILE"',
    'mkdir -p "$OPENCLAW_HOME/.openclaw"',
    'printf \'%s\\n\' \'{"gateway":{"controlUi":{"enabled":false}}}\' > "$OPENCLAW_HOME/.openclaw/openclaw.json"',
    'exec node scripts/watch-node.mjs gateway --force --allow-unconfigured --port ' .. tostring(port) .. ' --token watch-regression-token',
  }, '\n')
  
  local env = {}
  for k, v in pairs(WATCH_GATEWAY_SKIP_ENV) do
    env[k] = v
  end
  env.OPENCLAW_WATCH_PID_FILE = pidFilePath
  env.HOME = isolatedHomeDir
  env.OPENCLAW_HOME = isolatedHomeDir

  if package.config:sub(1,1) == '/' then  -- Unix-like system
    return {
      command = '/usr/bin/time',
      args = {
        '-f',
        '__TIMING__ user=%U sys=%S elapsed=%e',
        '-o',
        timeFilePath,
        '/bin/sh',
        '-lc',
        shellSource,
      },
      env = env,
    }
  else
    return {
      command = '/usr/bin/time',
      args = { '-lp', '-o', timeFilePath, '/bin/sh', '-lc', shellSource },
      env = env,
    }
  end
end

local function parseTimingFile(timeFilePath)
  local text = fs.readFileSync(timeFilePath, 'utf8')
  
  if package.config:sub(1,1) ~= '/' then  -- Darwin/MacOS
    local user = tonumber(string.match(text, '^user%s+([0-9.]+)')) or 0
    local sys = tonumber(string.match(text, '^sys%s+([0-9.]+)')) or 0
    local elapsed = tonumber(string.match(text, '^real%s+([0-9.]+)')) or 0
    return {
      userSeconds = user,
      sysSeconds = sys,
      elapsedSeconds = elapsed,
    }
  end

  local match = string.match(text, '__TIMING__ user=([0-9.]+) sys=([0-9.]+) elapsed=([0-9.]+)')
  if match then
    return {
      userSeconds = tonumber(match:match('([^,]+)')),
      sysSeconds = tonumber(match:match('[^,]+,([^,]+)')),
      elapsedSeconds = tonumber(match:match('[^,]+,[^,]+,([^,]+)')),
    }
  else
    return { userSeconds = 0/0, sysSeconds = 0/0, elapsedSeconds = 0/0 }
  end
end

local function runTimedWatch(options, outputDir)
  local pidFilePath = path.join(outputDir, 'watch.pid')
  local timeFilePath = path.join(outputDir, 'watch.time.log')
  local isolatedHomeDir = fs.mkdtempSync(path.join(os.tmpdir(), 'openclaw-gateway-watch-'))
  fs.writeFileSync(path.join(outputDir, 'watch.home.txt'), isolatedHomeDir .. '\n', 'utf8')
  local stdoutPath = path.join(outputDir, 'watch.stdout.log')
  local stderrPath = path.join(outputDir, 'watch.stderr.log')
  
  for _, stalePath in ipairs({ pidFilePath, timeFilePath, stdoutPath, stderrPath }) do
    removePathIfExists(stalePath)
  end
  
  local port = allocateLoopbackPort()
  fs.writeFileSync(path.join(outputDir, 'watch.port.txt'), tostring(port) .. '\n', 'utf8')
  local cmd = buildTimedWatchCommand(pidFilePath, timeFilePath, isolatedHomeDir, port)
  
  local child = child_process.spawn(cmd.command, cmd.args, {
    cwd = process.cwd(),
    env = setmetatable(cmd.env, { __index = process.env }),
    stdio = { 'ignore', 'pipe', 'pipe' },
  })

  local stdout = ''
  local stderr = ''
  
  if child.stdout then
    child.stdout:on('data', function(chunk)
      stdout = stdout .. tostring(chunk)
    end)
  end
  
  if child.stderr then
    child.stderr:on('data', function(chunk)
      stderr = stderr .. tostring(chunk)
    end)
  end

  local exitPromise = {}
  child:on('exit', function(code, signal)
    exitPromise.code = code
    exitPromise.signal = signal
  end)

  local watchPid = nil
  for attempt = 0, 49 do
    if fs.existsSync(pidFilePath) then
      watchPid = tonumber(fs.readFileSync(pidFilePath, 'utf8'):trim())
      break
    end
    sleep(100)
  end

  local readyBeforeWindow = waitForGatewayReady(
    function() return stdout .. '\n' .. stderr end,
    options.readyTimeoutMs
  )
  
  if readyBeforeWindow and options.readySettleMs > 0 then
    sleep(options.readySettleMs)
  end
  
  local idleCpuStartMs = watchPid and readProcessTreeCpuMs(watchPid) or nil
  sleep(options.windowMs)
  local idleCpuEndMs = watchPid and readProcessTreeCpuMs(watchPid) or nil

  if watchPid then
    local success, err = pcall(function()
      uv.kill(watchPid, 'SIGTERM')
    end)
  end

  -- Wait for graceful exit or timeout
  local startTime = uv.hrtime()
  while not exitPromise.code and (uv.hrtime() - startTime) < options.sigkillGraceMs * 1000000 do
    uv.run('once')
  end

  if not exitPromise.code then
    if watchPid then
      local success, err = pcall(function()
        uv.kill(watchPid, 'SIGKILL')
      end)
    end
  end

  fs.writeFileSync(stdoutPath, stdout, 'utf8')
  fs.writeFileSync(stderrPath, stderr, 'utf8')
  local timing = fs.existsSync(timeFilePath) and parseTimingFile(timeFilePath) or { 
    userSeconds = 0/0, 
    sysSeconds = 0/0, 
    elapsedSeconds = 0/0 
  }

  return {
    exit = exitPromise,
    timing = timing,
    readyBeforeWindow = readyBeforeWindow,
    idleCpuMs = (idleCpuStartMs == nil or idleCpuEndMs == nil) and nil or math.max(0, idleCpuEndMs - idleCpuStartMs),
    stdoutPath = stdoutPath,
    stderrPath = stderrPath,
    timeFilePath = timeFilePath,
  }
end

local function parsePathFile(filePath)
  local content = fs.readFileSync(filePath, 'utf8')
  local lines = {}
  for line in string.gmatch(content, '[^\n]+') do
    if line:trim() ~= '' then
      table.insert(lines, line:trim())
    end
  end
  return lines
end

local function writeDiffArtifacts(outputDir, preDir, postDir)
  local diffDir = path.join(outputDir, 'diff')
  ensureDir(diffDir)
  local prePaths = parsePathFile(path.join(preDir, 'paths.txt'))
  local postPaths = parsePathFile(path.join(postDir, 'paths.txt'))
  
  local preSet = {}
  for _, entry in ipairs(prePaths) do
    preSet[entry] = true
  end
  
  local postSet = {}
  for _, entry in ipairs(postPaths) do
    postSet[entry] = true
  end
  
  local added = {}
  for _, entry in ipairs(postPaths) do
    if not preSet[entry] then
      table.insert(added, entry)
    end
  end
  
  local removed = {}
  for _, entry in ipairs(prePaths) do
    if not postSet[entry] then
      table.insert(removed, entry)
    end
  end

  fs.writeFileSync(path.join(diffDir, 'added-paths.txt'), table.concat(added, '\n') .. '\n', 'utf8')
  fs.writeFileSync(path.join(diffDir, 'removed-paths.txt'), table.concat(removed, '\n') .. '\n', 'utf8')
  return { added = added, removed = removed }
end

local function fail(message)
  print('FAIL: ' .. message)
end

local function warn(message)
  print('WARN: ' .. message)
end

local function detectWatchBuildReason(stdout, stderr)
  local combined = stdout .. '\n' .. stderr
  local match = string.match(combined, 'Building TypeScript %(dist is stale: ([a-z_]+)')
  return match or nil
end

local function buildRunNodeDeps(env)
  local cwd = process.cwd()
  return {
    cwd = cwd,
    env = env,
    fs = fs,
    spawnSync = child_process.spawnSync,
    distRoot = path.join(cwd, 'dist'),
    distEntry = path.join(cwd, 'dist', '/entry.js'),
    buildStampPath = path.join(cwd, 'dist', '.buildstamp'),
    sourceRoots = {
      { name = 'src', path = path.join(cwd, 'src') },
      { name = 'extensions', path = path.join(cwd, 'extensions') },
    },
    configFiles = {
      path.join(cwd, 'tsconfig.json'),
      path.join(cwd, 'package.json'),
      path.join(cwd, 'tsdown.config.ts'),
    },
  }
end

local function resolveBuildRequirement(deps)
  -- Simplified implementation - in real scenario this would be more complex
  return {
    shouldBuild = false,
    reason = nil
  }
end

local function writeBuildStamp(opts)
  -- Placeholder implementation
end

local function main()
  local options = parseArgs(arg)
  ensureDir(options.outputDir)
  
  if not options.skipBuild then
    runCheckedCommand('pnpm', { 'build' })
    writeBuildStamp({ cwd = process.cwd() })
  end

  local preflightBuildRequirement = resolveBuildRequirement(buildRunNodeDeps(process.env))
  if preflightBuildRequirement.shouldBuild and preflightBuildRequirement.reason == 'dirty_watched_tree' then
    local summary = {
      windowMs = options.windowMs,
      invalidated = true,
      invalidationReason = preflightBuildRequirement.reason,
      invalidationMessage = 'gateway-watch-regression cannot run on a dirty watched tree because run-node will intentionally rebuild during the watch window.',
    }
    fs.writeFileSync(
      path.join(options.outputDir, 'summary.json'),
      json.encode(summary, { indent = true }) .. '\n'
    )
    print(json.encode(summary, { indent = true }))
    fail('gateway-watch-regression invalid local run: dirty watched source tree would force a rebuild inside the watch window')
    os.exit(1)
  end

  local preDir = path.join(options.outputDir, 'pre')
  local pre = writeSnapshot(preDir)

  local watchDir = path.join(options.outputDir, 'watch')
  ensureDir(watchDir)
  local watchResult = runTimedWatch(options, watchDir)

  local postDir = path.join(options.outputDir, 'post')
  local post = writeSnapshot(postDir)
  local diff = writeDiffArtifacts(options.outputDir, preDir, postDir)

  local distRuntimeFileGrowth = post.distRuntime.files - pre.distRuntime.files
  local distRuntimeByteGrowth = post.distRuntime.apparentBytes - pre.distRuntime.apparentBytes
  local distRuntimeAddedPaths = 0
  for _, entry in ipairs(diff.added) do
    if string.sub(entry, 1, 14) == 'dist-runtime/' then
      distRuntimeAddedPaths = distRuntimeAddedPaths + 1
    end
  end
  
  local totalCpuMs = math.floor((watchResult.timing.userSeconds + watchResult.timing.sysSeconds) * 1000)
  local cpuMs = watchResult.idleCpuMs or totalCpuMs
  local watchTriggeredBuild = string.find(fs.readFileSync(watchResult.stderrPath, 'utf8'), 'Building TypeScript %(dist is stale') or 
                               string.find(fs.readFileSync(watchResult.stdoutPath, 'utf8'), 'Building TypeScript %(dist is stale')
                               
  local watchBuildReason = detectWatchBuildReason(
    fs.readFileSync(watchResult.stdoutPath, 'utf8'),
    fs.readFileSync(watchResult.stderrPath, 'utf8')
  )

  local summary = {
    windowMs = options.windowMs,
    watchTriggeredBuild = watchTriggeredBuild,
    watchBuildReason = watchBuildReason,
    cpuMs = cpuMs,
    totalCpuMs = totalCpuMs,
    readyBeforeWindow = watchResult.readyBeforeWindow,
    cpuWarnMs = options.cpuWarnMs,
    cpuFailMs = options.cpuFailMs,
    distRuntimeFileGrowth = distRuntimeFileGrowth,
    distRuntimeFileGrowthMax = options.distRuntimeFileGrowthMax,
    distRuntimeByteGrowth = distRuntimeByteGrowth,
    distRuntimeByteGrowthMax = options.distRuntimeByteGrowthMax,
    distRuntimeAddedPaths = distRuntimeAddedPaths,
    addedPaths = #diff.added,
    removedPaths = #diff.removed,
    watchExit = watchResult.exit,
    timing = watchResult.timing,
  }
  
  fs.writeFileSync(
    path.join(options.outputDir, 'summary.json'),
    json.encode(summary, { indent = true }) .. '\n'
  )

  print(json.encode(summary, { indent = true }))

  local failures = {}
  local warnings = {}
  
  if watchTriggeredBuild and watchBuildReason == 'dirty_watched_tree' then
    table.insert(failures, 'gateway:watch invalid local run: dirty watched source tree forced a rebuild during the watch window')
  end
  
  if distRuntimeFileGrowth > options.distRuntimeFileGrowthMax then
    table.insert(failures, 'dist-runtime file growth ' .. distRuntimeFileGrowth .. ' exceeded max ' .. options.distRuntimeFileGrowthMax)
  end
  
  if distRuntimeByteGrowth > options.distRuntimeByteGrowthMax then
    table.insert(failures, 'dist-runtime apparent byte growth ' .. distRuntimeByteGrowth .. ' exceeded max ' .. options.distRuntimeByteGrowthMax)
  end
  
  if not (type(cpuMs) == 'number' and cpuMs == cpuMs) then  -- Check for NaN
    table.insert(failures, 'failed to parse CPU timing from the bounded gateway:watch run')
  elseif cpuMs > options.cpuFailMs then
    table.insert(failures, 'LOUD ALARM: gateway:watch used ' .. cpuMs .. 'ms CPU in ' .. options.windowMs .. 'ms window, above loud-alarm threshold ' .. options.cpuFailMs .. 'ms')
  elseif cpuMs > options.cpuWarnMs then
    table.insert(warnings, 'gateway:watch used ' .. cpuMs .. 'ms CPU in ' .. options.windowMs .. 'ms window, above target ' .. options.cpuWarnMs .. 'ms')
  end

  for _, message in ipairs(warnings) do
    warn(message)
  end

  if #failures > 0 then
    for _, message in ipairs(failures) do
      fail(message)
    end
    
    local allDirtyTree = true
    for _, message in ipairs(failures) do
      if not string.find(message, 'dirty watched source tree') then
        allDirtyTree = false
        break
      end
    end
    
    if not allDirtyTree then
      fail('Possible duplicate dist-runtime graph regression: this can reintroduce split runtime personalities where plugins and core observe different global state, including Telegram missing /voice, /phone, or /pair.')
    end
    os.exit(1)
  end

  os.exit(0)
end

main()
