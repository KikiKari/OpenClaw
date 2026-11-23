#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "a2535beea751a80bf27acf65812976db1354703ea2ddb413acc0a23e1bcf416b", "source_sha256": "53a6908a18055c2a46b63b5da3ddbf4ea5f6b1867c1482c1dcc8903c3ab7b89a", "target_language": "lua"}
-- setup.sh — portiert nach lua
-- Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/podman/setup.sh
-- Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

-- One-time host setup for rootless OpenClaw in Podman. Uses the current
-- non-root user throughout, builds or pulls the image into that user's Podman
-- store, writes config under ~/.openclaw by default, and uses the repo-local
-- launch script at ./scripts/run-openclaw-podman.sh.
--
-- Usage: ./scripts/podman/setup.lua [--quadlet|--container]
--   --quadlet   Install a Podman Quadlet as the current user's systemd service
--   --container Only install image + config; you start the container manually (default)
--   Or set OPENCLAW_PODMAN_QUADLET=1 (or 0) to choose without a flag.
--
-- After this, start the gateway manually:
--   ./scripts/run-openclaw-podman.sh launch
--   ./scripts/run-openclaw-podman.sh launch setup
-- Or, if you used --quadlet:
--   systemctl --user start openclaw.service

local lfs = require("lfs")
local posix = require("posix")

-- Helper functions
local function split(str, sep)
  local fields = {}
  local pattern = string.format("([^%s]+)", sep or ":")
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
  local file = io.open(path, "r")
  if not file then return nil end
  local content = file:read("*all")
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

local function execute_command(cmd)
  local handle = io.popen(cmd)
  local result = handle:read("*a")
  local success, _, code = handle:close()
  return success, result, code
end

local function which(name)
  local success, result, _ = execute_command("command -v " .. name .. " 2>/dev/null")
  if success and result and result ~= "" then
    return trim(result)
  end
  return nil
end

local function fail(msg)
  io.stderr:write(msg .. "\n")
  os.exit(1)
end

local function require_cmd(name)
  if not which(name) then
    fail("Missing dependency: " .. name)
  end
end

local function is_root()
  local success, result, _ = execute_command("id -u 2>/dev/null")
  if success and tonumber(trim(result)) == 0 then
    return true
  end
  return false
end

local function validate_single_line_value(label, value)
  if string.find(value, "\n") or string.find(value, "\r") then
    fail("Invalid " .. label .. ": control characters are not allowed.")
  end
end

local function validate_absolute_path(label, value)
  validate_single_line_value(label, value)
  if not string.match(value, "^/") then
    fail("Invalid " .. label .. ": expected an absolute path.")
  end
  if string.find(value, "//") then
    fail("Invalid " .. label .. ": repeated slashes are not allowed.")
  end
  if string.find(value, "/%./") or ends_with(value, "/.") or string.find(value, "/%.%./") or ends_with(value, "/..") then
    fail("Invalid " .. label .. ": dot path segments are not allowed.")
  end
end

local function validate_mount_source_path(label, value)
  validate_absolute_path(label, value)
  if string.find(value, ":") then
    fail("Invalid " .. label .. ": ':' is not allowed in Podman bind-mount source paths.")
  end
end

local function validate_container_name(value)
  validate_single_line_value("container name", value)
  if not string.match(value, "^[A-Za-z0-9][A-Za-z0-9_.-]*$") then
    fail("Invalid container name: " .. value)
  end
end

local function validate_image_name(value)
  validate_single_line_value("image name", value)
  local transports = {
    "oci-archive:", "docker-archive:", "dir:", "oci:", 
    "containers-storage:", "docker-daemon:", "archive:"
  }
  for _, transport in ipairs(transports) do
    if starts_with(value, transport) then
      fail("Invalid image name: transport prefixes are not allowed: " .. value)
    end
  end
  if not string.match(value, "^[A-Za-z0-9][A-Za-z0-9._/:@-]*$") then
    fail("Invalid image name: " .. value)
  end
end

local function ensure_safe_existing_dir(label, dir)
  validate_absolute_path(label, dir)
  local mode = lfs.attributes(dir, "mode")
  if not mode or mode ~= "directory" then
    fail("Missing " .. label .. ": " .. dir)
  end
  if lfs.attributes(dir, "type") == "link" then
    fail("Unsafe " .. label .. ": symlinks are not allowed (" .. dir .. ")")
  end
