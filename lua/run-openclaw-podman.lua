#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "f71e1f727a22d2239032cc422d595ec3a3cc6c57195e3ed5ba500f4f6fbab11e", "source_sha256": "9b573d1d5f5751c3fe5bb1eb243725ffb174987da9e458632a295c541458b2a0", "target_language": "lua"}
-- run-openclaw-podman.sh — portiert nach lua
-- Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/run-openclaw-podman.sh
-- Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

-- Rootless OpenClaw in Podman: run after one-time setup.
--
-- One-time setup (from repo root): ./scripts/podman/setup.sh
-- Then:
--   ./scripts/run-openclaw-podman.sh launch        # Start gateway
--   ./scripts/run-openclaw-podman.sh launch setup  # Onboarding wizard
--
-- Manage the running container from the host CLI:
--   openclaw --container openclaw dashboard --no-open
--   openclaw --container openclaw channels login
--
-- Legacy: "setup-host" delegates to the Podman setup script

local function fail(msg)
  io.stderr:write(msg .. "\n")
  os.exit(1)
end

local function execute_command(cmd)
  local handle = io.popen(cmd .. " 2>/dev/null", "r")
  if not handle then return nil end
  local result = handle:read("*a")
  handle:close()
  return result and result:gsub("%s+$", "")
end

local function resolve_user_home(user)
  local home = execute_command("getent passwd " .. user)
  if home then
    home = home:match("[^:]+$")
  end
  if not home and io.open("/etc/passwd", "r") then
    for line in io.lines("/etc/passwd") do
      local fields = {}
      for field in line:gmatch("[^:]+") do
        table.insert(fields, field)
      end
      if #fields >= 6 and fields[1] == user then
        home = fields[6]
        break
      end
    end
  end
  if not home then
    home = "/home/" .. user
  end
  return home
end

local function validate_single_line_value(label, value)
  if value:find("[\n\r]") then
    fail("Invalid " .. label .. ": control characters are not allowed.")
  end
end

local function validate_absolute_path(label, value)
  validate_single_line_value(label, value)
  if not value:match("^/") then
    fail("Invalid " .. label .. ": expected an absolute path.")
  end
  if value:find("//") then
    fail("Invalid " .. label .. ": repeated slashes are not allowed.")
  end
  if value:find("/%./") or value:match("/%.$") or value:find("/%.%./") or value:match("/%.%.$") then
    fail("Invalid " .. label .. ": dot path segments are not allowed.")
  end
end

local function validate_mount_source_path(label, value)
  validate_absolute_path(label, value)
  if value:find(":") then
    fail("Invalid " .. label .. ": ':' is not allowed in Podman bind-mount source paths.")
  end
end

local function ensure_safe_existing_regular_file(label, file)
  validate_absolute_path(label, file)
  local f = io.open(file, "r")
  if not f then
    fail("Missing " .. label .. ": " .. file)
  end
  local stat = f:stat()
  if stat and stat.type ~= "file" then
    f:close()
    fail("Unsafe " .. label .. ": expected a regular file (" .. file .. ")")
  end
  f:close()
end

local function ensure_safe_existing_dir(label, dir)
  validate_absolute_path(label, dir)
  local f = io.open(dir, "r")
  if not f then
    fail("Missing " .. label .. ": " .. dir)
  end
  local stat = f:stat()
  if stat and stat.type ~= "directory" then
    f:close()
    fail("Unsafe " .. label .. ": expected a directory (" .. dir .. ")")
  end
  f:close()
end

local function stat_uid(path)
  local result = execute_command("stat -c '%u' " .. path)
  if not result then
    result = execute_command("stat -f '%u' " .. path)
  end
  return result
end

local function stat_mode(path)
  local result = execute_command("stat -c '%a' " .. path)
  if not result then
    result = execute_command("stat -f '%Lp' " .. path)
  end
  return result
end

