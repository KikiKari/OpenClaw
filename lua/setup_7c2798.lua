#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "ca90f357c5b97826fbe0a9d169cb866cc22f6353f4f7a079d474d548dc19507c", "source_sha256": "7c279836c2c2bf7bf1f0cd8868a320423a0e69387a65cec698db01e1d888a57a", "target_language": "lua"}
-- setup.sh — portiert nach lua
-- Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/docker/setup.sh
-- Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

local function fail(msg)
  io.stderr:write("ERROR: " .. msg .. "\n")
  os.exit(1)
end

local function require_cmd(cmd)
  local handle = io.popen("command -v " .. cmd .. " >/dev/null 2>&1; echo $?", "r")
  local result = handle:read("*a")
  handle:close()
  if tonumber(result) ~= 0 then
    io.stderr:write("Missing dependency: " .. cmd .. "\n")
    os.exit(1)
  end
end

local function run_docker_build(...)
  local args = {...}
  local cmd = "DOCKER_BUILDKIT=1 docker build " .. table.concat(args, " ")
  local success = os.execute(cmd)
  if not success then
    fail("Docker build failed")
  end
end

local function is_truthy_value(raw)
  if not raw then return false end
  raw = string.lower(tostring(raw))
  return raw == "1" or raw == "true" or raw == "yes" or raw == "on"
end

local function read_config_gateway_token()
  local config_path = os.getenv("OPENCLAW_CONFIG_DIR") or (os.getenv("HOME") .. "/.openclaw")
  config_path = config_path .. "/openclaw.json"
  
  if not io.open(config_path, "r") then
    return nil
  end
  
  local handle = io.popen("python3 -c 'import json,sys;cfg=json.load(sys.stdin);token=cfg.get(\"gateway\",{}).get(\"auth\",{}).get(\"token\",\"\");print(token)' < " .. config_path .. " 2>/dev/null", "r")
  local result = handle:read("*a"):gsub("^%s*(.-)%s*$", "%1")
  handle:close()
  
  if result and result ~= "" then
    return result
  end
  
  return nil
end

local function read_env_gateway_token(env_path)
  if not io.open(env_path, "r") then
    return nil
  end
  
  for line in io.lines(env_path) do
    line = line:gsub("\r$", "")
    if line:match("^OPENCLAW_GATEWAY_TOKEN=") then
      return line:match("^OPENCLAW_GATEWAY_TOKEN=(.*)$")
    end
  end
  
  return nil
end

local function sync_gateway_config()
  local allowed_origin_json = ""
  local current_allowed_origins = ""
  
  if os.getenv("OPENCLAW_GATEWAY_BIND") ~= "loopback" then
    local port = os.getenv("OPENCLAW_GATEWAY_PORT")
    allowed_origin_json = string.format('["http://localhost:%s","http://127.0.0.1:%s"]', port, port)
    local handle = io.popen("docker compose " .. os.getenv("COMPOSE_ARGS_STR") .. " run --rm --no-deps --entrypoint node openclaw-gateway dist/index.js config get gateway.controlUi.allowedOrigins 2>/dev/null", "r")
    current_allowed_origins = handle:read("*a") or ""
    handle:close()
    current_allowed_origins = current_allowed_origins:gsub("\r", "")
  end
  
  local batch_json = string.format('[{"path":"gateway.mode","value":"local"},{"path":"gateway.bind","value":"%s"}', os.getenv("OPENCLAW_GATEWAY_BIND"))
  if allowed_origin_json ~= "" then
    if current_allowed_origins == "" or current_allowed_origins == "null" or current_allowed_origins == "[]" then
      batch_json = batch_json .. ",{\"path\":\"gateway.controlUi.allowedOrigins\",\"value\":" .. allowed_origin_json .. "}"
    else
      print("Control UI allowlist already configured; leaving gateway.controlUi.allowedOrigins unchanged.")
    end
  end
  batch_json = batch_json .. "]"
  
  local cmd = "docker compose " .. os.getenv("COMPOSE_ARGS_STR") .. " run --rm --no-deps --entrypoint node openclaw-gateway dist/index.js config set --batch-json '" .. batch_json .. "' >/dev/null"
  os.execute(cmd)
  
  print("Pinned gateway.mode=local and gateway.bind=" .. os.getenv("OPENCLAW_GATEWAY_BIND") .. " for Docker setup.")
  if allowed_origin_json ~= "" then
    if current_allowed_origins == "" or current_allowed_origins == "null" or current_allowed_origins == "[]" then
      print("Set gateway.controlUi.allowedOrigins to " .. allowed_origin_json .. " for non-loopback bind.")
    end
  end
