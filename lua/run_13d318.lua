#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "77c4f24ac994e47fb9515ee0c1ee09c91168b58614f7c88ac6a81feb669877f6", "source_sha256": "13d3188a43593fc462e34986e11913f715c38d3ec54128b71ba71024d5419be6", "target_language": "lua"}
-- run.sh — portiert nach lua
-- Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/docker/cleanup-smoke/run.sh
-- Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

local function run_command(cmd)
  local handle = io.popen(cmd .. " 2>&1")
  local result = handle:read("*a")
  local success, _, code = handle:close()
  return success, result, code
end

local function check_success(success, output, code)
  if not success then
    print(output)
    os.exit(code or 1)
  end
end

-- Change directory to /repo
os.execute("cd /repo")

-- Set environment variables
os.setenv("OPENCLAW_STATE_DIR", "/tmp/openclaw-test")
os.setenv("OPENCLAW_CONFIG_PATH", "/tmp/openclaw-test/openclaw.json")

print("==> Build")
local success, output, code = run_command("pnpm build >/tmp/openclaw-cleanup-build.log")
check_success(success, output, code)

print("==> Seed state")
os.execute("mkdir -p /tmp/openclaw-test/credentials")
os.execute("mkdir -p /tmp/openclaw-test/agents/main/sessions")
os.execute("echo '{}' >/tmp/openclaw-test/openclaw.json")
os.execute("echo 'creds' >/tmp/openclaw-test/credentials/marker.txt")
os.execute("echo 'session' >/tmp/openclaw-test/agents/main/sessions/sessions.json")

print("==> Reset (config+creds+sessions)")
success, output, code = run_command("pnpm openclaw reset --scope config+creds+sessions --yes --non-interactive >/tmp/openclaw-cleanup-reset.log")
check_success(success, output, code)

-- Test file and directory removal
if io.open("/tmp/openclaw-test/openclaw.json", "r") ~= nil then
  io.stderr:write("File still exists: /tmp/openclaw-test/openclaw.json\n")
  os.exit(1)
end

if io.open("/tmp/openclaw-test/credentials", "r") ~= nil then
  io.stderr:write("Directory still exists: /tmp/openclaw-test/credentials\n")
  os.exit(1)
end

if io.open("/tmp/openclaw-test/agents/main/sessions", "r") ~= nil then
  io.stderr:write("Directory still exists: /tmp/openclaw-test/agents/main/sessions\n")
  os.exit(1)
end

print("==> Recreate minimal config")
os.execute("mkdir -p /tmp/openclaw-test/credentials")
os.execute("echo '{}' >/tmp/openclaw-test/openclaw.json")

print("==> Uninstall (state only)")
success, output, code = run_command("pnpm openclaw uninstall --state --yes --non-interactive >/tmp/openclaw-cleanup-uninstall.log")
check_success(success, output, code)

-- Test state directory removal
if io.open("/tmp/openclaw-test", "r") ~= nil then
  io.stderr:write("Directory still exists: /tmp/openclaw-test\n")
  os.exit(1)
end

print("OK")