local function ensure_private_existing_dir_owned_by_user(label, dir)
  ensure_safe_existing_dir(label, dir)
  local uid = stat_uid(dir)
  if uid ~= tostring(execute_command("id -u")) then
    fail("Unsafe " .. label .. ": not owned by current user (" .. dir .. ")")
  end
  local mode = tonumber(stat_mode(dir), 8)
  if bit.band(mode, 0x022) ~= 0 then
    fail("Unsafe " .. label .. ": group/other writable (" .. dir .. ")")
  end
end

local function ensure_private_existing_regular_file_owned_by_user(label, file)
  ensure_safe_existing_regular_file(label, file)
  local uid = stat_uid(file)
  if uid ~= tostring(execute_command("id -u")) then
    fail("Unsafe " .. label .. ": not owned by current user (" .. file .. ")")
  end
  local mode = tonumber(stat_mode(file), 8)
  if bit.band(mode, 0x077) ~= 0 then
    fail("Unsafe " .. label .. ": expected owner-only permissions (" .. file .. ")")
  end
end

local function ensure_safe_write_file_path(label, file)
  validate_absolute_path(label, file)
  if io.open(file, "r") then
    local f = io.open(file, "r")
    local stat = f:stat()
    if stat and stat.type ~= "file" then
      f:close()
      fail("Unsafe " .. label .. ": expected a regular file (" .. file .. ")")
    end
    f:close()
  end
  local dir = file:match("(.+)/[^/]*")
  ensure_safe_existing_dir(label .. " parent directory", dir)
end

local function write_file_atomically(file, mode, content)
  ensure_safe_write_file_path("output file", file)
  local dir = file:match("(.+)/[^/]*")
  local tmp = execute_command("mktemp " .. dir .. "/.tmp.XXXXXX")
  local f = io.open(tmp, "w")
  f:write(content)
  f:close()
  os.execute("chmod " .. mode .. " " .. tmp)
  os.execute("mv -f " .. tmp .. " " .. file)
end

local function load_podman_env_file(file)
  ensure_private_existing_regular_file_owned_by_user("Podman env file", file)
  local dir = file:match("(.+)/[^/]*")
  ensure_private_existing_dir_owned_by_user("Podman env directory", dir)
  local f = io.open(file, "r")
  if not f then
    fail("Unable to open Podman env file: " .. file)
  end
  for line in f:lines() do
    local trimmed = line:match("^%s*(.-)%s*$")
    if trimmed ~= "" and not trimmed:match("^#") and trimmed:find("=") then
      local key, value = trimmed:match("^([^=]+)=(.*)$")
      key = key:match("^%s*(.-)%s*$")
      if key:match("^[A-Za-z_][A-Za-z0-9_]*$") then
        local valid_keys = {
          OPENCLAW_GATEWAY_TOKEN = true,
          OPENCLAW_PODMAN_CONTAINER = true,
          OPENCLAW_PODMAN_IMAGE = true,
          OPENCLAW_IMAGE = true,
          OPENCLAW_PODMAN_PULL = true,
          OPENCLAW_PODMAN_GATEWAY_HOST_PORT = true,
          OPENCLAW_GATEWAY_PORT = true,
          OPENCLAW_PODMAN_BRIDGE_HOST_PORT = true,
          OPENCLAW_BRIDGE_PORT = true,
          OPENCLAW_GATEWAY_BIND = true,
          OPENCLAW_PODMAN_USERNS = true,
          OPENCLAW_BIND_MOUNT_OPTIONS = true,
          OPENCLAW_PODMAN_PUBLISH_HOST = true
        }
        if valid_keys[key] then
          if value:match('^".*"$') or value:match("^'.*'$") then
            value = value:sub(2, -2)
          end
          _G[key] = value
          os.setenv(key, value)
        end
      end
    end
  end
  f:close()
end