end

local function run_prestart_gateway(...)
  local args = {...}
  local cmd = "docker compose " .. os.getenv("COMPOSE_ARGS_STR") .. " run --rm --no-deps " .. table.concat(args, " ")
  os.execute(cmd)
end

local function run_prestart_cli(...)
  local args = {...}
  local cmd = "docker compose " .. os.getenv("COMPOSE_ARGS_STR") .. " run --rm --no-deps --entrypoint node openclaw-gateway dist/index.js " .. table.concat(args, " ")
  os.execute(cmd)
end

local function run_runtime_cli(compose_scope, deps_mode, ...)
  local args = {...}
  local compose_args = ""
  local run_args = "run --rm"
  
  if compose_scope == "base" then
    compose_args = os.getenv("BASE_COMPOSE_ARGS_STR") or ""
  else
    compose_args = os.getenv("COMPOSE_ARGS_STR") or ""
  end
  
  if deps_mode == "no-deps" then
    run_args = run_args .. " --no-deps"
  end
  
  local cmd = "docker compose " .. compose_args .. " " .. run_args .. " openclaw-cli " .. table.concat(args, " ")
  os.execute(cmd)
end

local function contains_disallowed_chars(value)
  return string.find(value, "[\n\r\t]") ~= nil
end

local function is_valid_timezone(value)
  local handle = io.open("/usr/share/zoneinfo/" .. value, "r")
  if handle then
    handle:close()
    return true
  end
  return false
end

local function validate_mount_path_value(label, value)
  if value == "" then
    fail(label .. " cannot be empty.")
  end
  if contains_disallowed_chars(value) then
    fail(label .. " contains unsupported control characters.")
  end
  if string.find(value, "%s") then
    fail(label .. " cannot contain whitespace.")
  end
end

local function validate_named_volume(value)
  if not string.match(value, "^[A-Za-z0-9][A-Za-z0-9_.-]*$") then
    fail("OPENCLAW_HOME_VOLUME must match [A-Za-z0-9][A-Za-z0-9_.-]* when using a named volume.")
  end
end

local function validate_mount_spec(mount)
  if contains_disallowed_chars(mount) then
    fail("OPENCLAW_EXTRA_MOUNTS entries cannot contain control characters.")
  end
  if not string.match(mount, "^[^%s,:]+:[^%s,:]+(:[^%s,:]+)?$") then
    fail("Invalid mount format '" .. mount .. "'. Expected source:target[:options] without spaces.")
  end
end

require_cmd("docker")
local handle = io.popen("docker compose version >/dev/null 2>&1; echo $?", "r")
local result = handle:read("*a")
handle:close()
if tonumber(result) ~= 0 then
  io.stderr:write("Docker Compose not available (try: docker compose version)\n")
  os.exit(1)
end

local DOCKER_SOCKET_PATH = os.getenv("OPENCLAW_DOCKER_SOCKET") or ""
if DOCKER_SOCKET_PATH == "" and (os.getenv("DOCKER_HOST") or ""):match("^unix://") then
  DOCKER_SOCKET_PATH = os.getenv("DOCKER_HOST"):sub(7)
end
if DOCKER_SOCKET_PATH == "" then
  DOCKER_SOCKET_PATH = "/var/run/docker.sock"
end

local RAW_SANDBOX_SETTING = os.getenv("OPENCLAW_SANDBOX") or ""
local SANDBOX_ENABLED = ""
if is_truthy_value(RAW_SANDBOX_SETTING) then
  SANDBOX_ENABLED = "1"
end

