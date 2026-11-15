#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "44950b91366f87fe0f149c844f1c2f469d127dabcd9a25445f27351928ba2f30", "source_sha256": "1b01ca0f5943b16d3905faf557953600ee54f15ecf1dc18c1461585eba94d376", "target_language": "lua"}
-- abstractions-manager-cron.sh — portiert nach lua
-- Quelle: shell, OpenClaw@gateway1:scripts/abstractions-manager-cron.sh
-- Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

local function getenv_or_error(name)
  local value = os.getenv(name)
  if not value or value == "" then
    error(name .. " fehlt")
  end
  return value
end

-- Set PATH
os.execute("export PATH=\"/home/openclaw/.local/bin:/usr/local/bin:/usr/bin:/bin\"")

-- Load environment variables from file
local env_file = "/home/openclaw/.openclaw/.env"
local file = io.open(env_file, "r")
if file then
  for line in file:lines() do
    if not line:match("^%s*#") and line:find("=") then
      local key, value = line:match("^([^=]+)=(.*)$")
      if key and value then
        -- Remove quotes if present
        value = value:gsub("^['\"](.*)['\"]$", "%1")
        os.setenv(key, value)
      end
    end
  end
  file:close()
end

-- Check required environment variable
getenv_or_error("OPENROUTER_API_KEY")

-- Set GITHUB_TOKEN with fallback chain
local github_token = os.getenv("GITHUB_TOKEN") or os.getenv("GH_TOKEN") or os.getenv("GH_ACCESS_TOKEN")
if github_token then
  os.setenv("GITHUB_TOKEN", github_token)
end

-- Try to acquire lock and execute command
local lock_file = "/home/openclaw/.openclaw/locks/abstractions-manager.lock"
local script_path = "/home/openclaw/.openclaw/workspace/skills/script-abstractions-manager/scripts/ABSTRACTIONS_MANAGER.py"

-- Use a simple approach to check lock file existence as flock equivalent
local lock_cmd = string.format(
  "(/usr/bin/flock --nonblock %s /usr/bin/python3 %s %s) 2>/dev/null || exit 1",
  lock_file,
  script_path,
  table.concat(arg, " ")
)

local success, _, exit_code = os.execute(lock_cmd)
if not success then
  os.exit(exit_code or 1)
end