end

local function stat_uid(path)
  local attr = lfs.attributes(path, "uid")
  if attr then
    return tostring(attr)
  end
  return nil
end

local function stat_mode(path)
  local attr = lfs.attributes(path, "permissions")
  if attr then
    return string.sub(attr, -3)
  end
  return nil
end

local function ensure_private_existing_dir_owned_by_user(label, dir)
  local uid = stat_uid(dir)
  if not uid or uid ~= posix.getuid() then
    fail("Unsafe " .. label .. ": not owned by current user (" .. dir .. ")")
  end
  local mode = stat_mode(dir)
  if mode then
    local perms = tonumber(mode, 8)
    if bit.band(perms, 0x12) ~= 0 then  -- Check group/other write permissions
      fail("Unsafe " .. label .. ": group/other writable (" .. dir .. ")")
    end
  end
end

local function ensure_safe_write_file_path(label, file)
  validate_absolute_path(label, file)
  if file_exists(file) then
    local attr = lfs.attributes(file, "type")
    if attr == "link" then
      fail("Unsafe " .. label .. ": symlinks are not allowed (" .. file .. ")")
    end
    if attr ~= "file" then
      fail("Unsafe " .. label .. ": expected a regular file (" .. file .. ")")
    end
  end
  local dir = string.match(file, "(.+)/[^/]*")
  if dir then
    ensure_safe_existing_dir(label .. " parent directory", dir)
  end
end

local function write_file_atomically(file, mode, content)
  ensure_safe_write_file_path("output file", file)
  local dir = string.match(file, "(.+)/[^/]*")
  local tmp = dir .. "/.tmp." .. tostring(math.random(100000))
  local f = io.open(tmp, "w")
  if not f then
    fail("Cannot create temporary file: " .. tmp)
  end
  f:write(content)
  f:close()
  os.rename(tmp, file)
end

local function validate_port(label, value)
  if not string.match(value, "^[0-9]+$") or #value > 5 then
    fail("Invalid " .. label .. ": must be numeric.")
  end
  local numeric = tonumber(value)
  if not numeric or numeric < 1 or numeric > 65535 then
    fail("Invalid " .. label .. ": out of range.")
  end
end

local function escape_sed_replacement_pipe_delim(str)
  return string.gsub(str, "[\\&|]", "\\%0")
end

local function resolve_user_home(user)
  local home = os.getenv("HOME")
  if home and home ~= "" then
    return home
  end
  
  -- Try getent first
  local success, result = execute_command("getent passwd " .. user .. " 2>/dev/null | cut -d: -f6")
  if success and result and trim(result) ~= "" then
    return trim(result)
  end
  
  -- Try /etc/passwd
  if file_exists("/etc/passwd") then
    for line in io.lines("/etc/passwd") do
      local parts = split(line, ":")
      if #parts >= 6 and parts[1] == user then
        return parts[6]
      end
    end
  end
  
  return "/home/" .. user
end

local function generate_token_hex_32()
  if which("openssl") then
    local success, result = execute_command("openssl rand -hex 32 2>/dev/null")
    if success then
      return trim(result)
    end
  end
  
  if which("python3") then
    local success, result = execute_command('python3 -c "import secrets; print(secrets.token_hex(32))"')
    if success then
      return trim(result)
    end
  end
  
  if which("od") then
    local success, result = execute_command("od -An -N32 -tx1 /dev/urandom | tr -d ' \\n'")
    if success then
      return trim(result)
    end
  end
  
  fail("Missing dependency: need openssl or python3 (or od) to generate OPENCLAW_GATEWAY_TOKEN.")
end