local OPENCLAW_CONFIG_DIR = os.getenv("OPENCLAW_CONFIG_DIR") or (os.getenv("HOME") .. "/.openclaw")
local OPENCLAW_WORKSPACE_DIR = os.getenv("OPENCLAW_WORKSPACE_DIR") or (OPENCLAW_CONFIG_DIR .. "/workspace")

validate_mount_path_value("OPENCLAW_CONFIG_DIR", OPENCLAW_CONFIG_DIR)
validate_mount_path_value("OPENCLAW_WORKSPACE_DIR", OPENCLAW_WORKSPACE_DIR)

local HOME_VOLUME_NAME = os.getenv("OPENCLAW_HOME_VOLUME") or ""
if HOME_VOLUME_NAME ~= "" then
  if string.find(HOME_VOLUME_NAME, "/") then
    validate_mount_path_value("OPENCLAW_HOME_VOLUME", HOME_VOLUME_NAME)
  else
    validate_named_volume(HOME_VOLUME_NAME)
  end
end

local EXTRA_MOUNTS = os.getenv("OPENCLAW_EXTRA_MOUNTS") or ""
if contains_disallowed_chars(EXTRA_MOUNTS) then
  fail("OPENCLAW_EXTRA_MOUNTS cannot contain control characters.")
end
if SANDBOX_ENABLED ~= "" then
  validate_mount_path_value("OPENCLAW_DOCKER_SOCKET", DOCKER_SOCKET_PATH)
end

local TIMEZONE = os.getenv("OPENCLAW_TZ") or ""
if TIMEZONE ~= "" then
  if contains_disallowed_chars(TIMEZONE) then
    fail("OPENCLAW_TZ contains unsupported control characters.")
  end
  if not string.match(TIMEZONE, "^[A-Za-z0-9/_+-]+$") then
    fail("OPENCLAW_TZ must be a valid IANA timezone string (e.g. Asia/Shanghai).")
  end
  if not is_valid_timezone(TIMEZONE) then
    fail("OPENCLAW_TZ must match a timezone in /usr/share/zoneinfo (e.g. Asia/Shanghai).")
  end
end

os.execute("mkdir -p " .. OPENCLAW_CONFIG_DIR)
os.execute("mkdir -p " .. OPENCLAW_WORKSPACE_DIR)
os.execute("mkdir -p " .. OPENCLAW_CONFIG_DIR .. "/identity")
os.execute("mkdir -p " .. OPENCLAW_CONFIG_DIR .. "/agents/main/agent")
os.execute("mkdir -p " .. OPENCLAW_CONFIG_DIR .. "/agents/main/sessions")

os.setenv("OPENCLAW_CONFIG_DIR", OPENCLAW_CONFIG_DIR)
os.setenv("OPENCLAW_WORKSPACE_DIR", OPENCLAW_WORKSPACE_DIR)
os.setenv("OPENCLAW_GATEWAY_PORT", os.getenv("OPENCLAW_GATEWAY_PORT") or "18789")
os.setenv("OPENCLAW_BRIDGE_PORT", os.getenv("OPENCLAW_BRIDGE_PORT") or "18790")
os.setenv("OPENCLAW_GATEWAY_BIND", os.getenv("OPENCLAW_GATEWAY_BIND") or "lan")
os.setenv("OPENCLAW_IMAGE", os.getenv("OPENCLAW_IMAGE") or "openclaw:local")
os.setenv("OPENCLAW_DOCKER_APT_PACKAGES", os.getenv("OPENCLAW_DOCKER_APT_PACKAGES") or "")
os.setenv("OPENCLAW_EXTENSIONS", os.getenv("OPENCLAW_EXTENSIONS") or "")
os.setenv("OPENCLAW_EXTRA_MOUNTS", EXTRA_MOUNTS)
os.setenv("OPENCLAW_HOME_VOLUME", HOME_VOLUME_NAME)
os.setenv("OPENCLAW_ALLOW_INSECURE_PRIVATE_WS", os.getenv("OPENCLAW_ALLOW_INSECURE_PRIVATE_WS") or "")
os.setenv("OPENCLAW_SANDBOX", SANDBOX_ENABLED)
os.setenv("OPENCLAW_DOCKER_SOCKET", DOCKER_SOCKET_PATH)
os.setenv("OPENCLAW_TZ", TIMEZONE)

