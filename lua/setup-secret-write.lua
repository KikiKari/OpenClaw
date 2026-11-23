#!/usr/bin/lua
-- abstraction-provenance: {"artifact_sha256": "925a09797cdd07e980db412b10b2d064d49baeb68cb414ea5e678b1f8e67be90", "source_sha256": "eb329c9ad90fe7f2c211dd5d35aed9557a4387c1092c4569ebb4e3f4db2d3557", "target_language": "lua"}
-- setup-secret-write.sh — portiert nach lua
-- Quelle: shell, workspace@local:scripts/setup-secret-write.sh
-- Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

local posix = require("posix")
local lfs = require("lfs")

-- Source environment variables (simulated)
local env_file = "/home/openclaw/.config/openclaw/env"
local env_vars = {}

-- Read and parse the env file
local function read_env_file(file)
  local f = io.open(file, "r")
  if not f then return end
  for line in f:lines() do
    local key, value = line:match("^([^=]+)=(.*)$")
    if key and value then
      env_vars[key] = value
    end
  end
  f:close()
end

read_env_file(env_file)

-- Set environment variables
os.setenv("OPENROUTER_API_KEY", env_vars.OPENROUTER_API_KEY or "")
os.setenv("OPENAI_API_KEY", env_vars.OPENAI_API_KEY or "")

-- Configuration
local SECRETS_DIR = "/secret-store"
local YAML = "/home/openclaw/.openclaw/workspace/memory/model-pools.yaml"

-- Create directory with permissions
posix.mkdir(SECRETS_DIR, "rwxr-x---") -- 750 permissions
posix.chown(SECRETS_DIR, "openclaw", "openclaw")

-- Write default-model.json
local default_model_content = string.format('{ "provider": "openrouter", "token": "%s" }', os.getenv("OPENROUTER_API_KEY"))
local default_model_file = io.open(SECRETS_DIR .. "/default-model.json", "w")
if default_model_file then
  default_model_file:write(default_model_content)
  default_model_file:close()
  posix.chmod(SECRETS_DIR .. "/default-model.json", "rw-------") -- 600 permissions
end

-- Write proxy-model.json
local proxy_model_content = string.format('{ "provider": "openai", "token": "%s" }', os.getenv("OPENAI_API_KEY"))
local proxy_model_file = io.open(SECRETS_DIR .. "/proxy-model.json", "w")
if proxy_model_file then
  proxy_model_file:write(proxy_model_content)
  proxy_model_file:close()
  posix.chmod(SECRETS_DIR .. "/proxy-model.json", "rw-------") -- 600 permissions
end

-- YAML content
local yaml_content = [[
pools:
  - name: pool_default
    id: default
    model: openrouter/moonshotai/kimi-k3
    weight: 0.8
    secretsPath: /secret-store/default-model.json

  - name: pool_proxy
    id: proxy
    model: openrouter/auto
    weight: 0.2
    secretsPath: /secret-store/proxy-model.json

routing:
  - name: latency_and_error_based
    criteria:
      - latency_ms: "< 200"
      - error_rate_pct: "< 1"
    route_to: pool_default
  - name: fallback_if_issues
    criteria:
      - latency_ms: ">= 200"
      - error_rate_pct: ">= 1"
    route_to: pool_proxy

fallbacks:
  - model: openrouter/moonshotai/kimi-k3
  - model: openai/gpt-5.6-luna

logging:
  events:
    request_decisions: true
    memory_store_path: /memory/logs/model-routing.log
  retention_days: 14

security:
  secrets_encryption: true
  access_control:
    - role: model-operator
      allow: [read, write]
    - role: monitor
      allow: [read]
]]

-- Write YAML file
local yaml_file = io.open(YAML, "w")
if yaml_file then
  yaml_file:write(yaml_content)
  yaml_file:close()
end

print("=== ERLEDIGT ===")
print("Secrets:")
os.execute("ls -la " .. SECRETS_DIR .. "/")
print("")
print("YAML: " .. YAML)
os.execute("ls -la " .. YAML)
