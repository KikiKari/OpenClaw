#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "a1ede39307d4b2be017d0e1b55aae4608ef4907f647ef45644546c1dd7a81791", "source_sha256": "fbf046d1988d19407db864ee85d468151b410a1dc1cab4374f1f8119c6fb9897", "target_language": "lua"}
-- restart-mac.sh — portiert nach lua
-- Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/restart-mac.sh
-- Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

local function basename(str)
  local name = string.gsub(str, "(.*[/\\])(.*)", "%2")
  return name
end

local function dirname(str)
  local dir = string.gsub(str, "[/\\][^/\\]+$", "")
  return dir
end

local function readfile(path)
  local file = io.open(path, "r")
  if not file then return nil end
  local content = file:read("*all")
  file:close()
  return content
end

local function writefile(path, content)
  local file = io.open(path, "w")
  if not file then return false end
  file:write(content)
  file:close()
  return true
end

local function which(name)
  local path = os.getenv("PATH") or "/usr/bin:/bin"
  for dir in string.gmatch(path, "[^:]+") do
    local fullpath = dir .. "/" .. name
    local stat = io.open(fullpath, "r")
    if stat then
      stat:close()
      return fullpath
    end
  end
  return nil
end

local function execute(cmd)
  local handle = io.popen(cmd)
  local result = handle:read("*a")
  local success, exit_code, signal = handle:close()
  return result, success, exit_code
end

local function split(str, sep)
  local fields = {}
  str:gsub("([^"..sep.."]*)"..sep, function(c) table.insert(fields, c) end)
  table.insert(fields, str:match("[^"..sep.."]*$"))
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

local function contains(haystack, needle)
  return string.find(haystack, needle) ~= nil
end

local function hash_sha256(data)
  local sha = require("openssl").digest.new("sha256")
  sha:update(data)
  return sha:final():sub(1, 8)
end

local function log(msg)
  print(msg)
end

local function fail(msg)
  io.stderr:write("ERROR: " .. msg .. "\n")
  os.exit(1)
end

local function run_step(label, cmd)
  log("==> " .. label)
  local result, success, exit_code = execute(cmd)
  if not success then
    fail(label .. " failed")
  end
  return result
end

local script_path = arg[0]
local root_dir = dirname(dirname(script_path))

local app_bundle = os.getenv("OPENCLAW_APP_BUNDLE") or ""
local app_process_pattern = "OpenClaw.app/Contents/MacOS/OpenClaw"
local debug_process_pattern = root_dir .. "/apps/macos/.build/debug/OpenClaw"
local local_process_pattern = root_dir .. "/apps/macos/.build-local/debug/OpenClaw"
local release_process_pattern = root_dir .. "/apps/macos/.build/release/OpenClaw"
local launch_agent = os.getenv("HOME") .. "/Library/LaunchAgents/ai.openclaw.mac.plist"
local lock_key = hash_sha256(root_dir)
local tmpdir = os.getenv("TMPDIR") or "/tmp"
local lock_dir = tmpdir .. "/openclaw-restart-" .. lock_key
local lock_pid_file = lock_dir .. "/pid"
local wait_for_lock = false
local log_path = os.getenv("OPENCLAW_RESTART_LOG") or "/tmp/openclaw-restart.log"
local no_sign = false
local sign = false
local auto_detect_signing = true
local gateway_wait_seconds = tonumber(os.getenv("OPENCLAW_GATEWAY_WAIT_SECONDS")) or 0
local launchagent_disable_marker = os.getenv("HOME") .. "/.openclaw/disable-launchagent"
local attach_only = true

os.execute("export PATH=\"" .. root_dir .. "/node_modules/.bin:$PATH\"")

local function cleanup()
  os.remove(lock_dir)
end

local function acquire_lock()
  while true do
    local mkdir_result = os.execute("mkdir " .. lock_dir .. " 2>/dev/null")
    if mkdir_result == 0 then
      local pid_file = io.open(lock_pid_file, "w")
      if pid_file then
        pid_file:write(tostring(os.getpid()))
        pid_file:close()
      end
      return
    end

    local existing_pid = ""
    local pid_content = readfile(lock_pid_file)
    if pid_content then
      existing_pid = trim(pid_content)
    end

    if existing_pid ~= "" then
      local kill_result = os.execute("kill -0 " .. existing_pid .. " 2>/dev/null")
      if kill_result == 0 then
        if wait_for_lock then
          log("==> Another restart is running (pid " .. existing_pid .. "); waiting...")
          while os.execute("kill -0 " .. existing_pid .. " 2>/dev/null") == 0 do
            os.execute("sleep 1")
          end
        else
          log("==> Another restart is running (pid " .. existing_pid .. "); re-run with --wait.")
          os.exit(0)
        end
      end
    end

    os.execute("rm -rf " .. lock_dir)
  end
