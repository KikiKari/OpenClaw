#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "137924b73bc617af1ab32f4e5810b2fa5027fa15f1ac467f4792d10602f3426f", "source_sha256": "d0e229aab6f22cce6a57639e2ffb6182fc50c823ca2adff745764d168dc70826", "target_language": "lua"}
-- audit-seams.mjs — portiert nach lua
-- Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/audit-seams.mjs
-- Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

local fs = require("lfs")
local path = require("path")
local json = require("dkjson")

-- Constants
local repoRoot = path.resolve(arg[0]:match("(.*)[/\\][^/\\]+$"))
local srcRoot = path.join(repoRoot, "src")
local extensionsRoot = path.join(repoRoot, "extensions")
local testRoot = path.join(repoRoot, "test")
local workspacePackagePaths = {"ui/package.json"}
local MAX_SCAN_BYTES = 2 * 1024 * 1024

-- Helper functions
local function normalizePath(filePath)
  return path.relative(repoRoot, filePath):gsub("\\", "/")
end

local function readScannableText(filePath, maxBytes)
  maxBytes = maxBytes or MAX_SCAN_BYTES
  local file = io.open(filePath, "rb")
  if not file then return nil end
  
  local size = file:seek("end")
  file:seek("set", 0)
  
  if size <= maxBytes then
    local content = file:read("*a")
    file:close()
    return content
  end
  
  local buffer = file:read(maxBytes)
  file:close()
  return buffer
end

local function isCodeFile(fileName)
  return fileName:match("%.(ts|tsx|mts|cts|js|jsx|mjs|cjs)$") ~= nil
end

local function isTestLikePath(relativePath)
  return relativePath:match("(__tests__|fixtures|test%-utils|test%-fixtures)") ~= nil or
         relativePath:match("[.-](test|spec)%.[^.]+$") ~= nil
end

local function isProductionLikeFile(relativePath)
  return not isTestLikePath(relativePath)
end

local function walkCodeFiles(rootDir, includeTests)
  local out = {}
  
  local function walk(dir)
    local attr = lfs.attributes(dir)
    if not attr or attr.mode ~= "directory" then return end
    
    for file in lfs.dir(dir) do
      if file ~= "." and file ~= ".." then
        local fullPath = path.join(dir, file)
        local attr = lfs.attributes(fullPath)
        
        if attr.mode == "directory" and file ~= "dist" and file ~= "node_modules" then
          walk(fullPath)
        elseif attr.mode == "file" and isCodeFile(file) then
          local relativePath = normalizePath(fullPath)
          if includeTests or isProductionLikeFile(relativePath) then
            table.insert(out, fullPath)
          end
        end
      end
    end
  end
  
  walk(rootDir)
  table.sort(out, function(a, b) 
    return normalizePath(a) < normalizePath(b)
  end)
  return out
end

local function stemFromRelativePath(relativePath)
  return relativePath:gsub("%.[^.]+$", "")
end

local function splitNameTokens(name)
  local tokens = {}
  for token in name:gmatch("[%w]+") do
    token = token:lower():gsub("^%s*(.-)%s*$", "%1")
    if #token >= 1 then
      table.insert(tokens, token)
    end
  end
  return tokens
end

local function escapeForRegExp(value)
  return value:gsub("([%.%*%+%?%^%$%%%(%)|%[%]%\\%-])", "%%%1")
end

local function hasImportSource(source, specifier)
  local escaped = escapeForRegExp(specifier)
  return source:match("from%s+[\"']" .. escaped .. "[\"']") or 
         source:match("import%s*%(%s*[\"']" .. escaped .. "[\"']%s*%)")
end

local function hasAnyImportSource(source, specifiers)
  for _, specifier in ipairs(specifiers) do
    if hasImportSource(source, specifier) then
      return true
    end
  end
  return false
end

local function isCronProductionPath(relativePath)
  return relativePath:sub(1, 9) == "src/cron/" and isProductionLikeFile(relativePath)
end

local function isSubagentProductionPath(relativePath)
  return (relativePath:sub(1, 11) == "src/agents/" or relativePath:sub(1, 9) == "src/cron/") and
         isProductionLikeFile(relativePath) and
         (relativePath:match("subagent") or 
          relativePath:match("sessions%-spawn") or
          relativePath:match("acp%-spawn") or
          relativePath == "src/agents/tools/sessions-spawn-tool.ts" or
          relativePath == "src/agents/tools/subagents-tool.ts")