local DOCKER_GID = ""
if SANDBOX_ENABLED ~= "" and os.execute("[ -S " .. DOCKER_SOCKET_PATH .. " ]") then
  local handle = io.popen("stat -c '%g' " .. DOCKER_SOCKET_PATH .. " 2>/dev/null || stat -f '%g' " .. DOCKER_SOCKET_PATH .. " 2>/dev/null || echo ''", "r")
  DOCKER_GID = handle:read("*l") or ""
  handle:close()
end
os.setenv("DOCKER_GID", DOCKER_GID)

local OPENCLAW_GATEWAY_TOKEN = os.getenv("OPENCLAW_GATEWAY_TOKEN") or ""
if OPENCLAW_GATEWAY_TOKEN == "" then
  local EXISTING_CONFIG_TOKEN = read_config_gateway_token() or ""
  if EXISTING_CONFIG_TOKEN ~= "" then
    OPENCLAW_GATEWAY_TOKEN = EXISTING_CONFIG_TOKEN
    print("Reusing gateway token from " .. OPENCLAW_CONFIG_DIR .. "/openclaw.json")
  else
    local DOTENV_GATEWAY_TOKEN = read_env_gateway_token(os.getenv("PWD") .. "/.env") or ""
    if DOTENV_GATEWAY_TOKEN ~= "" then
      OPENCLAW_GATEWAY_TOKEN = DOTENV_GATEWAY_TOKEN
      print("Reusing gateway token from .env")
    elseif os.execute("command -v openssl >/dev/null 2>&1") then
      local handle = io.popen("openssl rand -hex 32", "r")
      OPENCLAW_GATEWAY_TOKEN = handle:read("*l")
      handle:close()
    else
      local handle = io.popen("python3 -c 'import secrets; print(secrets.token_hex(32))'", "r")
      OPENCLAW_GATEWAY_TOKEN = handle:read("*l")
      handle:close()
    end
  end
end
os.setenv("OPENCLAW_GATEWAY_TOKEN", OPENCLAW_GATEWAY_TOKEN)

local ROOT_DIR = os.getenv("PWD") .. "/../.."
local COMPOSE_FILE = ROOT_DIR .. "/docker-compose.yml"
local EXTRA_COMPOSE_FILE = ROOT_DIR .. "/docker-compose.extra.yml"

local COMPOSE_FILES = {COMPOSE_FILE}
local COMPOSE_ARGS = {}

local function write_extra_compose(home_volume, ...)
  local mounts = {...}
  local file = io.open(EXTRA_COMPOSE_FILE, "w")
  
  file:write([[
services:
  openclaw-gateway:
    volumes:
]])
  
  if home_volume ~= "" then
    local gateway_home_mount = home_volume .. ":/home/node"
    local gateway_config_mount = OPENCLAW_CONFIG_DIR .. ":/home/node/.openclaw"
    local gateway_workspace_mount = OPENCLAW_WORKSPACE_DIR .. ":/home/node/.openclaw/workspace"
    validate_mount_spec(gateway_home_mount)
    validate_mount_spec(gateway_config_mount)
    validate_mount_spec(gateway_workspace_mount)
    file:write("      - " .. gateway_home_mount .. "\n")
    file:write("      - " .. gateway_config_mount .. "\n")
    file:write("      - " .. gateway_workspace_mount .. "\n")
  end
  
  for _, mount in ipairs(mounts) do
    validate_mount_spec(mount)
    file:write("      - " .. mount .. "\n")
  end
  
  file:write([[
  openclaw-cli:
    volumes:
]])
  
  if home_volume ~= "" then
    file:write("      - " .. gateway_home_mount .. "\n")
    file:write("      - " .. gateway_config_mount .. "\n")
    file:write("      - " .. gateway_workspace_mount .. "\n")
  end
  
  for _, mount in ipairs(mounts) do
    validate_mount_spec(mount)
    file:write("      - " .. mount .. "\n")
  end
  
  if home_volume ~= "" and not string.find(home_volume, "/") then
    validate_named_volume(home_volume)
    file:write("volumes:\n  " .. home_volume .. ":\n")
  end
  
  file:close()
end