end

local function check_signing_keys()
  local result, success = execute("security find-identity -p codesigning -v 2>/dev/null")
  if success and (contains(result, "Developer ID Application") or 
                  contains(result, "Apple Distribution") or 
                  contains(result, "Apple Development")) then
    return true
  end
  return false
end

for _, arg in ipairs(arg) do
  if arg == "--wait" or arg == "-w" then
    wait_for_lock = true
  elseif arg == "--no-sign" then
    no_sign = true
    auto_detect_signing = false
  elseif arg == "--sign" then
    sign = true
    auto_detect_signing = false
  elseif arg == "--attach-only" then
    attach_only = true
  elseif arg == "--no-attach-only" then
    attach_only = false
  elseif arg == "--help" or arg == "-h" then
    log("Usage: " .. basename(script_path) .. " [--wait] [--no-sign] [--sign] [--attach-only|--no-attach-only]")
    log("  --wait    Wait for other restart to complete instead of exiting")
    log("  --no-sign Force no code signing (fastest for development)")
    log("  --sign    Force code signing (will fail if no signing key available)")
    log("  --attach-only    Launch app with --attach-only (skip launchd install)")
    log("  --no-attach-only Launch app without attach-only override")
    log("")
    log("Env:")
    log("  OPENCLAW_GATEWAY_WAIT_SECONDS=0  Wait time before gateway port check (unsigned only)")
    log("")
    log("Unsigned recovery:")
    log("  node openclaw.mjs daemon install --force --runtime node")
    log("  node openclaw.mjs daemon restart")
    log("")
    log("Reset unsigned overrides:")
    log("  rm ~/.openclaw/disable-launchagent")
    log("")
    log("Default behavior: Auto-detect signing keys, fallback to --no-sign if none found")
    os.exit(0)
  end
end

if no_sign and sign then
  fail("Cannot use --sign and --no-sign together")
end

os.execute("mkdir -p \"" .. dirname(log_path) .. "\"")
os.execute("rm -f \"" .. log_path .. "\"")
-- Note: Lua doesn't support redirecting stdout/stderr easily, so we'll just print to console

log("==> Log: " .. log_path)
if no_sign then
  log("==> Using --no-sign (unsigned flow enabled)")
end
if attach_only then
  log("==> Using --attach-only (skip launchd install)")
end

acquire_lock()

local function kill_all_openclaw()
  for i = 1, 10 do
    os.execute("pkill -f \"" .. app_process_pattern .. "\" 2>/dev/null || true")
    os.execute("pkill -f \"" .. debug_process_pattern .. "\" 2>/dev/null || true")
    os.execute("pkill -f \"" .. local_process_pattern .. "\" 2>/dev/null || true")
    os.execute("pkill -f \"" .. release_process_pattern .. "\" 2>/dev/null || true")
    os.execute("pkill -x \"OpenClaw\" 2>/dev/null || true")
    
    local pgrep_result = os.execute("pgrep -f \"" .. app_process_pattern .. "\" >/dev/null 2>&1")
    if pgrep_result ~= 0 then
      pgrep_result = os.execute("pgrep -f \"" .. debug_process_pattern .. "\" >/dev/null 2>&1")
    end
    if pgrep_result ~= 0 then
      pgrep_result = os.execute("pgrep -f \"" .. local_process_pattern .. "\" >/dev/null 2>&1")
    end
    if pgrep_result ~= 0 then
      pgrep_result = os.execute("pgrep -f \"" .. release_process_pattern .. "\" >/dev/null 2>&1")
    end
    if pgrep_result ~= 0 then
      pgrep_result = os.execute("pgrep -x \"OpenClaw\" >/dev/null 2>&1")
    end
    
    if pgrep_result ~= 0 then
      return
    end
    os.execute("sleep 0.3")
  end
end

local function stop_launch_agent()
  os.execute("launchctl bootout gui/\"$UID\"/ai.openclaw.mac 2>/dev/null || true")
end

log("==> Killing existing OpenClaw instances")
kill_all_openclaw()
stop_launch_agent()

run_step("bundle canvas a2ui", "bash -lc \"cd '" .. root_dir .. "' && pnpm canvas:a2ui:bundle\"")

run_step("clean build cache", "bash -lc \"cd '" .. root_dir .. "/apps/macos' && rm -rf .build .build-swift .swiftpm 2>/dev/null || true\"")
run_step("swift build", "bash -lc \"cd '" .. root_dir .. "/apps/macos' && swift build -q --product OpenClaw\"")

if auto_detect_signing then
  if check_signing_keys() then
    log("==> Signing keys detected, will code sign")
    sign = true
  else
    log("==> No signing keys found, will skip code signing (--no-sign)")
    no_sign = true
  end
