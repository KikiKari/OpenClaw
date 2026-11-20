#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "36073f8aba2e384def52ff43d59d647eadc9104a81ecf81edb2dc03697a1c393", "source_sha256": "c28e85cfc52b92ed64eb8e20b072fd218cfe0e1ab0787781c1a9abd3355c3514", "target_language": "lua"}
-- extension-test-plan.mjs — portiert nach lua
-- Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/extension-test-plan.mjs
-- Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

local fs = require("lfs")
local path_lib = require("path")

-- Helper functions to mimic Node.js path behavior
local function path_resolve(...)
    local args = {...}
    local resolved = table.concat(args, "/")
    return path_lib.normalize(resolved)
end

local function path_join(...)
    local args = {...}
    return table.concat(args, "/")
end

local function path_basename(p)
    return p:match("([^/]+)$")
end

local function path_dirname(p)
    return p:match("(.-)/[^/]*$")
end

local function path_relative(from, to)
    -- Simplified relative path calculation
    local from_parts = {}
    for part in from:gmatch("[^/]+") do
        table.insert(from_parts, part)
    end
    
    local to_parts = {}
    for part in to:gmatch("[^/]+") do
        table.insert(to_parts, part)
    end
    
    local common_length = 0
    for i = 1, math.min(#from_parts, #to_parts) do
        if from_parts[i] == to_parts[i] then
            common_length = i
        else
            break
        end
    end
    
    local result = {}
    for i = common_length + 1, #from_parts do
        table.insert(result, "..")
    end
    
    for i = common_length + 1, #to_parts do
        table.insert(result, to_parts[i])
    end
    
    return table.concat(result, "/")
end

-- Constants (mocked values since we don't have access to the original files)
local repoRoot = path_resolve(debug.getinfo(1).source:match("@(.*)"), "..", "..")
local DEFAULT_EXTENSION_TEST_SHARD_COUNT = 6

local BUNDLED_PLUGIN_PATH_PREFIX = "packages/plugins"
local BUNDLED_PLUGIN_ROOT_DIR = "packages/plugins"

-- Mocked imports (these would need actual implementation based on your project structure)
local channelTestRoots = {} -- This should be populated from vitest.channel-paths.mjs
local function isAcpxExtensionRoot(_) return false end
local function isBlueBubblesExtensionRoot(_) return false end
local function isDiffsExtensionRoot(_) return false end
local function isFeishuExtensionRoot(_) return false end
local function isIrcExtensionRoot(_) return false end
local function isMatrixExtensionRoot(_) return false end
local function isMattermostExtensionRoot(_) return false end
local function isMemoryExtensionRoot(_) return false end
local function isMessagingExtensionRoot(_) return false end
local function isMsTeamsExtensionRoot(_) return false end
local function isProviderExtensionRoot(_) return false end
local function isTelegramExtensionRoot(_) return false end
local function isVoiceCallExtensionRoot(_) return false end
local function isWhatsAppExtensionRoot(_) return false end
local function isZaloExtensionRoot(_) return false end

-- Mocked changed-extensions functionality
local function listAvailableExtensionIds()
    -- This should return a list of available extension IDs
    return {}
end

local function normalizeRelative(inputPath)
    return inputPath:gsub("\\", "/")
end

local function file_exists(path)
    local attr = lfs.attributes(path)
    return attr and attr.mode == "file"
end

local function dir_exists(path)
    local attr = lfs.attributes(path)
    return attr and attr.mode == "directory"
end

local function countTestFiles(rootPath)
    local total = 0
    local stack = {rootPath}
    
    while #stack > 0 do
        local current = table.remove(stack)
        if not current or not dir_exists(current) then
            goto continue
        end
        
        for entry in lfs.dir(current) do
            if entry ~= "." and entry ~= ".." then
                local fullPath = path_join(current, entry)
                local attr = lfs.attributes(fullPath)
                
                if attr and attr.mode == "directory" then
                    if entry ~= "node_modules" and entry ~= "dist" then
                        table.insert(stack, fullPath)
                    end
                elseif attr and attr.mode == "file" then
                    if fullPath:match("%.test%.ts$") or fullPath:match("%.test%.tsx$") then
                        total = total + 1
                    end
                end
            end
        end
        
        ::continue::
    end
    
    return total
end

local function resolveExtensionDirectory(targetArg, cwd)
    cwd = cwd or lfs.currentdir()
    
    if targetArg then
        local asGiven = path_resolve(cwd, targetArg)
        if file_exists(path_join(asGiven, "package.json")) then
            return asGiven
        end
        
        local byName = path_join(repoRoot, BUNDLED_PLUGIN_ROOT_DIR, targetArg)
        if file_exists(path_join(byName, "package.json")) then
            return byName
        end
        
        error(string.format('Unknown extension target "%s". Use a plugin name like "slack" or a path inside the bundled plugin workspace tree.', targetArg))
    end
    
    local current = cwd
    while true do
        local relativePath = normalizeRelative(path_relative(repoRoot, current))
        if relativePath:find(BUNDLED_PLUGIN_PATH_PREFIX, 1, true) == 1 and file_exists(path_join(current, "package.json")) then
            return current
        end
        
        local parent = path_dirname(current)
        if not parent or parent == current then
            break
        end
        current = parent
    end
    
    error("No extension target provided, and current working directory is not inside the bundled plugin workspace tree.")
end

function resolveExtensionTestPlan(params)
    params = params or {}
    local cwd = params.cwd or lfs.currentdir()
    local targetArg = params.targetArg
    local extensionDir = resolveExtensionDirectory(targetArg, cwd)
    local extensionId = path_basename(extensionDir)
    local relativeExtensionDir = normalizeRelative(path_relative(repoRoot, extensionDir))
    
    local roots = {relativeExtensionDir}
    
    local usesChannelConfig = false
    for _, root in ipairs(roots) do
        for _, channelRoot in ipairs(channelTestRoots) do
            if root == channelRoot then
                usesChannelConfig = true
                break
            end
        end
    end
    
    local usesAcpxConfig = false
    for _, root in ipairs(roots) do
        if isAcpxExtensionRoot(root) then
            usesAcpxConfig = true
            break
        end
    end
    
    local usesDiffsConfig = false
    for _, root in ipairs(roots) do
        if isDiffsExtensionRoot(root) then
            usesDiffsConfig = true
            break
        end
    end
    
    local usesBlueBubblesConfig = false
    for _, root in ipairs(roots) do
        if isBlueBubblesExtensionRoot(root) then
            usesBlueBubblesConfig = true
            break
        end
    end
    
    local usesFeishuConfig = false
    for _, root in ipairs(roots) do
        if isFeishuExtensionRoot(root) then
            usesFeishuConfig = true
            break
        end
    end
    
    local usesIrcConfig = false
    for _, root in ipairs(roots) do
        if isIrcExtensionRoot(root) then
            usesIrcConfig = true
            break
        end
    end
    
    local usesMattermostConfig = false
    for _, root in ipairs(roots) do
        if isMattermostExtensionRoot(root) then
            usesMattermostConfig = true
            break
        end
    end
    
    local usesTelegramConfig = false
    for _, root in ipairs(roots) do
        if isTelegramExtensionRoot(root) then
            usesTelegramConfig = true
            break
        end
    end
    
    local usesVoiceCallConfig = false
    for _, root in ipairs(roots) do
        if isVoiceCallExtensionRoot(root) then
            usesVoiceCallConfig = true
            break
        end
    end
    
    local usesWhatsAppConfig = false
    for _, root in ipairs(roots) do
        if isWhatsAppExtensionRoot(root) then
            usesWhatsAppConfig = true
            break
        end
    end
    
    local usesZaloConfig = false
    for _, root in ipairs(roots) do
        if isZaloExtensionRoot(root) then
            usesZaloConfig = true
            break
        end
    end
    
    local usesMatrixConfig = false
    for _, root in ipairs(roots) do
        if isMatrixExtensionRoot(root) then
            usesMatrixConfig = true
            break
        end
    end
    
    local usesMemoryConfig = false
    for _, root in ipairs(roots) do
        if isMemoryExtensionRoot(root) then
            usesMemoryConfig = true
            break
        end
    end
    
    local usesMsTeamsConfig = false
    for _, root in ipairs(roots) do
        if isMsTeamsExtensionRoot(root) then
            usesMsTeamsConfig = true
            break
        end
    end
    
    local usesMessagingConfig = false
    for _, root in ipairs(roots) do
        if isMessagingExtensionRoot(root) then
            usesMessagingConfig = true
            break
        end
    end
    
    local usesProviderConfig = false
    for _, root in ipairs(roots) do
        if isProviderExtensionRoot(root) then
            usesProviderConfig = true
            break
        end
    end
    
    local config = "test/vitest/vitest.extensions.config.ts"
    if usesChannelConfig then
        config = "test/vitest/vitest.extension-channels.config.ts"
    elseif usesAcpxConfig then
        config = "test/vitest/vitest.extension-acpx.config.ts"
    elseif usesDiffsConfig then
        config = "test/vitest/vitest.extension-diffs.config.ts"
    elseif usesBlueBubblesConfig then
        config = "test/vitest/vitest.extension-bluebubbles.config.ts"
    elseif usesFeishuConfig then
        config = "test/vitest/vitest.extension-feishu.config.ts"
    elseif usesIrcConfig then
        config = "test/vitest/vitest.extension-irc.config.ts"
    elseif usesMattermostConfig then
        config = "test/vitest/vitest.extension-mattermost.config.ts"
    elseif usesMatrixConfig then
        config = "test/vitest/vitest.extension-matrix.config.ts"
    elseif usesTelegramConfig then
        config = "test/vitest/vitest.extension-telegram.config.ts"
    elseif usesVoiceCallConfig then
        config = "test/vitest/vitest.extension-voice-call.config.ts"
    elseif usesWhatsAppConfig then
        config = "test/vitest/vitest.extension-whatsapp.config.ts"
    elseif usesZaloConfig then
        config = "test/vitest/vitest.extension-zalo.config.ts"
    elseif usesMemoryConfig then
        config = "test/vitest/vitest.extension-memory.config.ts"
    elseif usesMsTeamsConfig then
        config = "test/vitest/vitest.extension-msteams.config.ts"
    elseif usesMessagingConfig then
        config = "test/vitest/vitest.extension-messaging.config.ts"
    elseif usesProviderConfig then
        config = "test/vitest/vitest.extension-providers.config.ts"
    end
    
    local testFileCount = 0
    for _, root in ipairs(roots) do
        testFileCount = testFileCount + countTestFiles(path_join(repoRoot, root))
    end
    
    return {
        config = config,
        extensionDir = relativeExtensionDir,
        extensionId = extensionId,
        hasTests = testFileCount > 0,
        roots = roots,
        testFileCount = testFileCount
    }
end

local function mergeTestPlans(plans)
    local groupsByConfig = {}
    
    for _, plan in ipairs(plans) do
        local current = groupsByConfig[plan.config]
        if not current then
            current = {
                config = plan.config,
                extensionIds = {},
                roots = {},
                testFileCount = 0
            }
            groupsByConfig[plan.config] = current
        end
        
        table.insert(current.extensionIds, plan.extensionId)
        
        for _, root in ipairs(plan.roots) do
            table.insert(current.roots, root)
        end
        
        current.testFileCount = current.testFileCount + plan.testFileCount
    end
    
    local planGroups = {}
    for _, group in pairs(groupsByConfig) do
        -- Sort extensionIds
        table.sort(group.extensionIds)
        
        -- Remove duplicate roots
        local uniqueRoots = {}
        local rootsSet = {}
        for _, root in ipairs(group.roots) do
            if not rootsSet[root] then
                rootsSet[root] = true
                table.insert(uniqueRoots, root)
            end
        end
        group.roots = uniqueRoots
        
        table.insert(planGroups, group)
    end
    
    -- Sort planGroups by config
    table.sort(planGroups, function(a, b)
        return a.config < b.config
    end)
    
    -- Sort extensionIds from all plans
    local allExtensionIds = {}
    for _, plan in ipairs(plans) do
        table.insert(allExtensionIds, plan.extensionId)
    end
    table.sort(allExtensionIds)
    
    -- Calculate total testFileCount
    local totalTestFileCount = 0
    for _, plan in ipairs(plans) do
        totalTestFileCount = totalTestFileCount + plan.testFileCount
    end
    
    return {
        extensionCount = #plans,
        extensionIds = allExtensionIds,
        hasTests = #plans > 0,
        planGroups = planGroups,
        testFileCount = totalTestFileCount
    }
end

function resolveExtensionBatchPlan(params)
    params = params or {}
    local cwd = params.cwd or lfs.currentdir()
    local extensionIds = params.extensionIds or listAvailableExtensionIds()
    
    local plans = {}
    for _, extensionId in ipairs(extensionIds) do
        local plan = resolveExtensionTestPlan({cwd = cwd, targetArg = extensionId})
        if plan.hasTests then
            table.insert(plans, plan)
        end
    end
    
    return mergeTestPlans(plans)
end

local function pickLeastLoadedShard(shards)
    local bestIndex = -1
    
    for index, shard in ipairs(shards) do
        if bestIndex == -1 then
            bestIndex = index
        else
            local best = shards[bestIndex]
            if shard.testFileCount ~= best.testFileCount then
                if shard.testFileCount < best.testFileCount then
                    bestIndex = index
                end
            elseif shard.plans and best.plans and #shard.plans ~= #best.plans then
                if #shard.plans < #best.plans then
                    bestIndex = index
                end
            else
                if index < bestIndex then
                    bestIndex = index
                end
            end
        end
    end
    
    return bestIndex
end

function createExtensionTestShards(params)
    params = params or {}
    local cwd = params.cwd or lfs.currentdir()
    local extensionIds = params.extensionIds or listAvailableExtensionIds()
    local shardCount = math.max(1, tonumber(params.shardCount) or 1)
    
    local plans = {}
    for _, extensionId in ipairs(extensionIds) do
        local plan = resolveExtensionTestPlan({cwd = cwd, targetArg = extensionId})
        if plan.hasTests then
            table.insert(plans, plan)
        end
    end
    
    -- Sort plans
    table.sort(plans, function(left, right)
        if left.testFileCount ~= right.testFileCount then
            return right.testFileCount - left.testFileCount
        end
        return left.extensionId < right.extensionId
    end)
    
    local effectiveShardCount = math.min(shardCount, math.max(1, #plans))
    local shards = {}
    for i = 1, effectiveShardCount do
        shards[i] = {
            plans = {},
            testFileCount = 0
        }
    end
    
    for _, plan in ipairs(plans) do
        local targetIndex = pickLeastLoadedShard(shards)
        table.insert(shards[targetIndex].plans, plan)
        shards[targetIndex].testFileCount = shards[targetIndex].testFileCount + plan.testFileCount
    end
    
    local result = {}
    for index, shard in ipairs(shards) do
        local merged = mergeTestPlans(shard.plans)
        if merged.hasTests then
            table.insert(result, {
                index = index,
                checkName = string.format("checks-node-extensions-shard-%d", index + 1),
                extensionCount = merged.extensionCount,
                extensionIds = merged.extensionIds,
                hasTests = merged.hasTests,
                planGroups = merged.planGroups,
                testFileCount = merged.testFileCount
            })
        end
    end
    
    return result
end

-- Export functions
return {
    DEFAULT_EXTENSION_TEST_SHARD_COUNT = DEFAULT_EXTENSION_TEST_SHARD_COUNT,
    resolveExtensionTestPlan = resolveExtensionTestPlan,
    resolveExtensionBatchPlan = resolveExtensionBatchPlan,
    createExtensionTestShards = createExtensionTestShards
}