if SANDBOX_ENABLED ~= "" then
  if os.getenv("OPENCLAW_INSTALL_DOCKER_CLI") == nil or os.getenv("OPENCLAW_INSTALL_DOCKER_CLI") == "" then
    os.setenv("OPENCLAW_INSTALL_DOCKER_CLI", "1")
  end
end

local VALID_MOUNTS = {}
if EXTRA_MOUNTS ~= "" then
  for mount in string.gmatch(EXTRA_MOUNTS, "[^,]+") do
    mount = mount:match("^%s*(.-)%s*$")
    if mount ~= "" then
      table.insert(VALID_MOUNTS, mount)
    end
  end
end

if HOME_VOLUME_NAME ~= "" or #VALID_MOUNTS > 0 then
  if #VALID_MOUNTS > 0 then
    write_extra_compose(HOME_VOLUME_NAME, table.unpack(VALID_MOUNTS))
  else
    write_extra_compose(HOME_VOLUME_NAME)
  end
  table.insert(COMPOSE_FILES, EXTRA_COMPOSE_FILE)
end

local COMPOSE_ARGS_STR = ""
for _, compose_file in ipairs(COMPOSE_FILES) do
  COMPOSE_ARGS_STR = COMPOSE_ARGS_STR .. "-f " .. compose_file .. " "
  table.insert(COMPOSE_ARGS, "-f")
  table.insert(COMPOSE_ARGS, compose_file)
end
os.setenv("COMPOSE_ARGS_STR", COMPOSE_ARGS_STR)

local BASE_COMPOSE_ARGS_STR = COMPOSE_ARGS_STR
os.setenv("BASE_COMPOSE_ARGS_STR", BASE_COMPOSE_ARGS_STR)

local ENV_FILE = ROOT_DIR .. "/.env"
local function upsert_env(file, ...)
  local keys = {...}
  local tmp_file = os.tmpname()
  local tmp = io.open(tmp_file, "w")
  local seen = " "
  
  if io.open(file, "r") then
    for line in io.lines(file) do
      local key = line:match("^([^=]+)")
      local replaced = false
      for _, k in ipairs(keys) do
        if key == k then
          tmp:write(k .. "=" .. (os.getenv(k) or "") .. "\n")
          seen = seen .. k .. " "
          replaced = true
          break
        end
      end
      if not replaced then
        tmp:write(line .. "\n")
      end
    end
  end
  
  for _, k in ipairs(keys) do
    if not string.find(seen, " " .. k .. " ") then
      tmp:write(k .. "=" .. (os.getenv(k) or "") .. "\n")
    end
  end
  
  tmp:close()
  os.rename(tmp_file, file)
end

upsert_env(ENV_FILE,
  "OPENCLAW_CONFIG_DIR",
  "OPENCLAW_WORKSPACE_DIR",
  "OPENCLAW_GATEWAY_PORT",
  "OPENCLAW_BRIDGE_PORT",
  "OPENCLAW_GATEWAY_BIND",
  "OPENCLAW_GATEWAY_TOKEN",
  "OPENCLAW_IMAGE",
  "OPENCLAW_EXTRA_MOUNTS",
  "OPENCLAW_HOME_VOLUME",
  "OPENCLAW_DOCKER_APT_PACKAGES",
  "OPENCLAW_EXTENSIONS",
  "OPENCLAW_SANDBOX",
  "OPENCLAW_DOCKER_SOCKET",
  "DOCKER_GID",
  "OPENCLAW_INSTALL_DOCKER_CLI",
  "OPENCLAW_ALLOW_INSECURE_PRIVATE_WS",
  "OPENCLAW_TZ"
)

local IMAGE_NAME = os.getenv("OPENCLAW_IMAGE")
if IMAGE_NAME == "openclaw:local" then
  print("==> Building Docker image: " .. IMAGE_NAME)
  run_docker_build(
    "--build-arg", "OPENCLAW_DOCKER_APT_PACKAGES=" .. os.getenv("OPENCLAW_DOCKER_APT_PACKAGES"),
    "--build-arg", "OPENCLAW_EXTENSIONS=" .. os.getenv("OPENCLAW_EXTENSIONS"),
    "--build-arg", "OPENCLAW_INSTALL_DOCKER_CLI=" .. (os.getenv("OPENCLAW_INSTALL_DOCKER_CLI") or ""),
    "-t", IMAGE_NAME,
    "-f", ROOT_DIR .. "/Dockerfile",
    ROOT_DIR
  )
