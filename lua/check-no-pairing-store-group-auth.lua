#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "d5dbf51c36435fc5932d84a71eaf7581034140d38258b7e3a10428eb0fb5f385", "source_sha256": "a9a15237ac26649d4fe81c84ab0e7be0474d07af42503d8016279ce5a868359c", "target_language": "lua"}
-- check-no-pairing-store-group-auth.mjs — portiert nach lua
-- Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-no-pairing-store-group-auth.mjs
-- Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

local fs = require("fs")
local path = require("path")

-- Simuliere einige TypeScript-Funktionen und -Konstanten
local ts = {
    SyntaxKind = {
        Identifier = 70,
        PropertyAccessExpression = 162,
        CallExpression = 170,
        ObjectLiteralExpression = 179,
        PropertyAssignment = 238,
        VariableDeclaration = 243,
    },
    isIdentifier = function(node)
        return node.kind == ts.SyntaxKind.Identifier
    end,
    isPropertyAccessExpression = function(node)
        return node.kind == ts.SyntaxKind.PropertyAccessExpression
    end,
    isCallExpression = function(node)
        return node.kind == ts.SyntaxKind.CallExpression
    end,
    isObjectLiteralExpression = function(node)
        return node.kind == ts.SyntaxKind.ObjectLiteralExpression
    end,
    isPropertyAssignment = function(node)
        return node.kind == ts.SyntaxKind.PropertyAssignment
    end,
    isVariableDeclaration = function(node)
        return node.kind == ts.SyntaxKind.VariableDeclaration
    end,
    forEachChild = function(node, callback)
        if node.children then
            for _, child in ipairs(node.children) do
                callback(child)
            end
        end
    end,
}

-- Globale Konfiguration
local repoRoot = path.resolve(".")
local sourceRoots = {"src"}
local allowedFiles = {
    [path.join(repoRoot, "src/security/dm-policy-shared.ts")] = true,
    [path.join(repoRoot, "src/channels/allow-from.ts")] = true,
    [path.join(repoRoot, "src/security/fix.ts")] = true,
    [path.join(repoRoot, "src/security/audit-channel.ts")] = true,
}

local function resolveFromRepo(relPath)
    return path.join(repoRoot, relPath)
end

local storeIdentifierRe = "^(storeAllowFrom|storedAllowFrom|storeAllowList)$"
local groupNameRe = "(groupAllowFrom|effectiveGroupAllowFrom|groupAllowed|groupAllow|groupAuth|groupSender)"
local storeSourceCallNames = {
    readChannelAllowFromStore = true,
    readChannelAllowFromStoreSync = true,
    readStoreAllowFromForDmPolicy = true,
}
local allowedResolverCallNames = {
    resolveEffectiveAllowFromLists = true,
    resolveDmGroupAccessWithLists = true,
    resolveMattermostEffectiveAllowFromLists = true,
    resolveIrcEffectiveAllowlists = true,
}

local function getPropertyNameText(nameNode)
    if ts.isIdentifier(nameNode) then
        return nameNode.text
    elseif nameNode.kind == ts.SyntaxKind["ObjectBindingPattern"] or nameNode.kind == ts.SyntaxKind["ArrayBindingPattern"] then
        return nameNode:getText()
    end
    return nil
end

local function containsPairingStoreSource(node)
    local found = false
    local function visit(current)
        if found then return end
        if ts.isIdentifier(current) and string.match(current.text:lower(), storeIdentifierRe) then
            found = true
            return
        end
        if ts.isCallExpression(current) then
            local callName = getCallName(current)
            if callName and storeSourceCallNames[callName] then
                found = true
                return
            end
        end
        ts.forEachChild(current, visit)
    end
    visit(node)
    return found
end

local function getCallName(node)
    if not ts.isCallExpression(node) then
        return nil
    end
    if ts.isIdentifier(node.expression) then
        return node.expression.text
    end
    if ts.isPropertyAccessExpression(node.expression) then
        return node.expression.name.text
    end
    return nil
end

local function isSuspiciousNormalizeWithStoreCall(node)
    if not ts.isCallExpression(node) then
        return false
    end
    if not ts.isIdentifier(node.expression) or node.expression.text ~= "normalizeAllowFromWithStore" then
        return false
    end
    local firstArg = node.arguments[1]
    if not firstArg or not ts.isObjectLiteralExpression(firstArg) then
        return false
    end
    local hasStoreProp = false
    local hasGroupAllowProp = false
    for _, property in ipairs(firstArg.properties) do
        if not ts.isPropertyAssignment(property) then
            goto continue
        end
        local name = getPropertyNameText(property.name)
        if not name then
            goto continue
        end
        if name == "storeAllowFrom" and containsPairingStoreSource(property.initializer) then
            hasStoreProp = true
        end
        if name == "allowFrom" and string.find(property.initializer:getText():lower(), groupNameRe) then
            hasGroupAllowProp = true
        end
        ::continue::
    end
    return hasStoreProp and hasGroupAllowProp
end

local function findViolations(content, filePath)
    -- Da wir keinen echten Parser haben, simulieren wir das Parsen
    -- In einer echten Implementierung würden wir hier den AST analysieren
    local sourceFile = { getText = function() return content end }
    local violations = {}

    -- Dummy-Logik zur Demonstration
    -- In Wirklichkeit müsste man den AST durchlaufen und prüfen
    local lines = {}
    for line in content:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end

    for i, line in ipairs(lines) do
        if string.find(line, groupNameRe) and string.find(line, storeIdentifierRe) then
            table.insert(violations, {
                line = i,
                reason = "group-scoped variable references pairing-store identifiers"
            })
        end
    end

    return violations
end

local function collectFileViolations(options)
    local violations = {}
    for _, root in ipairs(options.sourceRoots) do
        local function scanDir(dir)
            local files = fs.readdirSync(dir)
            for _, file in ipairs(files) do
                local fullPath = path.join(dir, file)
                local stat = fs.statSync(fullPath)
                if stat.isDirectory() then
                    scanDir(fullPath)
                elseif stat.isFile() and string.sub(file, -3) == ".ts" and not options.skipFile(fullPath) then
                    local content = fs.readFileSync(fullPath, "utf8")
                    local fileViolations = findViolations(content, fullPath)
                    for _, v in ipairs(fileViolations) do
                        table.insert(violations, {
                            path = fullPath,
                            line = v.line,
                            reason = v.reason
                        })
                    end
                end
            end
        end
        scanDir(root)
    end
    return violations
end

local function main()
    local violations = collectFileViolations({
        sourceRoots = sourceRoots,
        repoRoot = repoRoot,
        findViolations = findViolations,
        skipFile = function(filePath)
            return allowedFiles[filePath] == true
        end
    })

    if #violations == 0 then
        return
    end

    print("Found pairing-store identifiers referenced in group auth composition:")
    for _, violation in ipairs(violations) do
        print("- " .. violation.path .. ":" .. violation.line .. " (" .. violation.reason .. ")")
    end
    print("Group auth must be composed via shared resolvers (resolveDmGroupAccessWithLists / resolveEffectiveAllowFromLists).")
    os.exit(1)
end

main()