end

local function describeCronSeamKinds(relativePath, source)
  if not isCronProductionPath(relativePath) then
    return {}
  end

  local seamKinds = {}
  local importsAgentRunner = hasAnyImportSource(source, {
    "../../agents/cli-runner.js",
    "../../agents/pi-embedded.js",
    "../../agents/model-fallback.js",
    "../../agents/subagent-registry.js",
    "../../infra/agent-events.js",
  })
  local importsOutboundDelivery = hasAnyImportSource(source, {
    "../infra/outbound/deliver.js",
    "../../infra/outbound/deliver.js",
    "../infra/outbound/session-context.js",
    "../../infra/outbound/session-context.js",
    "../infra/outbound/identity.js",
    "../../infra/outbound/identity.js",
    "../cli/outbound-send-deps.js",
    "../../cli/outbound-send-deps.js",
  })
  local importsHeartbeat = hasAnyImportSource(source, {
    "../auto-reply/heartbeat.js",
    "../../auto-reply/heartbeat.js",
    "../infra/heartbeat-wake.js",
    "../../infra/heartbeat-wake.js",
  })
  local importsFollowup = hasAnyImportSource(source, {
    "./subagent-followup.js",
    "../../agents/subagent-registry.js",
    "../../agents/tools/agent-step.js",
    "../../gateway/call.js",
  })
  local importsSchedulerModules = relativePath:sub(1, 17) == "src/cron/service/" and
    hasAnyImportSource(source, {
      "./jobs.js",
      "./store.js",
      "./timer.js",
      "./state.js",
      "../schedule.js",
      "../store.js",
      "../run-log.js",
    })

  if importsAgentRunner and source:match("runCliAgent") or source:match("runEmbeddedPiAgent") or
     source:match("runWithModelFallback") or source:match("registerAgentRunContext") then
    table.insert(seamKinds, "cron-agent-handoff")
  end

  if importsOutboundDelivery and source:match("deliverOutboundPayloads") or
     source:match("buildOutboundSessionContext") or source:match("resolveAgentOutboundIdentity") then
    table.insert(seamKinds, "cron-outbound-delivery")
  end

  if importsHeartbeat and source:match("stripHeartbeatToken") or source:match("Heartbeat") or
     source:match("heartbeat") or source:match("next%-heartbeat") then
    table.insert(seamKinds, "cron-heartbeat-handoff")
  end

  if importsSchedulerModules and source:match("ensureLoaded") or source:match("persist") or
     source:match("armTimer") or source:match("runMissedJobs") or source:match("computeJobNextRunAtMs") or
     source:match("recomputeNextRuns") or source:match("nextWakeAtMs") then
    table.insert(seamKinds, "cron-scheduler-state")
  end

  if importsOutboundDelivery and source:match("mediaUrl") or source:match("mediaUrls") or
     source:match("filename") or source:match("audioAsVoice") or source:match("deliveryPayloads") or
     source:match("deliveryPayloadHasStructuredContent") then
    table.insert(seamKinds, "cron-media-delivery")
  end

  if importsFollowup and source:match("waitForDescendantSubagentSummary") or
     source:match("readDescendantSubagentFallbackReply") or source:match("expectsSubagentFollowup") or
     source:match("callGateway") or source:match("listDescendantRunsForRequester") then
    table.insert(seamKinds, "cron-followup-handoff")
  end

  return seamKinds
end