else
  print("==> Pulling Docker image: " .. IMAGE_NAME)
  local success = os.execute("docker pull " .. IMAGE_NAME)
  if not success then
    fail("Failed to pull image " .. IMAGE_NAME .. ". Please check the image name and your access permissions.")
  end
end

print("")
print("==> Fixing data-directory permissions")
run_prestart_gateway("--user", "root", "--entrypoint", "sh", "openclaw-gateway", "-c",
  'find /home/node/.openclaw -xdev -exec chown node:node {} +; [ -d /home/node/.openclaw/workspace/.openclaw ] && chown -R node:node /home/node/.openclaw/workspace/.openclaw || true')

print("")
print("==> Onboarding (interactive)")
print("Docker setup pins Gateway mode to local.")
print("Gateway runtime bind comes from OPENCLAW_GATEWAY_BIND (default: lan).")
print("Current runtime bind: " .. os.getenv("OPENCLAW_GATEWAY_BIND"))
print("Gateway token: " .. OPENCLAW_GATEWAY_TOKEN)
print("Tailscale exposure: Off (use host-level tailnet/Tailscale setup separately).")
print("Install Gateway daemon: No (managed by Docker Compose)")
print("")
run_prestart_cli("onboard", "--mode", "local", "--no-install-daemon")

print("")
print("==> Docker gateway defaults")
sync_gateway_config()

print("")
print("==> Provider setup (optional)")
print("WhatsApp (QR):")
print("  docker compose " .. COMPOSE_ARGS_STR .. " run --rm openclaw-cli channels login")
print("Telegram (bot token):")
print("  docker compose " .. COMPOSE_ARGS_STR .. " run --rm openclaw-cli channels add --channel telegram --token <token>")
print("Discord (bot token):")
print("  docker compose " .. COMPOSE_ARGS_STR .. " run --rm openclaw-cli channels add --channel discord --token <token>")
print("Docs: https://docs.openclaw.ai/channels")

print("")
print("==> Starting gateway")
os.execute("docker compose " .. COMPOSE_ARGS_STR .. " up -d openclaw-gateway")

if SANDBOX_ENABLED ~= "" then
  print("")
  print("==> Sandbox setup")
  
  if io.open(ROOT_DIR .. "/Dockerfile.sandbox", "r") then
    print("Building sandbox image: openclaw-sandbox:bookworm-slim")
    run_docker_build(
      "-t", "openclaw-sandbox:bookworm-slim",
      "-f", ROOT_DIR .. "/Dockerfile.sandbox",
      ROOT_DIR
    )
  else
    print("WARNING: Dockerfile.sandbox not found in " .. ROOT_DIR)
    print("  Sandbox config will be applied but no sandbox image will be built.")
    print("  Agent exec may fail if the configured sandbox image does not exist.")
  end
  
  if not os.execute("docker compose " .. COMPOSE_ARGS_STR .. " run --rm --entrypoint docker openclaw-gateway --version >/dev/null 2>&1") then
    print("WARNING: Docker CLI not found inside the container image.")
    print("  Sandbox requires Docker CLI. Rebuild with --build-arg OPENCLAW_INSTALL_DOCKER_CLI=1")
    print("  or use a local build (OPENCLAW_IMAGE=openclaw:local). Skipping sandbox setup.")
    SANDBOX_ENABLED = ""
  end
end

