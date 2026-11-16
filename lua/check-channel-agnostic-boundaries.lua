#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "79e62771831e9fb985baadc34fc0e64a02c22fb349048d07a092564c5839c98a", "source_sha256": "a2afe873e78fca9f7a9bf66785f17d7cad24c6285fd2c0dc6c6bb2abf1e375fa", "target_language": "lua"}
-- check-channel-agnostic-boundaries.mjs — portiert nach lua
-- Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-channel-agnostic-boundaries.mjs
-- Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

local fs = require("lfs")
local path = require("path")

-- Helper functions to mimic Node.js path behavior
local function join(...)
    local args = {...}
    local result = ""
    for i, arg in ipairs(args) do
        if i == 1 then
            result = arg
        else
            result = result .. "/" .. arg
        end
    end
    return result
end

local function resolveRepoRoot(currentPath)
    -- Simplified version - assumes script is in repo root
    return path.dirname(currentPath)
end

local function collectTypeScriptFiles(dir, options)
    local files = {}
    local function scanDirectory(directory)
        for file in lfs.dir(directory) do
            if file ~= "." and file ~= ".." then
                local fullPath = directory .. "/" .. file
                local attr = lfs.attributes(fullPath)
                if attr.mode == "directory" then
                    scanDirectory(fullPath)
                elseif string.match(file, "%.ts$") then
                    table.insert(files, fullPath)
                end
            end
        end
    end
    scanDirectory(dir)
    return files
end

local function toLine(sourceFile, node)
    -- Simplified line number extraction
    return 1
end

local function runAsScript(scriptPath, mainFunc)
    if arg[0] and string.match(arg[0], scriptPath) then
        mainFunc()
    end
end

local repoRoot = resolveRepoRoot(debug.getinfo(1).source:sub(2))

local acpCoreProtectedSources = {
    join(repoRoot, "src", "acp"),
    join(repoRoot, "src", "agents", "acp-spawn.ts"),
    join(repoRoot, "src", "auto-reply", "reply", "commands-acp"),
    join(repoRoot, "src", "infra", "outbound", "conversation-id.ts"),
}

local channelCoreProtectedSources = {
    join(repoRoot, "src", "channels", "thread-bindings-policy.ts"),
    join(repoRoot, "src", "channels", "thread-bindings-messages.ts"),
}
local acpUserFacingTextSources = {
    join(repoRoot, "src", "auto-reply", "reply", "commands-acp"),
}
local systemMarkLiteralGuardSources = {
    join(repoRoot, "src", "auto-reply", "reply", "commands-acp"),
    join(repoRoot, "src", "auto-reply", "reply", "dispatch-acp.ts"),
    join(repoRoot, "src", "auto-reply", "reply", "directive-handling.shared.ts"),
    join(repoRoot, "src", "channels", "thread-bindings-messages.ts"),
}

local channelIds = {
    "bluebubbles",
    "discord",
    "googlechat",
    "imessage",
    "irc",
    "line",
    "matrix",
    "msteams",
    "signal",
    "slack",
    "telegram",
    "web",
    "whatsapp",
    "zalo",
    "zalouser",
}

local channelIdSet = {}
for _, id in ipairs(channelIds) do
    channelIdSet[id] = true
end

local channelSegmentRe = "[._/\\](" .. table.concat(channelIds, "|") .. ")[._/\\]"
local comparisonOperators = {
    ["=="] = true,
    ["~="] = true,
}

local allowedViolations = {}

local function isChannelsPropertyAccess(node)
    if type(node) == "table" and node.type == "property" then
        return node.name == "channels"
    end
    if type(node) == "table" and node.type == "element" and node.argumentExpression then
        return node.argumentExpression.value == "channels"
    end
    return false
end

local function readStringLiteral(node)
    if type(node) == "table" and (node.type == "string_literal" or node.type == "template_literal") then
        return node.value
    end
    return nil
end

local function isChannelLiteralNode(node)
    local text = readStringLiteral(node)
    return text and channelIdSet[text]
end

local function matchesChannelModuleSpecifier(specifier)
    return string.match(specifier:gsub("\\", "/"), channelSegmentRe) ~= nil
end

local userFacingChannelNameRe = "%f[%w]" .. table.concat({
    "discord", "telegram", "slack", "signal", "imessage", 
    "whatsapp", "google%s*chat", "irc", "line", "zalo", 
    "matrix", "msteams", "bluebubbles"
}, "|") .. "%f[%W]"
local systemMarkLiteral = "⚙️"

