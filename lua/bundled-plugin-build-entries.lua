#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "bac2c5542eeed830788c299350a8362a05ac3d5610bcea64f228bc3c4549df64", "source_sha256": "ddf85df3b9350046010bc7449b7c05ad91c9c7d97ce98d75578f16ec7e33cef1", "target_language": "lua"}
-- bundled-plugin-build-entries.mjs — portiert nach lua
-- Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/bundled-plugin-build-entries.mjs
-- Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

local fs = require("lfs")
local path = require("path")
local json = require("json")

-- Konstanten
local BUNDLED_PLUGIN_ROOT_DIR = "plugins"
local NON_PACKAGED_BUNDLED_PLUGIN_DIRS = {["qa-channel"] = true, ["qa-lab"] = true}
local TOP_LEVEL_PUBLIC_SURFACE_EXTENSIONS = {
    [".ts"] = true, [".js"] = true, [".mts"] = true, 
    [".cts"] = true, [".mjs"] = true, [".cjs"] = true
}

-- Hilfsfunktionen
local function toPosixPath(value)
    return string.gsub(value, "\\", "/")
end

local function fileExists(filepath)
    local attr = lfs.attributes(filepath)
    return attr and attr.mode == "file"
end

local function readBundledPluginPackageJson(packageJsonPath)
    if not fileExists(packageJsonPath) then
        return nil
    end
    
    local file = io.open(packageJsonPath, "r")
    if not file then
        return nil
    end
    
    local content = file:read("*a")
    file:close()
    
    local success, result = pcall(function()
        return json.decode(content)
    end)
    
    if success then
        return result
    else
        return nil
    end
end

local function isManifestlessBundledRuntimeSupportPackage(params)
    local packageName = ""
    if params.packageJson and params.packageJson.name and type(params.packageJson.name) == "string" then
        packageName = params.packageJson.name
    end
    
    if packageName ~= "@openclaw/" .. params.dirName then
        return false
    end
    
    return #params.topLevelPublicSurfaceEntries > 0
end

local function collectPluginSourceEntries(packageJson)
    local packageEntries = {}
    
    if packageJson and packageJson.openclaw and packageJson.openclaw.extensions and type(packageJson.openclaw.extensions) == "table" then
        for _, entry in ipairs(packageJson.openclaw.extensions) do
            if type(entry) == "string" and string.len(string.gsub(entry, "%s+", "")) > 0 then
                table.insert(packageEntries, entry)
            end
        end
    end
    
    local setupEntry = nil
    if packageJson and packageJson.openclaw and packageJson.openclaw.setupEntry and 
       type(packageJson.openclaw.setupEntry) == "string" and 
       string.len(string.gsub(packageJson.openclaw.setupEntry, "%s+", "")) > 0 then
        setupEntry = packageJson.openclaw.setupEntry
    end
    
    if setupEntry then
        -- Entferne Duplikate
        local uniqueEntries = {}
        for _, entry in ipairs(packageEntries) do
            uniqueEntries[entry] = true
        end
        uniqueEntries[setupEntry] = true
        
        packageEntries = {}
        for entry, _ in pairs(uniqueEntries) do
            table.insert(packageEntries, entry)
        end
    end
    
    if #packageEntries > 0 then
        return packageEntries
    else
        return {"./index.ts"}
    end
end

local function shouldStageBundledPluginRuntimeDependencies(packageJson)
    return packageJson and 
           packageJson.openclaw and 
           packageJson.openclaw.bundle and 
           packageJson.openclaw.bundle.stageRuntimeDependencies == true
end

local function collectTopLevelPublicSurfaceEntries(pluginDir)
    local entries = {}
    
    if not lfs.attributes(pluginDir, "mode") then
        return entries
    end
    
    for file in lfs.dir(pluginDir) do
        if file ~= "." and file ~= ".." then
            local filepath = path.join(pluginDir, file)
            local attr = lfs.attributes(filepath)
            
            if attr and attr.mode == "file" then
                local ext = path.extname(file)
                if TOP_LEVEL_PUBLIC_SURFACE_EXTENSIONS[ext] then
                    local normalizedName = string.lower(file)
                    
                    if not string.find(normalizedName, "%.d%.ts$") and
                       not string.match(normalizedName, "^config%-api%.[cm]?[jt]s$") and
                       not string.find(normalizedName, "%.test%.") and
                       not string.find(normalizedName, "%.spec%.") and
                       not string.find(normalizedName, "%.fixture%.") and
                       not string.find(normalizedName, "%.snap") then
                        table.insert(entries, "./" .. file)
                    end
                end
            end
        end
    end
    
    table.sort(entries)
    return entries
end

local function bundledPluginFile(id, name)
    return id .. "/" .. name
end

local function bundledDistPluginFile(id, filename)
    return path.join("dist", id, filename)
end

local function shouldBuildBundledCluster(dirName, env, options)
    -- Dummy implementation - ersetzen mit echter Logik
    return true
end