local function describeSubagentSeamKinds(relativePath, source)
  if not isSubagentProductionPath(relativePath) then
    return {}
  end

  local seamKinds = {}
  local isAnnounceDispatchPath = relativePath == "src/agents/subagent-announce.ts" or
                                relativePath == "src/agents/subagent-announce-dispatch.ts"
  local importsSpawnRuntime = hasAnyImportSource(source, {
    "./subagent-spawn.js",
    "../subagent-spawn.js",
    "./acp-spawn.js",
    "../acp-spawn.js",
    "./subagent-registry.js",
    "../subagent-registry.js",
    "../acp/control-plane/manager.js",
  })
  local importsLifecycleRegistry = hasAnyImportSource(source, {
    "./subagent-registry-completion.js",
    "./subagent-registry-cleanup.js",
    "./subagent-registry-state.js",
    "./subagent-registry.js",
    "./subagent-lifecycle-events.js",
    "../context-engine/init.js",
    "../context-engine/registry.js",
    "../sessions/session-lifecycle-events.js",
  })
  local importsAnnounceDelivery = hasAnyImportSource(source, {
    "./subagent-announce.js",
    "./subagent-announce-dispatch.js",
    "./subagent-announce-queue.js",
    "../infra/outbound/bound-delivery-router.js",
    "../utils/delivery-context.js",
    "../gateway/call.js",
  })
  local importsCleanup = hasAnyImportSource(source, {
    "../gateway/call.js",
    "./subagent-registry-cleanup.js",
    "../acp/control-plane/spawn.js",
  })
  local importsParentStream = hasAnyImportSource(source, {
    "./acp-spawn-parent-stream.js",
    "../infra/heartbeat-wake.js",
    "../infra/system-events.js",
    "../infra/agent-events.js",
  })

  if importsSpawnRuntime and source:match("spawnSubagentDirect") or source:match("spawnAcpDirect") or
     source:match("registerSubagentRun") or source:match("getAcpSessionManager") or
     source:match("spawnSubagent") or source:match("spawnAcp") then
    table.insert(seamKinds, "subagent-session-spawn")
  end

  if importsLifecycleRegistry and source:match("emitSubagentEndedHookOnce") or
     source:match("resolveDeferredCleanupDecision") or source:match("persistSubagentRunsToDisk") or
     source:match("restoreSubagentRunsFromDisk") or source:match("resolveContextEngine") or
     source:match("emitSessionLifecycleEvent") or source:match("captureSubagentCompletionReply") then
    table.insert(seamKinds, "subagent-lifecycle-registry")
  end

  if (importsAnnounceDelivery or isAnnounceDispatchPath) and
     source:match("runSubagentAnnounceFlow") or source:match("runSubagentAnnounceDispatch") or
     source:match("enqueueAnnounce") or source:match("createBoundDeliveryRouter") or
     source:match("queueEmbeddedPiMessage") or source:match("waitForEmbeddedPiRunEnd") or
     source:match("queue%-fallback") or source:match("direct%-primary") then
    table.insert(seamKinds, "subagent-announce-delivery")
  end

  if importsCleanup and source:match("sessions%.delete") or source:match("deleteTranscript") or
     source:match("cleanupFailedAcpSpawn") or source:match("cleanupProvisionalSession") or
     source:match("cleanupFailedSpawnBeforeAgentStart") or source:match("resolveDeferredCleanupDecision") then
    table.insert(seamKinds, "subagent-session-cleanup")
  end

  if importsParentStream and source:match("startAcpSpawnParentStreamRelay") or
     source:match("requestHeartbeatNow") or source:match("enqueueSystemEvent") or
     source:match("onAgentEvent") or source:match("streamTo") then
    table.insert(seamKinds, "subagent-parent-stream")
  end

  return seamKinds
end

function describeSeamKinds(relativePath, source)
  local seamKinds = {}
  local isReplyDeliveryPath = relativePath:match("reply%-delivery") or
                              relativePath:match("reply%-dispatcher") or
                              relativePath:match("deliver%-reply") or
                              relativePath:match("reply/[a-z]+/delivery") or
                              relativePath:match("monitor/(replies|deliver|native%-command)") or
                              relativePath:match("outbound/deliver") or
                              relativePath:match("outbound/message")
  local isChannelMediaAdapterPath = (relativePath:sub(1, 10) == "extensions/" and
                                    relativePath:match("(outbound|outbound%-adapter|reply%-delivery|send|delivery|messenger|channel%.runtime?)%.ts$")) or
                                   relativePath:match("^src/channels/plugins/outbound/[^/]+%.ts$")

  if relativePath:sub(1, 16) == "src/agents/tools/" and source:find("details") and
     source:find("media") and source:find("details%s*:%s*{%s*[^}]*%bmedia%s*:") then
    table.insert(seamKinds, "tool-result-media")
  end

  if isReplyDeliveryPath and (source:find("mediaUrl") or source:find("mediaUrls") or
     source:find("resolveSendableOutboundReplyParts")) then
    table.insert(seamKinds, "reply-delivery-media")
  end

  if isChannelMediaAdapterPath and (source:find("sendMedia") or
     source:find("mediaUrl") or source:find("mediaUrls") or source:find("filename") or
     source:find("audioAsVoice")) then
    table.insert(seamKinds, "channel-media-adapter")
  end

  if isReplyDeliveryPath and (source:find("blockStreamingEnabled") or
     source:find("directlySentBlockKeys") or source:find("resolveSendableOutboundReplyParts")) and
     (source:find("mediaUrl") or source:find("mediaUrls")) then
    table.insert(seamKinds, "streaming-media-handoff")
  end

  for _, kind in ipairs(describeCronSeamKinds(relativePath, source)) do
    table.insert(seamKinds, kind)
  end

  for _, kind in ipairs(describeSubagentSeamKinds(relativePath, source)) do
    table.insert(seamKinds, kind)
  end

  -- Remove duplicates and sort
  local unique = {}
  for _, v in ipairs(seamKinds) do
    unique[v] = true
  end
  local sorted = {}
  for k in pairs(unique) do
    table.insert(sorted, k)
  end
  table.sort(sorted)
  return sorted