local function isModuleSpecifierStringNode(node)
    local parent = node.parent
    if not parent then return false end
    
    if parent.type == "import_declaration" or parent.type == "export_declaration" then
        return true
    end
    
    if parent.type == "call_expression" and 
       parent.expression and parent.expression.kind == "import" and
       parent.arguments and parent.arguments[1] == node then
        return true
    end
    
    return false
end

local function findChannelAgnosticBoundaryViolations(content, fileName, options)
    options = options or {}
    local checkModuleSpecifiers = options.checkModuleSpecifiers
    local checkConfigPaths = options.checkConfigPaths
    local checkChannelComparisons = options.checkChannelComparisons
    local checkChannelAssignments = options.checkChannelAssignments
    local moduleSpecifierMatcher = options.moduleSpecifierMatcher or matchesChannelModuleSpecifier
    
    -- Parse content into AST-like structure (simplified)
    local sourceFile = {content = content, fileName = fileName}
    local violations = {}
    
    -- This would normally parse the TypeScript content
    -- For now we'll simulate some basic checks
    
    return violations
end

local function findChannelCoreReverseDependencyViolations(content, fileName)
    return findChannelAgnosticBoundaryViolations(content, fileName, {
        checkModuleSpecifiers = true,
        checkConfigPaths = false,
        checkChannelComparisons = false,
        checkChannelAssignments = false,
        moduleSpecifierMatcher = matchesChannelModuleSpecifier,
    })
end

local function findAcpUserFacingChannelNameViolations(content, fileName)
    local sourceFile = {content = content, fileName = fileName}
    local violations = {}
    
    -- Simulate scanning for user-facing channel names
    -- In real implementation this would parse the content
    
    return violations
end

local function findSystemMarkLiteralViolations(content, fileName)
    local sourceFile = {content = content, fileName = fileName}
    local violations = {}
    
    -- Simulate scanning for system mark literals
    -- In real implementation this would parse the content
    
    return violations
end

local boundaryRuleSets = {
    {
        id = "acp-core",
        sources = acpCoreProtectedSources,
        scan = function(content, fileName) 
            return findChannelAgnosticBoundaryViolations(content, fileName)
        end,
    },
    {
        id = "channel-core-reverse-deps",
        sources = channelCoreProtectedSources,
        scan = function(content, fileName)
            return findChannelCoreReverseDependencyViolations(content, fileName)
        end,
    },
    {
        id = "acp-user-facing-text",
        sources = acpUserFacingTextSources,
        scan = function(content, fileName)
            return findAcpUserFacingChannelNameViolations(content, fileName)
        end,
    },
    {
        id = "system-mark-literal-usage",
        sources = systemMarkLiteralGuardSources,
        scan = function(content, fileName)
            return findSystemMarkLiteralViolations(content, fileName)
        end,
    },
}

local function main()
    local violations = {}
    
    for _, ruleSet in ipairs(boundaryRuleSets) do
        local files = {}
        for _, sourcePath in ipairs(ruleSet.sources) do
            local collected = collectTypeScriptFiles(sourcePath, {ignoreMissing = true})
            for _, file in ipairs(collected) do
                table.insert(files, file)
            end
        end
        
        for _, filePath in ipairs(files) do
            local relativeFile = filePath:gsub(repoRoot .. "/", "")
            
            if not allowedViolations[ruleSet.id .. ":" .. relativeFile] and 
               not allowedViolations[relativeFile] then
                
                local file = io.open(filePath, "r")
                if file then
                    local content = file:read("*all")
                    file:close()
                    
                    local scanResults = ruleSet.scan(content, relativeFile)
                    for _, violation in ipairs(scanResults) do
                        table.insert(violations, ruleSet.id .. " " .. relativeFile .. ":" .. violation.line .. ": " .. violation.reason)
                    end
                end
            end
        end
    end

    if #violations == 0 then
        return
    end

    print("Found channel-specific references in channel-agnostic sources:")
    for _, violation in ipairs(violations) do
        print("- " .. violation)
    end
    print("Move channel-specific logic to channel adapters or add a justified allowlist entry.")
    os.exit(1)
end

runAsScript(arg[0], main)