local function seed_local_control_ui_origins(file, port)
  ensure_safe_write_file_path("config file", file)
  
  if not which("python3") then
    io.stderr:write("Warning: python3 not found; unable to seed gateway.controlUi.allowedOrigins in " .. file .. ".\n")
    return
  end
  
  local python_script = [[
import json
import sys

path = sys.argv[1]
port = sys.argv[2]
try:
    with open(path, "r", encoding="utf-8") as fh:
        data = json.load(fh)
except json.JSONDecodeError as exc:
    print(
        f"Warning: unable to seed gateway.controlUi.allowedOrigins in {path}: existing config is not strict JSON ({exc}). Leaving file unchanged.",
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
managed_localhosts = {"127.0.0.1", "localhost"}
desired = [
    f"http://127.0.0.1:{port}",
    f"http://localhost:{port}",
]
if not isinstance(allowed, list):
    allowed = []
cleaned = []
for origin in allowed:
    if not isinstance(origin, str):
        continue
    normalized = origin.strip()
    if not normalized:
        continue
    if normalized.startswith("http://"):
        host_port = normalized[len("http://") :]
        host = host_port.split(":", 1)[0]
        if host in managed_localhosts:
            continue
    cleaned.append(normalized)
control_ui["allowedOrigins"] = cleaned + desired
with open(path, "w", encoding="utf-8") as fh:
    json.dump(data, fh, indent=2)
    fh.write("\n")
]]
  
  local tmpfile = os.tmpname()
  local f = io.open(tmpfile, "w")
  f:write(python_script)
  f:close()
  
  local cmd = string.format('python3 %s %s %s', tmpfile, file, port)
  local success = os.execute(cmd)
  os.remove(tmpfile)
  
  if not success then
    return
  end
end

local function upsert_env_var(file, key, value)
  ensure_safe_write_file_path("env file", file)
  local lines = {}
  local found = false
  
  if file_exists(file) then
    for line in io.lines(file) do
      if string.match(line, "^" .. key .. "=") then
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
  
  local content = table.concat(lines, "\n") .. "\n"
  write_file_atomically(file, "600", content)
end

-- Main script logic
local args = {...}
local INSTALL_QUADLET = false

for _, arg in ipairs(args) do
  if arg == "--quadlet" then
    INSTALL_QUADLET = true
  elseif arg == "--container" then
    INSTALL_QUADLET = false
  end
end

local OPENCLAW_PODMAN_QUADLET = os.getenv("OPENCLAW_PODMAN_QUADLET")
if OPENCLAW_PODMAN_QUADLET then
  local lower_val = string.lower(OPENCLAW_PODMAN_QUADLET)
  if lower_val == "1" or lower_val == "yes" or lower_val == "true" then
    INSTALL_QUADLET = true
  elseif lower_val == "0" or lower_val == "no" or lower_val == "false" then
    INSTALL_QUADLET = false
  end
end

local PLATFORM_NAME = "unknown"
local success, result = execute_command("uname -s 2>/dev/null")
if success then
  PLATFORM_NAME = trim(result)
end

if INSTALL_QUADLET and PLATFORM_NAME ~= "Linux" then
  fail("--quadlet is only supported on Linux with systemd user services.")
end

local SEED_GATEWAY_PORT = os.getenv("OPENCLAW_PODMAN_GATEWAY_HOST_PORT") or os.getenv("OPENCLAW_GATEWAY_PORT") or "18789"
if INSTALL_QUADLET then
  SEED_GATEWAY_PORT = "18789"
end

require_cmd("podman")
if is_root() then
  fail("Run scripts/podman/setup.lua as your normal user so Podman stays rootless.")
end

-- Get repository path
local script_path = debug.getinfo(1, "S").source:sub(2)
local REPO_PATH = os.getenv("OPENCLAW_REPO_PATH")
if not REPO_PATH then
  REPO_PATH = script_path:match("(.-)/scripts/podman/setup%.lua$")
  if not REPO_PATH then
    REPO_PATH = "."
  end
end

local RUN_SCRIPT_SRC = REPO_PATH .. "/scripts/run-openclaw-podman.sh"
local QUADLET_TEMPLATE = REPO_PATH .. "/scripts/podman/openclaw.container.in"

if not file_exists(RUN_SCRIPT_SRC) then
  fail("Launch script not found at " .. RUN_SCRIPT_SRC .. ".")
end

local OPENCLAW_IMAGE = os.getenv("OPENCLAW_PODMAN_IMAGE") or os.getenv("OPENCLAW_IMAGE") or "openclaw:local"
if OPENCLAW_IMAGE == "openclaw:local" and not file_exists(REPO_PATH .. "/Dockerfile") then
  fail("Dockerfile not found at " .. REPO_PATH .. ". Set OPENCLAW_REPO_PATH to the repo root.")
end

local OPENCLAW_USER = posix.getlogin() or "unknown"
local OPENCLAW_HOME = os.getenv("HOME") or ""
if OPENCLAW_HOME == "" then
  OPENCLAW_HOME = resolve_user_home(OPENCLAW_USER)
end
if OPENCLAW_HOME == "" then
  fail("Unable to resolve HOME for user " .. OPENCLAW_USER .. ".")
end

local OPENCLAW_CONFIG_DIR = os.getenv("OPENCLAW_CONFIG_DIR") or (OPENCLAW_HOME .. "/.openclaw")
local OPENCLAW_WORKSPACE_DIR = os.getenv("OPENCLAW_WORKSPACE_DIR") or (OPENCLAW_CONFIG_DIR .. "/workspace")
local OPENCLAW_CONTAINER_NAME = os.getenv("OPENCLAW_PODMAN_CONTAINER") or "openclaw"
local HOST_GATEWAY_PORT = os.getenv("OPENCLAW_PODMAN_GATEWAY_HOST_PORT") or os.getenv("OPENCLAW_GATEWAY_PORT") or "18789"

validate_absolute_path("home directory", OPENCLAW_HOME)
validate_mount_source_path("config directory", OPENCLAW_CONFIG_DIR)
validate_mount_source_path("workspace directory", OPENCLAW_WORKSPACE_DIR)
validate_container_name(OPENCLAW_CONTAINER_NAME)
validate_image_name(OPENCLAW_IMAGE)
validate_port("gateway host port", HOST_GATEWAY_PORT)
validate_port("seed gateway port", SEED_GATEWAY_PORT)

-- Create directories
os.execute("install -d -m 700 " .. OPENCLAW_CONFIG_DIR .. " " .. OPENCLAW_WORKSPACE_DIR)
ensure_private_existing_dir_owned_by_user("config directory", OPENCLAW_CONFIG_DIR)
ensure_private_existing_dir_owned_by_user("workspace directory", OPENCLAW_WORKSPACE_DIR)

-- Build or pull image
local BUILD_ARGS = {}
local OPENCLAW_DOCKER_APT_PACKAGES = os.getenv("OPENCLAW_DOCKER_APT_PACKAGES")
if OPENCLAW_DOCKER_APT_PACKAGES then
  table.insert(BUILD_ARGS, "--build-arg OPENCLAW_DOCKER_APT_PACKAGES=" .. OPENCLAW_DOCKER_APT_PACKAGES)
end

local OPENCLAW_EXTENSIONS = os.getenv("OPENCLAW_EXTENSIONS")
if OPENCLAW_EXTENSIONS then
  table.insert(BUILD_ARGS, "--build-arg OPENCLAW_EXTENSIONS=" .. OPENCLAW_EXTENSIONS)
end

if OPENCLAW_IMAGE == "openclaw:local" then
  print("Building image " .. OPENCLAW_IMAGE .. " ...")
  local build_cmd = "podman build -t " .. OPENCLAW_IMAGE .. " -f " .. REPO_PATH .. "/Dockerfile " .. table.concat(BUILD_ARGS, " ") .. " " .. REPO_PATH
  os.execute(build_cmd)
else
  local success, _, code = execute_command("podman image exists " .. OPENCLAW_IMAGE .. " 2>/dev/null")
  if code == 0 then
    print("Using existing image " .. OPENCLAW_IMAGE)
  else
    print("Pulling image " .. OPENCLAW_IMAGE .. " ...")
    os.execute("podman pull " .. OPENCLAW_IMAGE)
  end
end

-- Setup environment file
local ENV_FILE = OPENCLAW_CONFIG_DIR .. "/.env"
if not file_exists(ENV_FILE) then
  local TOKEN = generate_token_hex_32()
  local env_content = "OPENCLAW_GATEWAY_TOKEN=" .. TOKEN .. "\n"
  write_file_atomically(ENV_FILE, "600", env_content)
  print("Generated OPENCLAW_GATEWAY_TOKEN and wrote it to " .. ENV_FILE)
end

upsert_env_var(ENV_FILE, "OPENCLAW_PODMAN_CONTAINER", OPENCLAW_CONTAINER_NAME)
upsert_env_var(ENV_FILE, "OPENCLAW_PODMAN_IMAGE", OPENCLAW_IMAGE)

-- Setup config file
local CONFIG_JSON = OPENCLAW_CONFIG_DIR .. "/openclaw.json"
if not file_exists(CONFIG_JSON) then
  local config_content = [[{
  "gateway": {
    "mode": "local",
    "controlUi": {
      "allowedOrigins": [
        "http://127.0.0.1:]] .. SEED_GATEWAY_PORT .. [[",
        "http://localhost:]] .. SEED_GATEWAY_PORT .. [["
      ]
    }
  }
}]]
  write_file_atomically(CONFIG_JSON, "600", config_content)
  print("Wrote minimal config to " .. CONFIG_JSON)
end

seed_local_control_ui_origins(CONFIG_JSON, SEED_GATEWAY_PORT)

-- Install quadlet if requested
if INSTALL_QUADLET then
  local QUADLET_DIR = OPENCLAW_HOME .. "/.config/containers/systemd"
  local QUADLET_DST = QUADLET_DIR .. "/openclaw.container"
  print("Installing Quadlet to " .. QUADLET_DST .. " ...")
  os.execute("mkdir -p " .. QUADLET_DIR)
  ensure_safe_existing_dir("quadlet directory", QUADLET_DIR)
  
  local template_content = read_file(QUADLET_TEMPLATE)
  if not template_content then
    fail("Cannot read quadlet template: " .. QUADLET_TEMPLATE)
  end
  
  local OPENCLAW_HOME_ESCAPED = escape_sed_replacement_pipe_delim(OPENCLAW_HOME)
  local OPENCLAW_CONFIG_ESCAPED = escape_sed_replacement_pipe_delim(OPENCLAW_CONFIG_DIR)
  local OPENCLAW_WORKSPACE_ESCAPED = escape_sed_replacement_pipe_delim(OPENCLAW_WORKSPACE_DIR)
  local OPENCLAW_IMAGE_ESCAPED = escape_sed_replacement_pipe_delim(OPENCLAW_IMAGE)
  local OPENCLAW_CONTAINER_ESCAPED = escape_sed_replacement_pipe_delim(OPENCLAW_CONTAINER_NAME)
  
  local content = template_content
  content = string.gsub(content, "{{OPENCLAW_HOME}}", OPENCLAW_HOME_ESCAPED)
  content = string.gsub(content, "{{OPENCLAW_CONFIG_DIR}}", OPENCLAW_CONFIG_ESCAPED)
  content = string.gsub(content, "{{OPENCLAW_WORKSPACE_DIR}}", OPENCLAW_WORKSPACE_ESCAPED)
  content = string.gsub(content, "{{IMAGE_NAME}}", OPENCLAW_IMAGE_ESCAPED)
  content = string.gsub(content, "{{CONTAINER_NAME}}", OPENCLAW_CONTAINER_ESCAPED)
  
  write_file_atomically(QUADLET_DST, "644", content)
  
  if which("systemctl") then
    print("Reloading and starting user service...")
    local reload_success = os.execute("systemctl --user daemon-reload")
    local start_success = os.execute("systemctl --user start openclaw.service")
    
    if reload_success and start_success then
      print("Quadlet installed and service started.")
    else
      print("Quadlet installed, but automatic start failed.")
      io.stderr:write("Try: systemctl --user daemon-reload && systemctl --user start openclaw.service\n")
      if which("loginctl") then
        local whoami_success, whoami_result = execute_command("whoami")
        if whoami_success then
          io.stderr:write("For boot persistence on headless hosts, you may also need: sudo loginctl enable-linger " .. trim(whoami_result) .. "\n")
        end
      end
    end
  else
    print("systemctl not found; Quadlet installed but not started.")
  end
else
  print("Container setup complete.")
end

print("")
print("Next:")
print("  ./scripts/run-openclaw-podman.sh launch")
print("  ./scripts/run-openclaw-podman.sh launch setup")
print("  openclaw --container " .. OPENCLAW_CONTAINER_NAME .. " dashboard --no-open")