end

local function buildTestIndex(testFiles)
  local index = {}
  for _, filePath in ipairs(testFiles) do
    local relativePath = normalizePath(filePath)
    local stem = stemFromRelativePath(relativePath):gsub("%.test$", ""):gsub("%.spec$", "")
    local baseName = path.basename(stem)
    local source = readScannableText(filePath)
    if source then
      table.insert(index, {
        filePath = filePath,
        relativePath = relativePath,
        stem = stem,
        baseName = baseName,
        source = source
      })
    end
  end
  return index
end

local function hasExecutableImportReference(source, importPath)
  local escapedImportPath = escapeForRegExp(importPath)
  local suffix = "[^\"'\\`]*"
  local patterns = {
    "from%s*[\"']" .. escapedImportPath .. suffix .. "[\"']",
    "import%s*[\"']" .. escapedImportPath .. suffix .. "[\"']",
    "require%s*%(%s*[\"']" .. escapedImportPath .. suffix .. "[\"']%s*%)",
    "import%s*%(%s*[\"']" .. escapedImportPath .. suffix .. "[\"']%s*%)"
  }
  for _, pattern in ipairs(patterns) do
    if source:match(pattern) then
      return true
    end
  end
  return false
end

local function hasModuleMockReference(source, importPath)
  local escapedImportPath = escapeForRegExp(importPath)
  local suffix = "[^\"'\\`]*"
  local patterns = {
    "vi%.mock%s*%(%s*[\"']" .. escapedImportPath .. suffix .. "[\"']%)",
    "jest%.mock%s*%(%s*[\"']" .. escapedImportPath .. suffix .. "[\"']%)"
  }
  for _, pattern in ipairs(patterns) do
    if source:match(pattern) then
      return true
    end
  end
  return false
end

local function matchQualityRank(quality)
  local ranks = {
    ["exact-stem"] = 0,
    ["path-nearby"] = 1,
    ["direct-import"] = 2,
    ["dir-token"] = 3
  }
  return ranks[quality] or 4
end

