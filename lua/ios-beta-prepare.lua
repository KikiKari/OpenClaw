#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "3e1b15b027c9661ed71d19ea33f3dab6064f95d5c7834474f937b61d2b1cc406", "source_sha256": "2ca708f3e5a694b78eb83d1e37cf5eefe3e601ebec3e31d771a7ebd4246aa33c", "target_language": "lua"}
-- ios-beta-prepare.sh — portiert nach lua
-- Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/ios-beta-prepare.sh
-- Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

local function usage()
  print([[
Usage:
  OPENCLAW_PUSH_RELAY_BASE_URL=https://relay.example.com \
    scripts/ios-beta-prepare.sh --build-number 7 [--team-id TEAMID]

Prepares local beta-release inputs without touching local signing overrides:
- reads apps/ios/version.json and writes apps/ios/build/Version.xcconfig
- writes apps/ios/build/BetaRelease.xcconfig with canonical bundle IDs
- configures the beta build for relay-backed APNs registration
- regenerates apps/ios/OpenClaw.xcodeproj via xcodegen
]])
end

local function split(str, sep)
  local fields = {}
  local pattern = string.format("([^%s]+)", sep)
  str:gsub(pattern, function(c) fields[#fields+1] = c end)
  return fields
end

local function trim(s)
  return s:match("^%s*(.-)%s*$")
end

local function starts_with(str, start)
   return str:sub(1, #start) == start
end

local function ends_with(str, ending)
   return ending == "" or str:sub(-#ending) == ending
end

local function file_exists(name)
  local f = io.open(name, "r")
  if f ~= nil then
    io.close(f)
    return true
  else
    return false
  end
end

local function read_file(path)
  local file = io.open(path, "rb")
  if not file then return nil end
  local content = file:read "*a"
  file:close()
  return content
end

local function write_file(path, content)
  local file = io.open(path, "wb")
  if not file then return false end
  file:write(content)
  file:close()
  return true
end

local function dirname(path)
  local i = path:match("^.*()/")
  if i then
    return path:sub(1, i-1)
  else
    return "."
  end
end

local function abspath(path)
  local is_windows = package.config:sub(1,1) == "\\"
  if is_windows then
    local p = io.popen('cd "' .. path .. '" && cd')
    if p then
      local abs = p:read("*l")
      p:close()
      return abs
    end
  else
    local p = io.popen("cd '" .. path .. "' && pwd")
    if p then
      local abs = p:read("*l")
      p:close()
      return abs
    end
  end
  return path
end

local function exec(cmd)
  local handle = io.popen(cmd)
  local result = handle:read("*a")
  local success, _, code = handle:close()
  return success, result, code
end

local args = {...}
local ROOT_DIR = abspath(dirname(debug.getinfo(1).source:sub(2)) .. "/..")
local IOS_DIR = ROOT_DIR .. "/apps/ios"
local BUILD_DIR = IOS_DIR .. "/build"
local BETA_XCCONFIG = IOS_DIR .. "/build/BetaRelease.xcconfig"
local TEAM_HELPER = ROOT_DIR .. "/scripts/ios-team-id.sh"
local VERSION_HELPER = ROOT_DIR .. "/scripts/ios-write-version-xcconfig.sh"
local IOS_VERSION_HELPER = ROOT_DIR .. "/scripts/ios-version.ts"
local VERSION_SYNC_HELPER = ROOT_DIR .. "/scripts/ios-sync-versioning.ts"

local BUILD_NUMBER = ""
local TEAM_ID = os.getenv("IOS_DEVELOPMENT_TEAM") or ""
local PUSH_RELAY_BASE_URL = os.getenv("OPENCLAW_PUSH_RELAY_BASE_URL") or os.getenv("IOS_PUSH_RELAY_BASE_URL") or ""
local PUSH_RELAY_BASE_URL_XCCONFIG = ""
local IOS_VERSION = ""

local function prepare_build_dir()
  if not os.rename(BUILD_DIR, BUILD_DIR) then
    print("Refusing to use symlinked build directory: " .. BUILD_DIR)
    os.exit(1)
  end
  os.execute("mkdir -p " .. BUILD_DIR)
end

local function write_generated_file(output_path, content)
  if file_exists(output_path) then
    local attr = lfs.attributes(output_path)
    if attr and attr.mode == "link" then
      print("Refusing to overwrite symlinked file: " .. output_path)
      os.exit(1)
    end
  end

  local tmp_file = os.tmpname()
  local file = io.open(tmp_file, "w")
  file:write(content)
  file:close()
  os.rename(tmp_file, output_path)
end

local function validate_push_relay_base_url(value)
  if value:find("[%s]") then
    print("Invalid OPENCLAW_PUSH_RELAY_BASE_URL: whitespace is not allowed.")
    os.exit(1)
  end

  if value:find("[%$%(%)%=]") then
    print("Invalid OPENCLAW_PUSH_RELAY_BASE_URL: contains forbidden xcconfig characters.")
    os.exit(1)
  end

  local pattern = "^https://[A-Za-z0-9%.%-]+(:([0-9]+))?(/[A-Za-z0-9%._~!&*+,;:@%%/%-]*)?$"
  local match = value:match(pattern)
  if not match then
    print("Invalid OPENCLAW_PUSH_RELAY_BASE_URL: expected https://host[:port][/path].")
    os.exit(1)
  end

  local port_match = value:match(":([0-9]+)")
  if port_match then
    local port = tonumber(port_match)
    if port < 1 or port > 65535 then
      print("Invalid OPENCLAW_PUSH_RELAY_BASE_URL: port must be between 1 and 65535.")
      os.exit(1)
    end
  end
end

local i = 1
while i <= #args do
  local arg = args[i]
  if arg == "--" then
    -- skip
  elseif arg == "--build-number" then
    BUILD_NUMBER = args[i+1] or ""
    i = i + 1
  elseif arg == "--team-id" then
    TEAM_ID = args[i+1] or ""
    i = i + 1
  elseif arg == "-h" or arg == "--help" then
    usage()
    os.exit(0)
  else
    print("Unknown argument: " .. arg)
    usage()
    os.exit(1)
  end
  i = i + 1
end

if BUILD_NUMBER == "" then
  print("Missing required --build-number.")
  usage()
  os.exit(1)
end

if TEAM_ID == "" then
  local env_cmd = "IOS_ALLOW_KEYCHAIN_TEAM_FALLBACK=1 bash " .. TEAM_HELPER
  local success, result = exec(env_cmd)
  if success then
    TEAM_ID = trim(result)
  end
end

if TEAM_ID == "" then
  print("Could not resolve Apple Team ID. Set IOS_DEVELOPMENT_TEAM or sign into Xcode.")
  os.exit(1)
end

if PUSH_RELAY_BASE_URL == "" then
  print("Missing OPENCLAW_PUSH_RELAY_BASE_URL (or IOS_PUSH_RELAY_BASE_URL) for beta relay registration.")
  os.exit(1)
end

validate_push_relay_base_url(PUSH_RELAY_BASE_URL)

-- `.xcconfig` treats `//` as a comment opener. Break the URL with a helper setting
-- so Xcode still resolves it back to `https://...` at build time.
PUSH_RELAY_BASE_URL_XCCONFIG = PUSH_RELAY_BASE_URL:gsub("//", "$(OPENCLAW_URL_SLASH)$(OPENCLAW_URL_SLASH)")

prepare_build_dir()

local sync_cmd = "cd " .. ROOT_DIR .. " && node --import tsx " .. VERSION_SYNC_HELPER .. " --check"
local success = os.execute(sync_cmd)
if not success then
  os.exit(1)
end

local version_cmd = "cd " .. ROOT_DIR .. " && node --import tsx " .. IOS_VERSION_HELPER .. " --field canonicalVersion"
local _, result = exec(version_cmd)
IOS_VERSION = trim(result)

if IOS_VERSION == "" then
  print("Unable to resolve iOS version from " .. ROOT_DIR .. "/apps/ios/version.json.")
  os.exit(1)
end

local version_helper_cmd = "bash " .. VERSION_HELPER .. " --build-number " .. BUILD_NUMBER
os.execute(version_helper_cmd)

local beta_content = [[
// Auto-generated by scripts/ios-beta-prepare.sh.
// Local beta-release override; do not commit.
OPENCLAW_CODE_SIGN_STYLE = Automatic
OPENCLAW_DEVELOPMENT_TEAM = ]] .. TEAM_ID .. [[
OPENCLAW_IOS_SELECTED_TEAM = ]] .. TEAM_ID .. [[
OPENCLAW_APP_BUNDLE_ID = ai.openclaw.client
OPENCLAW_SHARE_BUNDLE_ID = ai.openclaw.client.share
OPENCLAW_ACTIVITY_WIDGET_BUNDLE_ID = ai.openclaw.client.activitywidget
OPENCLAW_WATCH_APP_BUNDLE_ID = ai.openclaw.client.watchkitapp
OPENCLAW_WATCH_EXTENSION_BUNDLE_ID = ai.openclaw.client.watchkitapp.extension
OPENCLAW_APP_PROFILE =
OPENCLAW_SHARE_PROFILE =
OPENCLAW_PUSH_TRANSPORT = relay
OPENCLAW_PUSH_DISTRIBUTION = official
OPENCLAW_URL_SLASH = /
OPENCLAW_PUSH_RELAY_BASE_URL = ]] .. PUSH_RELAY_BASE_URL_XCCONFIG .. [[
OPENCLAW_PUSH_APNS_ENVIRONMENT = production
]]

write_generated_file(BETA_XCCONFIG, beta_content)

local xcodegen_cmd = "cd " .. IOS_DIR .. " && xcodegen generate"
os.execute(xcodegen_cmd)

print("Prepared iOS beta release: version=" .. IOS_VERSION .. " build=" .. BUILD_NUMBER .. " team=" .. TEAM_ID)
print("XCODE_XCCONFIG_FILE=" .. BETA_XCCONFIG)