function collectBundledPluginBuildEntries(params)
    params = params or {}
    local cwd = params.cwd or lfs.currentdir()
    local env = params.env or os.getenv
    local extensionsRoot = path.join(cwd, BUNDLED_PLUGIN_ROOT_DIR)
    local entries = {}
    
    if not lfs.attributes(extensionsRoot, "mode") then
        return entries
    end
    
    for item in lfs.dir(extensionsRoot) do
        if item ~= "." and item ~= ".." then
            local pluginDir = path.join(extensionsRoot, item)
            local attr = lfs.attributes(pluginDir)
            
            if attr and attr.mode == "directory" then
                local manifestPath = path.join(pluginDir, "openclaw.plugin.json")
                local hasManifest = fileExists(manifestPath)
                local packageJsonPath = path.join(pluginDir, "package.json")
                local packageJson = readBundledPluginPackageJson(packageJsonPath)
                local topLevelPublicSurfaceEntries = collectTopLevelPublicSurfaceEntries(pluginDir)
                
                local isManifestless = isManifestlessBundledRuntimeSupportPackage({
                    dirName = item,
                    packageJson = packageJson,
                    topLevelPublicSurfaceEntries = topLevelPublicSurfaceEntries
                })
                
                if not hasManifest and not isManifestless then
                    goto continue
                end
                
                if not shouldBuildBundledCluster(item, env, {packageJson = packageJson}) then
                    goto continue
                end
                
                local sourceEntries = {}
                local sourceEntriesSet = {}
                
                if hasManifest then
                    local pluginEntries = collectPluginSourceEntries(packageJson)
                    for _, entry in ipairs(pluginEntries) do
                        if not sourceEntriesSet[entry] then
                            sourceEntriesSet[entry] = true
                            table.insert(sourceEntries, entry)
                        end
                    end
                end
                
                for _, entry in ipairs(topLevelPublicSurfaceEntries) do
                    if not sourceEntriesSet[entry] then
                        sourceEntriesSet[entry] = true
                        table.insert(sourceEntries, entry)
                    end
                end
                
                table.insert(entries, {
                    id = item,
                    hasManifest = hasManifest,
                    hasPackageJson = packageJson ~= nil,
                    packageJson = packageJson,
                    sourceEntries = sourceEntries
                })
                
                ::continue::
            end
        end
    end
    
    return entries
end

function listBundledPluginBuildEntries(params)
    local buildEntries = collectBundledPluginBuildEntries(params)
    local result = {}
    
    for _, entryData in ipairs(buildEntries) do
        local id = entryData.id
        local sourceEntries = entryData.sourceEntries
        
        for _, entry in ipairs(sourceEntries) do
            local normalizedEntry = string.gsub(entry, "^%./", "")
            local entryKey = bundledPluginFile(id, string.gsub(normalizedEntry, "%.[^%.]+$", ""))
            local fullPath = path.join(BUNDLED_PLUGIN_ROOT_DIR, id, normalizedEntry)
            result[entryKey] = toPosixPath(fullPath)
        end
    end
    
    return result
end

function listBundledPluginPackArtifacts(params)
    local buildEntries = collectBundledPluginBuildEntries(params)
    local artifacts = {}
    local artifactsSet = {}
    
    for _, entryData in ipairs(buildEntries) do
        local id = entryData.id
        local hasManifest = entryData.hasManifest
        local hasPackageJson = entryData.hasPackageJson
        local sourceEntries = entryData.sourceEntries
        
        if not NON_PACKAGED_BUNDLED_PLUGIN_DIRS[id] then
            if hasManifest then
                local artifact = bundledDistPluginFile(id, "openclaw.plugin.json")
                if not artifactsSet[artifact] then
                    artifactsSet[artifact] = true
                    table.insert(artifacts, artifact)
                end
            end
            
            if hasPackageJson then
                local artifact = bundledDistPluginFile(id, "package.json")
                if not artifactsSet[artifact] then
                    artifactsSet[artifact] = true
                    table.insert(artifacts, artifact)
                end
            end
            
            for _, entry in ipairs(sourceEntries) do
                local normalizedEntry = string.gsub(string.gsub(entry, "^%./", ""), "%.[^%.]+$", "")
                local artifact = bundledDistPluginFile(id, normalizedEntry .. ".js")
                if not artifactsSet[artifact] then
                    artifactsSet[artifact] = true
                    table.insert(artifacts, artifact)
                end
            end
        end
    end
    
    table.sort(artifacts)
    return artifacts
end

function listBundledPluginRuntimeDependencies(params)
    local runtimeDependencies = {}
    local runtimeDepsSet = {}
    
    local buildEntries = collectBundledPluginBuildEntries(params)
    
    for _, entryData in ipairs(buildEntries) do
        local packageJson = entryData.packageJson
        
        if shouldStageBundledPluginRuntimeDependencies(packageJson) then
            if packageJson and packageJson.dependencies then
                for depName, _ in pairs(packageJson.dependencies) do
                    if not runtimeDepsSet[depName] then
                        runtimeDepsSet[depName] = true
                        table.insert(runtimeDependencies, depName)
                    end
                end
            end
            
            if packageJson and packageJson.optionalDependencies then
                for depName, _ in pairs(packageJson.optionalDependencies) do
                    if not runtimeDepsSet[depName] then
                        runtimeDepsSet[depName] = true
                        table.insert(runtimeDependencies, depName)
                    end
                end
            end
        end
    end
    
    table.sort(runtimeDependencies)
    return runtimeDependencies
end

return {
    collectBundledPluginBuildEntries = collectBundledPluginBuildEntries,
    listBundledPluginBuildEntries = listBundledPluginBuildEntries,
    listBundledPluginPackArtifacts = listBundledPluginPackArtifacts,
    listBundledPluginRuntimeDependencies = listBundledPluginRuntimeDependencies
}