if SANDBOX_ENABLED ~= "" then
  local SANDBOX_COMPOSE_FILE = ROOT_DIR .. "/docker-compose.sandbox.yml"
  if os.execute("[ -S " .. DOCKER_SOCKET_PATH .. " ]") then
    local file = io.open(SANDBOX_COMPOSE_FILE, "w")
    file:write("services:\n  openclaw-gateway:\n    volumes:\n      - " .. DOCKER_SOCKET_PATH .. ":/var/run/docker.sock\n")
    if os.getenv("DOCKER_GID") ~= "" then
      file:write("    group_add:\n      - \"" .. os.getenv("DOCKER_GID") .. "\"\n")
    end
    file:close()
    COMPOSE_ARGS_STR = COMPOSE_ARGS_STR .. "-f " .. SANDBOX_COMPOSE_FILE .. " "
    print("==> Sandbox: added Docker socket mount")
  else
    print("WARNING: OPENCLAW_SANDBOX enabled but Docker socket not found at " .. DOCKER_SOCKET_PATH .. ".")
    print("  Sandbox requires Docker socket access. Skipping sandbox setup.")
    SANDBOX_ENABLED = ""
  end
end

if SANDBOX_ENABLED ~= "" then
  local sandbox_config_ok = true
  if not os.execute("docker compose " .. COMPOSE_ARGS_STR .. " run --rm --entrypoint node openclaw-gateway dist/index.js config set agents.defaults.sandbox.mode \"non-main\" >/dev/null") then
    print("WARNING: Failed to set agents.defaults.sandbox.mode")
    sandbox_config_ok = false
  end
  if not os.execute("docker compose " .. COMPOSE_ARGS_STR .. " run --rm --entrypoint node openclaw-gateway dist/index.js config set agents.defaults.sandbox.scope \"agent\" >/dev/null") then
    print("WARNING: Failed to set agents.defaults.sandbox.scope")
    sandbox_config_ok = false
  end
  if not os.execute("docker compose " .. COMPOSE_ARGS_STR .. " run --rm --entrypoint node openclaw-gateway dist/index.js config set agents.defaults.sandbox.workspaceAccess \"none\" >/dev/null") then
    print("WARNING: Failed to set agents.defaults.sandbox.workspaceAccess")
    sandbox_config_ok = false
  end
  
  if sandbox_config_ok then
    print("Sandbox enabled: mode=non-main, scope=agent, workspaceAccess=none")
    print("Docs: https://docs.openclaw.ai/gateway/sandboxing")
    os.execute("docker compose " .. COMPOSE_ARGS_STR .. " up -d openclaw-gateway")
  else
    print("WARNING: Sandbox config was partially applied. Check errors above.")
    print("  Skipping gateway restart to avoid exposing Docker socket without a full sandbox policy.")
    if os.execute("docker compose " .. BASE_COMPOSE_ARGS_STR .. " run --rm --entrypoint node openclaw-gateway dist/index.js config set agents.defaults.sandbox.mode \"off\" >/dev/null") then
      print("Sandbox mode rolled back to off due to partial sandbox config failure.")
    else
      print("WARNING: Failed to roll back agents.defaults.sandbox.mode to off")
    end
    if os.execute("[ -f " .. SANDBOX_COMPOSE_FILE .. " ]") then
      os.remove(SANDBOX_COMPOSE_FILE)
    end
    os.execute("docker compose " .. BASE_COMPOSE_ARGS_STR .. " up -d --force-recreate openclaw-gateway")
  end
else
  if not os.execute("docker compose " .. COMPOSE_ARGS_STR .. " run --rm --entrypoint node openclaw-gateway dist/index.js config set agents.defaults.sandbox.mode \"off\" >/dev/null") then
    print("WARNING: Failed to reset agents.defaults.sandbox.mode to off")
  end
  if os.execute("[ -f " .. ROOT_DIR .. "/docker-compose.sandbox.yml ]") then
    os.remove(ROOT_DIR .. "/docker-compose.sandbox.yml")
  end
end

print("")
print("Gateway running with host port mapping.")
print("Access from tailnet devices via the host's tailnet IP.")
print("Config: " .. OPENCLAW_CONFIG_DIR)
print("Workspace: " .. OPENCLAW_WORKSPACE_DIR)
print("Token: " .. OPENCLAW_GATEWAY_TOKEN)
print("")
print("Commands:")
print("  docker compose " .. COMPOSE_ARGS_STR .. " logs -f openclaw-gateway")
print("  docker compose " .. COMPOSE_ARGS_STR .. " exec openclaw-gateway node dist/index.js health --token \"" .. OPENCLAW_GATEWAY_TOKEN .. "\"")
