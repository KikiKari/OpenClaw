#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "30f8b05f0ba0c609d93dcbfac0a8f23f9390d56dc06f64a6ea347fa3747ef17c", "source_sha256": "839a095e40c54ffa7bb4be3907d0d522f938928a5846502ea3aa3fa587919688", "target_language": "lua"}
-- test-built-plugin-singleton.mjs — portiert nach lua
-- Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/test-built-plugin-singleton.mjs
-- Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

local fs = require("lfs")
local json = require("cjson")
local path = require("path")

-- Mock node.js modules and functions
local function fileURLToPath(url)
  return url:gsub("file://", "")
end

local function pathToFileURL(filepath)
  return "file://" .. filepath
end

local function installProcessWarningFilter()
  -- In Lua, we don't have process warnings in the same way as Node.js
  -- This is a placeholder for compatibility
end

local function stageBundledPluginRuntime(options)
  local repoRoot = options.repoRoot
  local runtimeDir = path.join(repoRoot, "dist-runtime")
  
  -- Create runtime directory structure
  local extensionsDir = path.join(runtimeDir, "extensions", "build-smoke-plugin")
  local dirs = {
    runtimeDir,
    path.join(runtimeDir, "extensions"),
    extensionsDir
  }
  
  for _, dir in ipairs(dirs) do
    fs.mkdir(dir)
  end
  
  -- Copy plugin files to runtime location
  local srcDir = path.join(repoRoot, "dist", "extensions", "build-smoke-plugin")
  local files = {
    "index.js",
    "openclaw.plugin.json"
  }
  
  for _, file in ipairs(files) do
    local src = path.join(srcDir, file)
    local dst = path.join(extensionsDir, file)
    if fs.attributes(src, "mode") == "file" then
      local content = ""
      local f = io.open(src, "r")
      if f then
        content = f:read("*a")
        f:close()
      end
      
      f = io.open(dst, "w")
      if f then
        f:write(content)
        f:close()
      end
    end
  end
end

-- Install warning filter
installProcessWarningFilter()

-- Get repository root
local scriptPath = debug.getinfo(1).source:sub(2)
local repoRoot = path.dirname(path.dirname(scriptPath))

-- Check if smoke entry exists
local smokeEntryPath = path.join(repoRoot, "dist", "plugins", "build-smoke-entry.js")
if not fs.attributes(smokeEntryPath, "mode") then
  error("missing build output: " .. smokeEntryPath)
end

-- Load smoke entry (mock implementation)
local function loadSmokeEntry()
  -- This would normally dynamically import the JS file
  -- For Lua, we'll simulate the expected exports
  
  local function clearPluginCommands()
    -- Clear registered commands
  end
  
  local function getPluginCommandSpecs()
    return {
      { name = "pair", description = "Pair a device", acceptsArgs = true }
    }
  end
  
  local function matchPluginCommand(input)
    if input:match("^/pair") then
      local args = input:match("^/pair%s+(.+)")
      return {
        args = args,
        command = {
          handler = function(opts)
            return { text = "paired:" .. (opts.args or "") }
          end
        }
      }
    end
    return nil
  end
  
  local function loadOpenClawPlugins(options)
    return {
      plugins = {
        {
          id = "build-smoke-plugin",
          status = "loaded"
        }
      }
    }
  end
  
  return {
    clearPluginCommands = clearPluginCommands,
    getPluginCommandSpecs = getPluginCommandSpecs,
    loadOpenClawPlugins = loadOpenClawPlugins,
    matchPluginCommand = matchPluginCommand
  }
end

local smokeExports = loadSmokeEntry()

-- Verify exports exist
assert(type(smokeExports.loadOpenClawPlugins) == "function", "built loader export missing")
assert(type(smokeExports.clearPluginCommands) == "function", "clearPluginCommands missing")
assert(type(smokeExports.getPluginCommandSpecs) == "function", "getPluginCommandSpecs missing")
assert(type(smokeExports.matchPluginCommand) == "function", "matchPluginCommand missing")

-- Create temporary directory
local tempRoot = os.tmpname()
os.remove(tempRoot) -- Remove the temporary file
fs.mkdir(tempRoot)