local function validate_port(label, value)
  if not value:match("^[0-9]+$") or #value > 5 then
    fail("Invalid " .. label .. ": must be numeric.")
  end
  local numeric = tonumber(value)
  if numeric < 1 or numeric > 65535 then
    fail("Invalid " .. label .. ": out of range.")
  end
end

local PLATFORM_NAME = execute_command("uname -s") or "unknown"
local EFFECTIVE_USER = execute_command("id -un")
local EFFECTIVE_HOME = os.getenv("HOME") or ""
if EFFECTIVE_HOME == "" then
  EFFECTIVE_HOME = resolve_user_home(EFFECTIVE_USER)
end
if execute_command("id -u") == "0" then
  fail("Run run-openclaw-podman.sh as your normal user so Podman stays rootless.")
end

local args = {...}
if #args > 0 and args[1] == "setup-host" then
  table.remove(args, 1)
  local REPO_ROOT = execute_command("cd $(dirname $0)/.. && pwd")
  local SETUP_PODMAN = REPO_ROOT .. "/scripts/podman/setup.sh"
  if io.open(SETUP_PODMAN, "r") then
    os.execute(SETUP_PODMAN .. " " .. table.concat(args, " "))
    os.exit(0)
  end
  SETUP_PODMAN = REPO_ROOT .. "/setup-podman.sh"
  if io.open(SETUP_PODMAN, "r") then
    os.execute(SETUP_PODMAN .. " " .. table.concat(args, " "))
    os.exit(0)
  end
  io.stderr:write("Podman setup script not found. Run from repo root: ./scripts/podman/setup.sh\n")
  os.exit(1)
end

if #args > 0 and args[1] == "launch" then
  table.remove(args, 1)
end

if EFFECTIVE_HOME == "" then
  EFFECTIVE_HOME = "/tmp"
end
validate_absolute_path("effective home", EFFECTIVE_HOME)

local CONFIG_DIR = os.getenv("OPENCLAW_CONFIG_DIR") or (EFFECTIVE_HOME .. "/.openclaw")
local ENV_FILE = os.getenv("OPENCLAW_PODMAN_ENV") or (CONFIG_DIR .. "/.env")
if io.open(ENV_FILE, "r") then
  load_podman_env_file(ENV_FILE)
end

CONFIG_DIR = os.getenv("OPENCLAW_CONFIG_DIR") or (EFFECTIVE_HOME .. "/.openclaw")
ENV_FILE = os.getenv("OPENCLAW_PODMAN_ENV") or (CONFIG_DIR .. "/.env")
local WORKSPACE_DIR = os.getenv("OPENCLAW_WORKSPACE_DIR") or (CONFIG_DIR .. "/workspace")
local CONTAINER_NAME = os.getenv("OPENCLAW_PODMAN_CONTAINER") or "openclaw"
local OPENCLAW_IMAGE = os.getenv("OPENCLAW_PODMAN_IMAGE") or (os.getenv("OPENCLAW_IMAGE") or "openclaw:local")
local PODMAN_PULL = os.getenv("OPENCLAW_PODMAN_PULL") or "never"
local HOST_GATEWAY_PORT = os.getenv("OPENCLAW_PODMAN_GATEWAY_HOST_PORT") or (os.getenv("OPENCLAW_GATEWAY_PORT") or "18789")
local HOST_BRIDGE_PORT = os.getenv("OPENCLAW_PODMAN_BRIDGE_HOST_PORT") or (os.getenv("OPENCLAW_BRIDGE_PORT") or "18790")
local PUBLISH_HOST = os.getenv("OPENCLAW_PODMAN_PUBLISH_HOST") or "127.0.0.1"
validate_mount_source_path("config directory", CONFIG_DIR)
validate_mount_source_path("workspace directory", WORKSPACE_DIR)
validate_absolute_path("env file path", ENV_FILE)
validate_single_line_value("container name", CONTAINER_NAME)
validate_single_line_value("image name", OPENCLAW_IMAGE)
validate_single_line_value("publish host", PUBLISH_HOST)
validate_port("gateway host port", HOST_GATEWAY_PORT)
validate_port("bridge host port", HOST_BRIDGE_PORT)

