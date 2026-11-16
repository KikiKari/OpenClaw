#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "966e53482e8ad73b0033d249f1dcdacec9f82d224a668d72d38c5f744b8f27c8", "source_sha256": "913a32ef02a0f4e83bb9d65b279088c91abd5e717e9dbba62e17a4a50836e586", "target_language": "lua"}
-- check-architecture-smells.mjs — portiert nach lua
-- Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-architecture-smells.mjs
-- Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

local path = require("path")
local fs = require("fs")
local ts = require("typescript")

local BUNDLED_PLUGIN_PATH_PREFIX = "extensions/"
local repoRoot = path.resolve(debug.getinfo(1).source:match("@?(.-)[/\\][^/\\]*$"), "..")
local scanRoots = { "src/plugin-sdk", "src/plugins/runtime" }

local function compareEntries(left, right)
  if left.category ~= right.category then
    return left.category < right.category
  elseif left.file ~= right.file then
    return left.file < right.file
  elseif left.line ~= right.line then
    return left.line < right.line
  elseif left.kind ~= right.kind then
    return left.kind < right.kind
  else
    return left.reason < right.reason
  end
end

local function pushEntry(entries, entry)
  table.insert(entries, entry)
end

local function normalizeRepoPath(repoRoot, filePath)
  return path.relative(repoRoot, filePath):gsub("\\", "/")
end