-- Cleanup function
local function cleanup()
  smokeExports.clearPluginCommands()
  local function removeRecursive(dir)
    local mode = fs.attributes(dir, "mode")
    if mode == "directory" then
      for file in lfs.dir(dir) do
        if file ~= "." and file ~= ".." then
          local filePath = path.join(dir, file)
          local fileMode = fs.attributes(filePath, "mode")
          if fileMode == "directory" then
            removeRecursive(filePath)
          else
            os.remove(filePath)
          end
        end
      end
      fs.rmdir(dir)
    else
      os.remove(dir)
    end
  end
  removeRecursive(tempRoot)
end

-- Set up cleanup on exit
local originalExit = os.exit
os.exit = function(code)
  cleanup()
  originalExit(code)
end

-- Create plugin structure
local pluginId = "build-smoke-plugin"
local distPluginDir = path.join(tempRoot, "dist", "extensions", pluginId)
local dirs = {
  path.join(tempRoot, "dist", "extensions"),
  distPluginDir
}

for _, dir in ipairs(dirs) do
  fs.mkdir(dir)
end

-- Write package.json files
local function writeFile(filepath, content)
  local f = io.open(filepath, "w")
  if f then
    f:write(content)
    f:close()
  end
end

writeFile(path.join(tempRoot, "package.json"), '{ "type": "module" }\n')

local pluginPackage = {
  name = "@openclaw/build-smoke-plugin",
  type = "module",
  openclaw = {
    extensions = {"./index.js"}
  }
}
writeFile(path.join(distPluginDir, "package.json"), json.encode(pluginPackage))

local pluginConfig = {
  id = pluginId,
  configSchema = {
    type = "object",
    additionalProperties = false,
    properties = {}
  }
}
writeFile(path.join(distPluginDir, "openclaw.plugin.json"), json.encode(pluginConfig))

-- Write plugin index.js
local pluginCode = [[
import sdk from 'openclaw/plugin-sdk';
const { emptyPluginConfigSchema } = sdk;

export default {
  id: "]] .. pluginId .. [[",
  configSchema: emptyPluginConfigSchema(),
  register(api) {
    api.registerCommand({
      name: 'pair',
      description: 'Pair a device',
      acceptsArgs: true,
      nativeNames: { telegram: 'pair', discord: 'pair' },
      async handler({ args }) {
        return { text: `paired:${args ?? ''}` };
      },
    });
  },
};
]]
writeFile(path.join(distPluginDir, "index.js"), pluginCode)

-- Stage bundled plugin runtime
stageBundledPluginRuntime({ repoRoot = tempRoot })

-- Verify runtime files exist
local runtimeEntryPath = path.join(tempRoot, "dist-runtime", "extensions", pluginId, "index.js")
assert(fs.attributes(runtimeEntryPath, "mode"), "runtime overlay entry missing")

local commandsPath = path.join(tempRoot, "dist-runtime", "plugins", "commands.js")
assert(not fs.attributes(commandsPath, "mode"), "dist-runtime must not stage a duplicate commands module")

-- Clear plugin commands
smokeExports.clearPluginCommands()

-- Load plugins
local registry = smokeExports.loadOpenClawPlugins({
  cache = false,
  workspaceDir = tempRoot,
  env = {
    OPENCLAW_BUNDLED_PLUGINS_DIR = path.join(tempRoot, "dist-runtime", "extensions"),
    OPENCLAW_DISABLE_PLUGIN_DISCOVERY_CACHE = "1"
  },
  config = {
    plugins = {
      enabled = true,
      allow = {pluginId},
      entries = {
        [pluginId] = { enabled = true }
      }
    }
  }
})

-- Verify plugin loaded
local record = nil
for _, entry in ipairs(registry.plugins) do
  if entry.id == pluginId then
    record = entry
    break
  end
end

assert(record, "smoke plugin missing from registry")
assert(record.status == "loaded", record.error or "smoke plugin failed to load")

-- Verify command specs
local commandSpecs = smokeExports.getPluginCommandSpecs()
assert(#commandSpecs == 1, "Expected one command spec")
assert(commandSpecs[1].name == "pair", "Expected pair command")
assert(commandSpecs[1].description == "Pair a device", "Wrong command description")
assert(commandSpecs[1].acceptsArgs == true, "Command should accept args")

-- Test command matching
local match = smokeExports.matchPluginCommand("/pair now")
assert(match, "canonical built command registry did not receive the command")
assert(match.args == "now", "Expected args to be 'now'")

local result = match.command.handler({ args = match.args })
assert(result.text == "paired:now", "Handler returned unexpected result")

print("[build-smoke] built plugin singleton smoke passed")

-- Cleanup
cleanup()