local success = os.execute("cd " .. EFFECTIVE_HOME .. " 2>/dev/null || cd /tmp 2>/dev/null || true")

local RUN_SETUP = false
if #args > 0 and (args[1] == "setup" or args[1] == "onboard") then
  RUN_SETUP = true
  table.remove(args, 1)
end

os.execute("mkdir -p " .. CONFIG_DIR .. " " .. WORKSPACE_DIR)
os.execute("mkdir -p " .. CONFIG_DIR .. "/canvas " .. CONFIG_DIR .. "/cron")
os.execute("chmod 700 " .. CONFIG_DIR .. " " .. WORKSPACE_DIR)
ensure_private_existing_dir_owned_by_user("config directory", CONFIG_DIR)
ensure_private_existing_dir_owned_by_user("workspace directory", WORKSPACE_DIR)

local function resolve_config_gateway_bind(config_dir)
  if not execute_command("which openclaw") then
    return ""
  end
  local result = execute_command("OPENCLAW_CONTAINER='' OPENCLAW_CONFIG_DIR=" .. config_dir .. " openclaw config get gateway.bind 2>/dev/null")
  return result or ""
end

local CONFIG_GATEWAY_BIND = resolve_config_gateway_bind(CONFIG_DIR)
local GATEWAY_BIND = os.getenv("OPENCLAW_GATEWAY_BIND") or (CONFIG_GATEWAY_BIND ~= "" and CONFIG_GATEWAY_BIND or "lan")

local function upsert_env_var(file, key, value)
  ensure_safe_write_file_path("env file", file)
  local dir = file:match("(.+)/[^/]*")
  local tmp = execute_command("mktemp " .. dir .. "/.env.tmp.XXXXXX")
  local found = false
  if io.open(file, "r") then
    local f = io.open(file, "r")
    local lines = {}
    for line in f:lines() do
      if line:match("^" .. key .. "=") then
        table.insert(lines, key .. "=" .. value)
        found = true
      else
        table.insert(lines, line)
      end
    end
    f:close()
    if not found then
      table.insert(lines, key .. "=" .. value)
    end
    local f_out = io.open(tmp, "w")
    for _, line in ipairs(lines) do
      f_out:write(line .. "\n")
    end
    f_out:close()
  else
    local f = io.open(tmp, "w")
    f:write(key .. "=" .. value .. "\n")
    f:close()
  end
  os.execute("mv " .. tmp .. " " .. file)
  os.execute("chmod 600 " .. file .. " 2>/dev/null || true")
end

local function generate_token_hex_32()
  if execute_command("which openssl") then
    return execute_command("openssl rand -hex 32")
  end
  if execute_command("which python3") then
    local handle = io.popen('python3 -c "import secrets; print(secrets.token_hex(32))"', "r")
    local result = handle:read("*a"):gsub("%s+", "")
    handle:close()
    return result
  end
  if execute_command("which od") then
    return execute_command("od -An -N32 -tx1 /dev/urandom | tr -d ' \n'")
  end
  fail("Missing dependency: need openssl or python3 (or od) to generate OPENCLAW_GATEWAY_TOKEN.")
end

local function create_token_env_file(file, token)
  local dir = file:match("(.+)/[^/]*")
  ensure_private_existing_dir_owned_by_user("token env directory", dir)
  local tmp = execute_command("mktemp " .. dir .. "/.token.env.XXXXXX")
  os.execute("chmod 600 " .. tmp)
  local f = io.open(tmp, "w")
  f:write("OPENCLAW_GATEWAY_TOKEN=" .. token .. "\n")
  f:close()
  return tmp
end