local function findRelatedTests(relativePath, testIndex)
  local stem = stemFromRelativePath(relativePath)
  local baseName = path.basename(stem)
  local dirName = path.dirname(relativePath):gsub("\\", "/")
  local baseTokens = {}
  for _, token in ipairs(splitNameTokens(baseName)) do
    if #token >= 7 then
      baseTokens[token] = true
    end
  end

  local matches = {}
  local byFile = {}

  for _, entry in ipairs(testIndex) do
    local match = nil
    if entry.stem == stem then
      match = {file = entry.relativePath, matchQuality = "exact-stem"}
    elseif entry.stem:sub(1, #stem + 1) == stem .. "." then
      match = {file = entry.relativePath, matchQuality = "path-nearby"}
    else
      local entryDir = path.dirname(entry.relativePath):gsub("\\", "/")
      local importPath = ""
      if path.relative(entryDir, stem) == path.basename(stem) then
        importPath = "./" .. path.basename(stem)
      elseif path.relative(entryDir, stem):sub(1, 1) == "." then
        importPath = path.relative(entryDir, stem)
      else
        importPath = "./" .. path.relative(entryDir, stem)
      end
      
      if hasExecutableImportReference(entry.source, importPath) and
         not hasModuleMockReference(entry.source, importPath) then
        match = {file = entry.relativePath, matchQuality = "direct-import"}
      elseif entryDir == dirName and next(baseTokens) then
        local entryTokens = splitNameTokens(entry.baseName)
        for _, token in ipairs(entryTokens) do
          if baseTokens[token] then
            match = {file = entry.relativePath, matchQuality = "dir-token"}
            break
          end
        end
      end
    end

    if match then
      local existing = byFile[match.file]
      if not existing or matchQualityRank(match.matchQuality) < matchQualityRank(existing.matchQuality) then
        byFile[match.file] = match
      end
    end
  end

  local result = {}
  for _, match in pairs(byFile) do
    table.insert(result, match)
  end

  table.sort(result, function(left, right)
    local leftRank = matchQualityRank(left.matchQuality)
    local rightRank = matchQualityRank(right.matchQuality)
    if leftRank ~= rightRank then
      return leftRank < rightRank
    end
    return left.file < right.file
  end)

  return result
end

local function determineSeamTestStatus(seamKinds, relatedTestMatches)
  if #relatedTestMatches == 0 then
    return {
      status = "gap",
      reason = "No nearby test file references this seam candidate."
    }
  end

  local bestMatch = relatedTestMatches[1].matchQuality or "unknown"
  local highSignalKinds = {
    "reply-delivery-media",
    "streaming-media-handoff",
    "tool-result-media",
    "cron-agent-handoff",
    "cron-outbound-delivery",
    "cron-heartbeat-handoff",
    "cron-scheduler-state",
    "cron-media-delivery",
    "cron-followup-handoff",
    "subagent-session-spawn",
    "subagent-lifecycle-registry",
    "subagent-announce-delivery",
    "subagent-session-cleanup",
    "subagent-parent-stream"
  }

  for _, kind in ipairs(highSignalKinds) do
    for _, seamKind in ipairs(seamKinds) do
      if seamKind == kind then
        return {
          status = "partial",
          reason = "Nearby tests exist (best match: " .. bestMatch .. "), but this inventory does not prove cross-layer seam coverage end to end."
        }
      end
    end
  end

  return {
    status = "heuristic-nearby",
    reason = "Nearby tests exist (best match: " .. bestMatch .. "), but this remains a filename/path heuristic rather than proof of seam assertions."
  }
end

local function buildSeamTestInventory()
  local productionFiles = {}
  for _, file in ipairs(walkCodeFiles(srcRoot)) do
    table.insert(productionFiles, file)
  end
  for _, file in ipairs(walkCodeFiles(extensionsRoot)) do
    table.insert(productionFiles, file)
  end
  table.sort(productionFiles, function(a, b)
    return normalizePath(a) < normalizePath(b)
  end)

  local testFiles = {}
  for _, file in ipairs(walkCodeFiles(srcRoot, true)) do
    if file:match("%.(test|spec)%.[^.]+$") then
      table.insert(testFiles, file)
    end
  end
  for _, file in ipairs(walkCodeFiles(extensionsRoot, true)) do
    if file:match("%.(test|spec)%.[^.]+$") then
      table.insert(testFiles, file)
    end
  end
  for _, file in ipairs(walkCodeFiles(testRoot, true)) do
    if file:match("%.(test|spec)%.[^.]+$") then
      table.insert(testFiles, file)
    end
  end
  table.sort(testFiles, function(a, b)
    return normalizePath(a) < normalizePath(b)
  end)

  local testIndex = buildTestIndex(testFiles)
  local inventory = {}

  for _, filePath in ipairs(productionFiles) do
    local relativePath = normalizePath(filePath)
    local source = readScannableText(filePath)
    if source then
      local seamKinds = describeSeamKinds(relativePath, source)
      if #seamKinds > 0 then
        local relatedTestMatches = findRelatedTests(relativePath, testIndex)
        local status = determineSeamTestStatus(seamKinds, relatedTestMatches)
        table.insert(inventory, {
          file = relativePath,
          seamKinds = seamKinds,
          relatedTests = (function()
            local files = {}
            for _, entry in ipairs(relatedTestMatches) do
              table.insert(files, entry.file)
            end
            return files
          end)(),
          relatedTestMatches = relatedTestMatches,
          status = status.status,
          reason = status.reason
        })
      end
    end
  end

  table.sort(inventory, function(left, right)
    if left.status ~= right.status then
      return left.status < right.status
    end
    if left.file ~= right.file then
      return left.file < right.file
    end
    return table.concat(left.seamKinds, ",") < table.concat(right.seamKinds, ",")
  end)

  return inventory
end

local function collectWorkspacePackagePaths()
  local entries = {}
  for file in lfs.dir(extensionsRoot) do
    if file ~= "." and file ~= ".." then
      local fullPath = path.join(extensionsRoot, file)
      local attr = lfs.attributes(fullPath)
      if attr and attr.mode == "directory" then
        table.insert(workspacePackagePaths, path.join("extensions", file, "package.json"))
      end
    end
  end
end

local function buildMissingPackages(staticLeakClusters)
  staticLeakClusters = staticLeakClusters or {}
  local rootPackagePath = path.join(repoRoot, "package.json")
  local rootPackageFile = io.open(rootPackagePath, "r")
  if not rootPackageFile then return {} end
  
  local rootPackageContent = rootPackageFile:read("*a")
  rootPackageFile:close()
  local rootPackage = json.decode(rootPackageContent)
  
  local rootDeps = {}
  if rootPackage.dependencies then
    for dep in pairs(rootPackage.dependencies) do
      rootDeps[dep] = true
    end
  end
  if rootPackage.optionalDependencies then
    for dep in pairs(rootPackage.optionalDependencies) do
      rootDeps[dep] = true
    end
  end
  if rootPackage.devDependencies then
    for dep in pairs(rootPackage.devDependencies) do
      rootDeps[dep] = true
    end
  end

  local output = {}
  table.sort(workspacePackagePaths, function(a, b) return a < b end)

  for _, relativePackagePath in ipairs(workspacePackagePaths) do
    local packagePath = path.join(repoRoot, relativePackagePath)
    local packageFile = io.open(packagePath, "r")
    if packageFile then
      local packageContent = packageFile:read("*a")
      packageFile:close()
      local pkg = json.decode(packageContent)
      
      if pkg.dependencies then
        local missing = {}
        for dep in pairs(pkg.dependencies) do
          if dep ~= "openclaw" and not rootDeps[dep] then
            table.insert(missing, dep)
          end
        end
        table.sort(missing)
        
        if #missing > 0 then
          local cluster = "ui"
          if relativePackagePath ~= "ui/package.json" then
            cluster = relativePackagePath:match("^[^/]+/([^/]+)/")
          end
          
          local packageName = pkg.name
          if not packageName and relativePackagePath == "ui/package.json" then
            packageName = "openclaw-control-ui"
          end
          
          local private = pkg.private == true
          
          local decision = "required"
          local reason = "Cluster is statically visible to repo-wide check/build and has not been classified optional."
          
          if staticLeakClusters[cluster] then
            decision = "required"
            reason = "Cluster already appears in the static graph in this audit run, so treating it as optional would be misleading."
          elseif cluster == "ui" then
            decision = "optional"
            reason = "Private UI workspace. Repo-wide CLI/plugin CI should not require UI-only packages."
          end
          
          table.insert(output, {
            cluster = cluster,
            decision = decision,
            decisionReason = reason,
            packageName = packageName,
            packagePath = relativePackagePath,
            private = private,
            missing = missing
          })
        end
      end
    end
  end

  table.sort(output, function(left, right)
    if #left.missing ~= #right.missing then
      return #right.missing < #left.missing
    end
    return left.cluster < right.cluster
  end)

  return output
end

local function main(argv)
  argv = argv or arg
  local args = {}
  for _, v in ipairs(argv) do
    args[v] = true
  end
  
  if args["--help"] or args["-h"] then
    print([[Usage: node scripts/audit-seams.mjs [--help]

Audit repo seam inventory and emit JSON to stdout.

Sections:
  duplicatedSeamFamilies       Plugin SDK seam families imported from multiple production files
  overlapFiles                 Production files that touch multiple seam families
  optionalClusterStaticLeaks   Optional extension/plugin clusters referenced from the static graph
  missingPackages              Workspace packages whose deps are not mirrored at the root
  seamTestInventory            High-signal seam candidates with nearby-test gap signals,
                               including cron orchestration seams for agent handoff,
                               outbound/media delivery, heartbeat/followup handoff,
                               and scheduler state crossings, plus subagent seams
                               for spawn/session handoff, announce delivery,
                               lifecycle registry, cleanup, and parent streaming

Notes:
  - Output is JSON only.
  - For clean redirected JSON through package scripts, prefer:
      pnpm --silent audit:seams > seam-inventory.json
]])
    return
  end

  collectWorkspacePackagePaths()
  local seamTestInventory = buildSeamTestInventory()
  local missingPackages = buildMissingPackages()
  
  local result = {
    seamTestInventory = seamTestInventory,
    missingPackages = missingPackages
  }
  
  print(json.encode(result, {indent = true}))
end

-- Run main if this script is executed directly
if arg and arg[0] and arg[0]:match("audit%-seams%.lua$") then
  main()
end