end

local function choose_app_bundle()
  if app_bundle ~= "" and os.execute("test -d \"" .. app_bundle .. "\"") == 0 then
    return
  end

  if os.execute("test -d \"/Applications/OpenClaw.app\"") == 0 then
    app_bundle = "/Applications/OpenClaw.app"
    return
  end

  if os.execute("test -d \"" .. root_dir .. "/dist/OpenClaw.app\"") == 0 then
    app_bundle = root_dir .. "/dist/OpenClaw.app"
    if os.execute("test -d \"" .. app_bundle .. "/Contents/Frameworks/Sparkle.framework\"") ~= 0 then
      fail("dist/OpenClaw.app missing Sparkle after packaging")
    end
    return
  end

  fail("App bundle not found. Set OPENCLAW_APP_BUNDLE to your installed OpenClaw.app")
end

if no_sign then
  os.execute("export ALLOW_ADHOC_SIGNING=1")
  os.execute("export SIGN_IDENTITY=\"-\"")
  os.execute("mkdir -p \"" .. os.getenv("HOME") .. "/.openclaw\"")
  run_step("disable launchagent writes", "/usr/bin/touch \"" .. launchagent_disable_marker .. "\"")
elseif sign then
  if not check_signing_keys() then
    fail("No signing identity found. Use --no-sign or install a signing key.")
  end
  os.execute("unset ALLOW_ADHOC_SIGNING")
  os.execute("unset SIGN_IDENTITY")
end

run_step("package app", "bash -lc \"cd '" .. root_dir .. "' && SKIP_TSC=${SKIP_TSC:-1} '" .. root_dir .. "/scripts/package-mac-app.sh'\"")

choose_app_bundle()

if not no_sign and not attach_only and os.execute("test -f \"" .. launchagent_disable_marker .. "\"") == 0 then
  run_step("clear launchagent disable marker", "/bin/rm -f \"" .. launchagent_disable_marker .. "\"")
end

if no_sign and not attach_only then
  run_step("install gateway launch agent (unsigned)", "bash -lc \"cd '" .. root_dir .. "' && node openclaw.mjs daemon install --force --runtime node\"")
  run_step("restart gateway daemon (unsigned)", "bash -lc \"cd '" .. root_dir .. "' && node openclaw.mjs daemon restart\"")
  if gateway_wait_seconds > 0 then
    run_step("wait for gateway (unsigned)", "sleep " .. tostring(gateway_wait_seconds))
  end
  
  local gateway_port_cmd = [[
    node -e '
      const fs = require("node:fs");
      const path = require("node:path");
      try {
        const raw = fs.readFileSync(path.join(process.env.HOME, ".openclaw", "openclaw.json"), "utf8");
        const cfg = JSON.parse(raw);
        const port = cfg && cfg.gateway && typeof cfg.gateway.port === "number" ? cfg.gateway.port : 18789;
        process.stdout.write(String(port));
      } catch {
        process.stdout.write("18789");
      }
    '
  ]]
  
  local gateway_port_result = run_step("get gateway port", gateway_port_cmd)
  local gateway_port = trim(gateway_port_result)
  
  run_step("verify gateway port " .. gateway_port .. " (unsigned)", "bash -lc \"lsof -iTCP:" .. gateway_port .. " -sTCP:LISTEN | head -n 5 || true\"")
end

local attach_only_args = ""
if attach_only then
  attach_only_args = " --args --attach-only"
end

run_step("launch app", "env -i " ..
  "HOME=\"" .. os.getenv("HOME") .. "\" " ..
  "USER=\"" .. (os.getenv("USER") or "") .. "\" " ..
  "LOGNAME=\"" .. (os.getenv("LOGNAME") or "") .. "\" " ..
  "TMPDIR=\"" .. (os.getenv("TMPDIR") or "/tmp") .. "\" " ..
  "PATH=\"/usr/bin:/bin:/usr/sbin:/sbin\" " ..
  "LANG=\"" .. (os.getenv("LANG") or "en_US.UTF-8") .. "\" " ..
  "/usr/bin/open \"" .. app_bundle .. "\"" .. attach_only_args)

os.execute("sleep 1.5")
if os.execute("pgrep -f \"" .. app_process_pattern .. "\" >/dev/null 2>&1") == 0 then
  log("OK: OpenClaw is running.")
else
  fail("App exited immediately. Check " .. log_path .. " or Console.app (User Reports).")
end

if no_sign and not attach_only then
  run_step("show gateway launch agent args (unsigned)", "bash -lc \"/usr/bin/plutil -p '" .. os.getenv("HOME") .. "/Library/LaunchAgents/ai.openclaw.gateway.plist' | head -n 40 || true\"")
end