local function sync_local_control_ui_origins_via_cli(file, port)
  local config_dir = file:match("(.+)/[^/]*")
  if not execute_command("which openclaw") then
    io.stderr:write("Warning: openclaw not found; unable to sync gateway.controlUi.allowedOrigins in " .. file .. ".\n")
    return
  end
  if not execute_command("which python3") then
    os.execute("OPENCLAW_CONTAINER='' OPENCLAW_CONFIG_DIR=" .. config_dir .. " openclaw config set gateway.controlUi.allowedOrigins '[\"http://127.0.0.1:" .. port .. "\",\"http://localhost:" .. port .. "\"]' --strict-json >/dev/null")
    return
  end
  local allowed_json = execute_command("OPENCLAW_CONTAINER='' OPENCLAW_CONFIG_DIR=" .. config_dir .. " openclaw config get gateway.controlUi.allowedOrigins --json 2>/dev/null") or ""
  
  local script = [[
import json
import sys

port = sys.argv[1]
raw = sys.argv[2] if len(sys.argv) > 2 else ""
desired = [
    f"http://127.0.0.1:{port}",
    f"http://localhost:{port}",
]
allowed = []
if raw:
    try:
        parsed = json.loads(raw)
        if isinstance(parsed, list):
            allowed = parsed
    except json.JSONDecodeError:
        allowed = []
cleaned = []
seen = set()
for origin in allowed + desired:
    if not isinstance(origin, str):
        continue
    normalized = origin.strip()
    if not normalized or normalized in seen:
        continue
    cleaned.append(normalized)
    seen.add(normalized)
print(json.dumps(cleaned))
]]
  
  local handle = io.popen("python3 - " .. port .. " '" .. allowed_json .. "'", "w")
  handle:write(script)
  handle:close()
  
  os.execute("OPENCLAW_CONTAINER='' OPENCLAW_CONFIG_DIR=" .. config_dir .. " openclaw config set gateway.controlUi.allowedOrigins '" .. allowed_json .. "' --strict-json >/dev/null")
end

local function sync_local_control_ui_origins(file, port)
  ensure_safe_write_file_path("config file", file)
  if not execute_command("which python3") then
    io.stderr:write("Warning: python3 not found; unable to sync gateway.controlUi.allowedOrigins in " .. file .. ".\n")
    return
  end
  local dir = file:match("(.+)/[^/]*")
  ensure_private_existing_dir_owned_by_user("config file directory", dir)
  local tmp = execute_command("mktemp " .. dir .. "/.config.tmp.XXXXXX")
  
  local script = [[
import json
import sys

path = sys.argv[1]
port = sys.argv[2]
tmp = sys.argv[3]
try:
    with open(path, "r", encoding="utf-8") as fh:
        data = json.load(fh)
except json.JSONDecodeError as exc:
    print(
        f"Warning: unable to sync gateway.controlUi.allowedOrigins in {path}: existing config is not strict JSON ({exc}). Leaving file unchanged.",
        file=sys.stderr,
    )
    raise SystemExit(1)
if not isinstance(data, dict):
    raise SystemExit(f"{path}: expected top-level object")
gateway = data.setdefault("gateway", {})
if not isinstance(gateway, dict):
    raise SystemExit(f"{path}: expected gateway object")
gateway.setdefault("mode", "local")
control_ui = gateway.setdefault("controlUi", {})
if not isinstance(control_ui, dict):
    raise SystemExit(f"{path}: expected gateway.controlUi object")
allowed = control_ui.get("allowedOrigins")
desired = [
    f"http://127.0.0.1:{port}",
    f"http://localhost:{port}",
]
if not isinstance(allowed, list):
    allowed = []
cleaned = []
seen = set()
for origin in allowed:
    if not isinstance(origin, str):
        continue
    normalized = origin.strip()
    if not normalized or normalized in seen:
        continue
    cleaned.append(normalized)
    seen.add(normalized)
for origin in desired:
    if origin not in seen:
        cleaned.append(origin)
        seen.add(origin)
control_ui["allowedOrigins"] = cleaned
with open(tmp, "w", encoding="utf-8") as fh:
    json.dump(data, fh, indent=2)
    fh.write("\n")
]]
  
  local handle = io.popen("python3 - '" .. file .. "' " .. port .. " '" .. tmp .. "'", "w")
  handle:write(script)
  local status = handle:close()
  
  if not status then
    os.execute("rm -f " .. tmp)
    sync_local_control_ui_origins_via_cli(file, port)
    return
  end
  if not execute_command("test -s " .. tmp) then
    os.execute("rm -f " .. tmp)
    return
  end
  os.execute("chmod 600 " .. tmp .. " 2>/dev/null || true")
  os.execute("mv -f " .. tmp .. " " .. file)