local function resolveRepoSpecifier(repoRoot, specifier, filePath)
  local resolvedPath = path.resolve(path.dirname(filePath), specifier)
  if path.isAbsolute(specifier) then
    resolvedPath = path.resolve(repoRoot, specifier:sub(2))
  end
  if fs.existsSync(resolvedPath) and resolvedPath:sub(1, #repoRoot) == repoRoot then
    return normalizeRepoPath(repoRoot, resolvedPath)
  end
  return nil
end

local function toLine(sourceFile, node)
  local pos = ts.getLineAndCharacterOfPosition(sourceFile, node.pos)
  return pos.line + 1
end

local function visitModuleSpecifiers(ts, sourceFile, callback)
  local function visit(node)
    if ts.isImportDeclaration(node) or ts.isExportDeclaration(node) then
      local specifierNode = node.moduleSpecifier
      if specifierNode and ts.isStringLiteral(specifierNode) then
        local specifier = specifierNode.text
        local kind = node.kind == ts.SyntaxKind.ImportDeclaration and "import" or "export"
        callback({ kind = kind, specifier = specifier, specifierNode = specifierNode })
      end
    end
    ts.forEachChild(node, visit)
  end
  visit(sourceFile)
end

local function collectTypeScriptFilesFromRoots(scanRoots)
  local files = {}
  for _, root in ipairs(scanRoots) do
    local fullPath = path.join(repoRoot, root)
    if fs.existsSync(fullPath) then
      local function walk(dir)
        local items = fs.readdirSync(dir)
        for _, item in ipairs(items) do
          local itemPath = path.join(dir, item)
          local stat = fs.statSync(itemPath)
          if stat.isDirectory() then
            walk(itemPath)
          elseif stat.isFile() and item:match("%.ts$") and not item:match("%.d%.ts$") then
            table.insert(files, itemPath)
          end
        end
      end
      walk(fullPath)
    end
  end
  table.sort(files, function(a, b)
    return normalizeRepoPath(repoRoot, a) < normalizeRepoPath(repoRoot, b)
  end)
  return files
end

local function collectTypeScriptInventory(options)
  local ts = options.ts
  local files = options.files
  local compareEntries = options.compareEntries
  local collectEntries = options.collectEntries
  
  local inventory = {}
  
  for _, filePath in ipairs(files) do
    local content = fs.readFileSync(filePath, "utf8")
    local sourceFile = ts.createSourceFile(filePath, content, ts.ScriptTarget.ESNext, true)
    local entries = collectEntries(sourceFile, filePath)
    for _, entry in ipairs(entries) do
      table.insert(inventory, entry)
    end
  end
  
  table.sort(inventory, compareEntries)
  return inventory
end

local function scanPluginSdkExtensionFacadeSmells(sourceFile, filePath)
  local relativeFile = normalizeRepoPath(repoRoot, filePath)
  if not relativeFile:match("^src/plugin%-sdk/") then
    return {}
  end

  local entries = {}

  visitModuleSpecifiers(ts, sourceFile, function(info)
    local kind = info.kind
    local specifier = info.specifier
    local specifierNode = info.specifierNode
    
    if kind ~= "export" then
      return
    end
    local resolvedPath = resolveRepoSpecifier(repoRoot, specifier, filePath)
    if not resolvedPath or not resolvedPath:match("^"..BUNDLED_PLUGIN_PATH_PREFIX) then
      return
    end
    pushEntry(entries, {
      category = "plugin-sdk-extension-facade",
      file = relativeFile,
      line = toLine(sourceFile, specifierNode),
      kind = kind,
      specifier = specifier,
      resolvedPath = resolvedPath,
      reason = "plugin-sdk public surface re-exports extension-owned implementation",
    })
  end)
  return entries
end

local function scanRuntimeTypeImplementationSmells(sourceFile, filePath)
  local relativeFile = normalizeRepoPath(repoRoot, filePath)
  if not relativeFile:match("^src/plugins/runtime/types(%-.*)?%.ts$") then
    return {}
  end

  local entries = {}

  local function visit(node)
    if ts.isImportTypeNode(node) and 
       ts.isLiteralTypeNode(node.argument) and 
       ts.isStringLiteral(node.argument.literal) then
      
      local specifier = node.argument.literal.text
      local resolvedPath = resolveRepoSpecifier(repoRoot, specifier, filePath)
      
      if resolvedPath and (
         resolvedPath:match("^src/plugins/runtime/runtime%-.-%.ts$") or
         resolvedPath:match("^extensions/[^/]+/runtime%-api%.[^/]+$")
      ) then
        pushEntry(entries, {
          category = "runtime-type-implementation-edge",
          file = relativeFile,
          line = toLine(sourceFile, node.argument.literal),
          kind = "import-type",
          specifier = specifier,
          resolvedPath = resolvedPath,
          reason = "runtime type file references implementation shim directly",
        })
      end
    end

    ts.forEachChild(node, visit)
  end

  visit(sourceFile)
  return entries
end

local function scanRuntimeServiceLocatorSmells(sourceFile, filePath)
  local relativeFile = normalizeRepoPath(repoRoot, filePath)
  if not relativeFile:match("^src/plugin%-sdk/") and 
     not relativeFile:match("^src/plugins/runtime/") then
    return {}
  end

  local entries = {}
  local exportedNames = {}
  local runtimeStoreCalls = {}
  local mutableStateNodes = {}

  for _, statement in ipairs(sourceFile.statements) do
    if ts.isFunctionDeclaration(statement) and statement.name then
      local isExported = false
      if statement.modifiers then
        for _, modifier in ipairs(statement.modifiers) do
          if modifier.kind == ts.SyntaxKind.ExportKeyword then
            isExported = true
            break
          end
        end
      end
      if isExported then
        exportedNames[statement.name.text] = true
      end
    elseif ts.isVariableStatement(statement) then
      local isExported = false
      if statement.modifiers then
        for _, modifier in ipairs(statement.modifiers) do
          if modifier.kind == ts.SyntaxKind.ExportKeyword then
            isExported = true
            break
          end
        end
      end
      
      for _, declaration in ipairs(statement.declarationList.declarations) do
        if ts.isIdentifier(declaration.name) and isExported then
          exportedNames[declaration.name.text] = true
        end
        if not isExported and 
           (statement.declarationList.flags & ts.NodeFlags.Let) ~= 0 and
           ts.isIdentifier(declaration.name) then
          table.insert(mutableStateNodes, declaration.name)
        end
      end
    end
  end

  local function visit(node)
    if ts.isCallExpression(node) and 
       ts.isIdentifier(node.expression) and 
       node.expression.text == "createPluginRuntimeStore" then
      table.insert(runtimeStoreCalls, node.expression)
    end

    ts.forEachChild(node, visit)
  end

  visit(sourceFile)

  local getterNames = {}
  local setterNames = {}
  
  for name, _ in pairs(exportedNames) do
    if name:match("^get[A-Z]") then
      table.insert(getterNames, name)
    end
    if name:match("^set[A-Z]") then
      table.insert(setterNames, name)
    end
  end

  if #runtimeStoreCalls > 0 and #getterNames > 0 and #setterNames > 0 then
    for _, callNode in ipairs(runtimeStoreCalls) do
      pushEntry(entries, {
        category = "runtime-service-locator",
        file = relativeFile,
        line = toLine(sourceFile, callNode),
        kind = "runtime-store",
        specifier = "createPluginRuntimeStore",
        resolvedPath = relativeFile,
        reason = string.format(
          "exports paired runtime accessors (%s / %s) over module-global store state",
          table.concat(getterNames, ", "),
          table.concat(setterNames, ", ")
        ),
      })
    end
  end

  if #mutableStateNodes > 0 and #getterNames > 0 and #setterNames > 0 then
    for _, identifier in ipairs(mutableStateNodes) do
      pushEntry(entries, {
        category = "runtime-service-locator",
        file = relativeFile,
        line = toLine(sourceFile, identifier),
        kind = "mutable-state",
        specifier = identifier.text,
        resolvedPath = relativeFile,
        reason = string.format(
          "module-global mutable state backs exported runtime accessors (%s / %s)",
          table.concat(getterNames, ", "),
          table.concat(setterNames, ", ")
        ),
      })
    end
  end

  return entries
end

local function collectArchitectureSmells()
  local files = collectTypeScriptFilesFromRoots(scanRoots)
  return collectTypeScriptInventory({
    ts = ts,
    files = files,
    compareEntries = compareEntries,
    collectEntries = function(sourceFile, filePath)
      local result = {}
      
      local pluginSdkSmells = scanPluginSdkExtensionFacadeSmells(sourceFile, filePath)
      for _, entry in ipairs(pluginSdkSmells) do
        table.insert(result, entry)
      end
      
      local runtimeTypeSmells = scanRuntimeTypeImplementationSmells(sourceFile, filePath)
      for _, entry in ipairs(runtimeTypeSmells) do
        table.insert(result, entry)
      end
      
      local serviceLocatorSmells = scanRuntimeServiceLocatorSmells(sourceFile, filePath)
      for _, entry in ipairs(serviceLocatorSmells) do
        table.insert(result, entry)
      end
      
      return result
    end,
  })
end

local function formatInventoryHuman(inventory)
  if #inventory == 0 then
    return "No architecture smells found for the configured checks."
  end

  local lines = {"Architecture smell inventory:"}
  local activeCategory = ""
  local activeFile = ""
  
  for _, entry in ipairs(inventory) do
    if entry.category ~= activeCategory then
      activeCategory = entry.category
      activeFile = ""
      table.insert(lines, entry.category)
    end
    if entry.file ~= activeFile then
      activeFile = entry.file
      table.insert(lines, "  " .. activeFile)
    end
    table.insert(lines, "    - line " .. entry.line .. " [" .. entry.kind .. "] " .. entry.reason)
    table.insert(lines, "      specifier: " .. entry.specifier)
    table.insert(lines, "      resolved: " .. entry.resolvedPath)
  end
  
  return table.concat(lines, "\n")
end

local function writeLine(stream, text)
  stream:write(text .. "\n")
end

local function runArchitectureSmellsCheck(argv, io)
  argv = argv or {}
  local streams = io or { stdout = io.stdout or io.output, stderr = io.stderr or io.output }
  
  local json = false
  for _, arg in ipairs(argv) do
    if arg == "--json" then
      json = true
      break
    end
  end
  
  local inventory = collectArchitectureSmells()

  if json then
    writeLine(streams.stdout, require("cjson").encode(inventory))
    return 0
  end

  writeLine(streams.stdout, formatInventoryHuman(inventory))
  local countText = tostring(#inventory) .. " smell" .. (#inventory == 1 and "" or "s") .. " found."
  writeLine(streams.stdout, countText)
  return 0
end

local function main(argv, io)
  return runArchitectureSmellsCheck(argv, io)
end

if arg and #arg > 0 then
  main(arg, { stdout = io.stdout, stderr = io.stderr })
end

return {
  collectArchitectureSmells = collectArchitectureSmells,
  runArchitectureSmellsCheck = runArchitectureSmellsCheck,
  main = main
}
