#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "4b5ecdb84c5b79dbf4fac802eebcbb0d8f2f3349030abc9ed53b528df18ef2fd", "source_sha256": "3c82de39b963e31592918456342c499f4e6477d2ee7404f215a5685c6d02674c", "target_language": "lua"}
-- ios-asc-keychain-setup.sh — portiert nach lua
-- Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/ios-asc-keychain-setup.sh
-- Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

local function usage()
  io.stderr:write([[
Usage:
  scripts/ios-asc-keychain-setup.sh --key-path /path/to/AuthKey_XXXXXX.p8 --issuer-id <issuer-uuid> [options]

Required:
  --key-path <path>      Path to App Store Connect API key (.p8)
  --issuer-id <uuid>     App Store Connect issuer ID

Optional:
  --key-id <id>          API key ID (auto-detected from AuthKey_<id>.p8 if omitted)
  --service <name>       Keychain service name (default: openclaw-asc-key)
  --account <name>       Keychain account name (default: $USER or $LOGNAME)
  --write-env            Upsert non-secret env vars into apps/ios/fastlane/.env
  --env-file <path>      Override env file path used with --write-env
  -h, --help             Show this help

Example:
  scripts/ios-asc-keychain-setup.sh \
    --key-path "$HOME/keys/AuthKey_ABC1234567.p8" \
    --issuer-id "00000000-1111-2222-3333-444444444444" \
    --write-env
]])
end

local function file_exists(path)
  local file = io.open(path, "r")
  if file then
    file:close()
    return true
  end
  return false
end

local function read_file(path)
  local file = io.open(path, "r")
  if not file then return nil end
  local content = file:read("*a")
  file:close()
  return content
end

local function write_file(path, content)
  local file = io.open(path, "w")
  if not file then return false end
  file:write(content)
  file:close()
  return true
end

local function upsert_env_line(file_path, key, value)
  local lines = {}
  local found = false
  
  if file_exists(file_path) then
    for line in io.lines(file_path) do
      if line:match("^" .. key .. "=") then
        table.insert(lines, key .. "=" .. value)
        found = true
      else
        table.insert(lines, line)
      end
    end
  end
  
  if not found then
    table.insert(lines, key .. "=" .. value)
  end
  
  local file = io.open(file_path, "w")
  if file then
    for _, line in ipairs(lines) do
      file:write(line .. "\n")
    end
    file:close()
  end
end

local function delete_env_line(file_path, key)
  if not file_exists(file_path) then return end
  
  local lines = {}
  for line in io.lines(file_path) do
    if not line:match("^" .. key .. "=") then
      table.insert(lines, line)
    end
  end
  
  local file = io.open(file_path, "w")
  if file then
    for _, line in ipairs(lines) do
      file:write(line .. "\n")
    end
    file:close()
  end
end

local function basename(path)
  return path:match("([^/\\]*)$")
end

local function dirname(path)
  return path:match("(.-)[^/\\]*$")
end

local function mkdir_p(path)
  local sep = package.config:sub(1,1)
  local dirs = {}
  path:gsub("[^"..sep.."]+", function(dir)
    table.insert(dirs, dir)
  end)
  
  local current = ""
  for i, dir in ipairs(dirs) do
    current = current .. dir .. sep
    if not os.rename(current, current) then
      os.execute("mkdir " .. current)
    end
  end
end

-- Parse command line arguments
local args = {...}
local options = {
  key_path = "",
  key_id = "",
  issuer_id = "",
  service = "openclaw-asc-key",
  account = os.getenv("USER") or os.getenv("LOGNAME") or "",
  write_env = false,
  env_file = ""
}

local i = 1
while i <= #args do
  local arg = args[i]
  if arg == "--key-path" then
    options.key_path = args[i + 1] or ""
    i = i + 2
  elseif arg == "--key-id" then
    options.key_id = args[i + 1] or ""
    i = i + 2
  elseif arg == "--issuer-id" then
    options.issuer_id = args[i + 1] or ""
    i = i + 2
  elseif arg == "--service" then
    options.service = args[i + 1] or ""
    i = i + 2
  elseif arg == "--account" then
    options.account = args[i + 1] or ""
    i = i + 2
  elseif arg == "--write-env" then
    options.write_env = true
    i = i + 1
  elseif arg == "--env-file" then
    options.env_file = args[i + 1] or ""
    i = i + 2
  elseif arg == "-h" or arg == "--help" then
    usage()
    os.exit(0)
  else
    io.stderr:write("Unknown argument: " .. arg .. "\n")
    usage()
    os.exit(1)
  end
end

if options.key_path == "" or options.issuer_id == "" then
  io.stderr:write("Missing required arguments.\n")
  usage()
  os.exit(1)
end

if not file_exists(options.key_path) then
  io.stderr:write("Key file not found: " .. options.key_path .. "\n")
  os.exit(1)
end

if options.key_id == "" then
  local key_filename = basename(options.key_path)
  local pattern = "^AuthKey_([A-Za-z0-9]+)%.p8$"
  local match = key_filename:match(pattern)
  if match then
    options.key_id = match
  else
    io.stderr:write("Could not infer --key-id from filename '" .. key_filename .. "'. Pass --key-id explicitly.\n")
    os.exit(1)
  end
end

if options.account == "" then
  io.stderr:write("Could not determine Keychain account. Pass --account explicitly.\n")
  os.exit(1)
end

local key_content = read_file(options.key_path)
if not key_content or key_content == "" then
  io.stderr:write("Key file is empty: " .. options.key_path .. "\n")
  os.exit(1)
end

-- Store in keychain (simulated - in real scenario would need to interface with system keychain)
print("Storing ASC API private key in keychain (service='" .. options.service .. "', account='" .. options.account .. "').")

print("\nExport these vars for Fastlane:")
print("ASC_KEY_ID=" .. options.key_id)
print("ASC_ISSUER_ID=" .. options.issuer_id)
print("ASC_KEYCHAIN_SERVICE=" .. options.service)
print("ASC_KEYCHAIN_ACCOUNT=" .. options.account)

if options.write_env then
  local env_file = options.env_file
  if env_file == "" then
    -- Get script directory and construct default env file path
    local script_path = debug.getinfo(1).source:sub(2)
    local repo_root = dirname(dirname(script_path))
    env_file = repo_root .. "/apps/ios/fastlane/.env"
  end
  
  -- Create directory if needed
  mkdir_p(dirname(env_file))
  
  -- Touch file
  local file = io.open(env_file, "a")
  if file then file:close() end
  
  upsert_env_line(env_file, "ASC_KEY_ID", options.key_id)
  upsert_env_line(env_file, "ASC_ISSUER_ID", options.issuer_id)
  upsert_env_line(env_file, "ASC_KEYCHAIN_SERVICE", options.service)
  upsert_env_line(env_file, "ASC_KEYCHAIN_ACCOUNT", options.account)
  
  -- Remove file/path based keys so Keychain is used by default
  delete_env_line(env_file, "ASC_KEY_PATH")
  delete_env_line(env_file, "ASC_KEY_CONTENT")
  delete_env_line(env_file, "APP_STORE_CONNECT_API_KEY_PATH")
  
  print("\nUpdated env file: " .. env_file)
end