end

local TOKEN_ENV_FILE = ""
local function cleanup_token_env_file()
  if TOKEN_ENV_FILE ~= "" and io.open(TOKEN_ENV_FILE, "r") then
    os.execute("rm -f " .. TOKEN_ENV_FILE)
  end
end

local OPENCLAW_GATEWAY_TOKEN = os.getenv("OPENCLAW_GATEWAY_TOKEN")
if not OPENCLAW_GATEWAY_TOKEN then
  OPENCLAW_GATEWAY_TOKEN = generate_token_hex_32()
  os.execute("mkdir -p " .. ENV_FILE:match("(.+)/[^/]*"))
  ensure_safe_existing_dir("env file directory", ENV_FILE:match("(.+)/[^/]*"))
  upsert_env_var(ENV_FILE, "OPENCLAW_GATEWAY_TOKEN", OPENCLAW_GATEWAY_TOKEN)
  io.stderr:write("Generated OPENCLAW_GATEWAY_TOKEN and wrote it to " .. ENV_FILE .. ".\n")
end

local CONFIG_JSON = CONFIG_DIR .. "/openclaw.json"
if not io.open(CONFIG_JSON, "r") then
  local content = '{ "gateway": { "mode": "local" } }\n'
  write_file_atomically(CONFIG_JSON, "600", content)
  io.stderr:write("Created " .. CONFIG_JSON .. " (minimal gateway.mode=local).\n")
end
sync_local_control_ui_origins(CONFIG_JSON, HOST_GATEWAY_PORT)

local PODMAN_USERNS = os.getenv("OPENCLAW_PODMAN_USERNS") or "keep-id"
local USERNS_ARGS = {}
local RUN_USER_ARGS = {}
if PODMAN_USERNS == "" or PODMAN_USERNS == "auto" then
  -- Empty
elseif PODMAN_USERNS == "keep-id" then
  USERNS_ARGS = {"--userns=keep-id"}
elseif PODMAN_USERNS == "host" then
  USERNS_ARGS = {"--userns=host"}
else
  fail("Unsupported OPENCLAW_PODMAN_USERNS=" .. PODMAN_USERNS .. " (expected: keep-id, auto, host).")
end

local RUN_UID = execute_command("id -u")
local RUN_GID = execute_command("id -g")
if PODMAN_USERNS == "keep-id" then
  RUN_USER_ARGS = {"--user", RUN_UID .. ":" .. RUN_GID}
else
  io.stderr:write("Starting container without --user (OPENCLAW_PODMAN_USERNS=" .. PODMAN_USERNS .. "), mounts may require ownership fixes.\n")
end

local SELINUX_MOUNT_OPTS = ""
if not os.getenv("OPENCLAW_BIND_MOUNT_OPTIONS") then
  if execute_command("uname -s") == "Linux" and execute_command("which getenforce") then
    local selinux_mode = execute_command("getenforce") or ""
    if selinux_mode == "Enforcing" or selinux_mode == "Permissive" then
      SELINUX_MOUNT_OPTS = ",Z"
    end
  end
