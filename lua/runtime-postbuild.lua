#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "f2aa35f0e6f953bc30355b75fa48ceb62f0b5a0f0eed7180ddd3c42dff2de91a", "source_sha256": "fd0e09df4d2dcc4aafd9784f264f0b9e5a046c02335886978c614026a9f3648c", "target_language": "lua"}
-- runtime-postbuild.mjs — portiert nach lua
-- Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/runtime-postbuild.mjs
-- Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

local fs = require("lfs")
local path = require("path")

-- Hilfsfunktionen für Dateioperationen
local function file_exists(filepath)
    local file = io.open(filepath, "r")
    if file then
        file:close()
        return true
    end
    return false
end

local function read_file(filepath)
    local file = io.open(filepath, "r")
    if not file then return nil end
    local content = file:read("*a")
    file:close()
    return content
end

local function write_file(filepath, content)
    local file = io.open(filepath, "w")
    if not file then return false end
    file:write(content)
    file:close()
    return true
end

local function mkdir_p(dir)
    local dirs = {}
    repeat
        table.insert(dirs, 1, dir)
        dir = path.dirname(dir)
    until dir == "/" or dir == "." or dir == ""

    for _, d in ipairs(dirs) do
        lfs.mkdir(d)
    end
end

-- Globale Konstanten
local ROOT = path.dirname(debug.getinfo(1).source:sub(2))
ROOT = path.normalize(ROOT .. "/..")
local ROOT_RUNTIME_ALIAS_PATTERN = "^(.+%.(runtime|contract))%-[%w_-]+%.js$"

-- Importierte Module (simuliert)
local function copyBundledPluginMetadata(params) end -- Placeholder
local function copyPluginSdkRootAlias(params) end -- Placeholder
local function writeTextFileIfChanged(filepath, content)
    local current_content = read_file(filepath)
    if current_content ~= content then
        write_file(filepath, content)
    end
end
local function stageBundledPluginRuntimeDeps(params) end -- Placeholder
local function stageBundledPluginRuntime(params) end -- Placeholder
local function writeOfficialChannelCatalog(params) end -- Placeholder

-- Statische Assets Definition
STATIC_EXTENSION_ASSETS = {
    {
        src = "extensions/acpx/src/runtime-internals/mcp-proxy.mjs",
        dest = "dist/extensions/acpx/mcp-proxy.mjs"
    },
    {
        src = "extensions/diffs/assets/viewer-runtime.js",
        dest = "dist/extensions/diffs/assets/viewer-runtime.js"
    }
}

function listStaticExtensionAssetOutputs(params)
    params = params or {}
    local assets = params.assets or STATIC_EXTENSION_ASSETS
    local outputs = {}
    for _, asset in ipairs(assets) do
        local dest = string.gsub(asset.dest, "\\", "/")
        table.insert(outputs, dest)
    end
    table.sort(outputs)
    return outputs
end

function copyStaticExtensionAssets(params)
    params = params or {}
    local rootDir = params.rootDir or ROOT
    local assets = params.assets or STATIC_EXTENSION_ASSETS
    local warn = params.warn or print

    for _, asset in ipairs(assets) do
        local srcPath = path.join(rootDir, asset.src)
        local destPath = path.join(rootDir, asset.dest)

        if file_exists(srcPath) then
            mkdir_p(path.dirname(destPath))
            local input = io.open(srcPath, "rb")
            local output = io.open(destPath, "wb")
            if input and output then
                output:write(input:read("*a"))
                input:close()
                output:close()
            end
        else
            warn("[runtime-postbuild] static asset not found, skipping: " .. asset.src)
        end
    end
end

function writeStableRootRuntimeAliases(params)
    params = params or {}
    local rootDir = params.rootDir or ROOT
    local distDir = path.join(rootDir, "dist")

    local files = {}
    for file in lfs.dir(distDir) do
        if lfs.attributes(path.join(distDir, file), "mode") == "file" then
            table.insert(files, file)
        end
    end

    for _, filename in ipairs(files) do
        local match = string.match(filename, ROOT_RUNTIME_ALIAS_PATTERN)
        if match then
            local base = match
            local aliasPath = path.join(distDir, base .. ".js")
            local content = 'export * from "./' .. filename .. '";\n'
            writeTextFileIfChanged(aliasPath, content)
        end
    end
end

function runRuntimePostBuild(params)
    params = params or {}
    copyPluginSdkRootAlias(params)
    copyBundledPluginMetadata(params)
    writeOfficialChannelCatalog(params)
    stageBundledPluginRuntimeDeps(params)
    stageBundledPluginRuntime(params)
    writeStableRootRuntimeAliases(params)
    copyStaticExtensionAssets(params)
end

-- Hauptausführung
if arg[0] == nil or debug.getinfo(2) == nil then
    runRuntimePostBuild()
end