else
  SELINUX_MOUNT_OPTS = os.getenv("OPENCLAW_BIND_MOUNT_OPTIONS"):sub(2)
  if SELINUX_MOUNT_OPTS ~= "" then
    SELINUX_MOUNT_OPTS = "," .. SELINUX_MOUNT_OPTS
  end
end

if RUN_SETUP then
  TOKEN_ENV_FILE = create_token_env_file(ENV_FILE, OPENCLAW_GATEWAY_TOKEN)
  local cmd = "podman run --pull=" .. PODMAN_PULL .. " --rm -it --init "
  for _, arg in ipairs(USERNS_ARGS) do
    cmd = cmd .. arg .. " "
  end
  for _, arg in ipairs(RUN_USER_ARGS) do
    cmd = cmd .. arg .. " "
  end
  cmd = cmd .. "-e HOME=/home/node -e TERM=xterm-256color -e BROWSER=echo "
  cmd = cmd .. "-e NPM_CONFIG_CACHE=/home/node/.openclaw/.npm "
  cmd = cmd .. "-e OPENCLAW_NO_RESPAWN=1 "
  cmd = cmd .. "--env-file " .. TOKEN_ENV_FILE .. " "
  cmd = cmd .. "-v " .. CONFIG_DIR .. ":/home/node/.openclaw:rw" .. SELINUX_MOUNT_OPTS .. " "
  cmd = cmd .. "-v " .. WORKSPACE_DIR .. ":/home/node/.openclaw/workspace:rw" .. SELINUX_MOUNT_OPTS .. " "
  cmd = cmd .. OPENCLAW_IMAGE .. " node dist/index.js onboard " .. table.concat(args, " ")
  os.execute(cmd)
  os.exit(0)
end

TOKEN_ENV_FILE = create_token_env_file(ENV_FILE, OPENCLAW_GATEWAY_TOKEN)
local cmd = "podman run --pull=" .. PODMAN_PULL .. " -d --replace --name " .. CONTAINER_NAME .. " --init "
for _, arg in ipairs(USERNS_ARGS) do
  cmd = cmd .. arg .. " "
end
for _, arg in ipairs(RUN_USER_ARGS) do
  cmd = cmd .. arg .. " "
end
cmd = cmd .. "-e HOME=/home/node -e TERM=xterm-256color "
cmd = cmd .. "-e NPM_CONFIG_CACHE=/home/node/.openclaw/.npm "
cmd = cmd .. "-e OPENCLAW_NO_RESPAWN=1 "
cmd = cmd .. "--env-file " .. TOKEN_ENV_FILE .. " "
cmd = cmd .. "-v " .. CONFIG_DIR .. ":/home/node/.openclaw:rw" .. SELINUX_MOUNT_OPTS .. " "
cmd = cmd .. "-v " .. WORKSPACE_DIR .. ":/home/node/.openclaw/workspace:rw" .. SELINUX_MOUNT_OPTS .. " "
cmd = cmd .. "-p " .. PUBLISH_HOST .. ":" .. HOST_GATEWAY_PORT .. ":18789 "
cmd = cmd .. "-p " .. PUBLISH_HOST .. ":" .. HOST_BRIDGE_PORT .. ":18790 "
cmd = cmd .. OPENCLAW_IMAGE .. " node dist/index.js gateway --bind " .. GATEWAY_BIND .. " --port 18789 >/dev/null"
os.execute(cmd)

print("Container " .. CONTAINER_NAME .. " started: http://127.0.0.1:" .. HOST_GATEWAY_PORT .. "/")
print("podman exec -it " .. CONTAINER_NAME .. " openclaw dashboard --no-open")
print("podman exec -it " .. CONTAINER_NAME .. " openclaw devices approve --latest  # if pairing required")
print("podman logs -f " .. CONTAINER_NAME)
if PLATFORM_NAME == "Linux" then
  print("For auto-start/restarts, use: ./scripts/podman/setup.sh --quadlet (Quadlet + systemd user service).")
end
