#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "0c4e6a783944160f2b2ea654bf841b9fd9e1de87f4767a68d26034bfa6e136cf", "source_sha256": "47064dbc7b32c01d57d42222f8cc3ac7caf9c8d82b98029dc5fc6ecb0d32f2c9", "target_language": "lua"}
-- collect_ist_gateway_a.sh — portiert nach lua
-- Quelle: shell, OpenClaw@gateway1:scripts/collect_ist_gateway_a.sh
-- Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

local os = require("os")
local io = require("io")
local table = require("table")

-- Hilfsfunktionen
local function exec(cmd)
  local handle = io.popen(cmd .. " 2>/dev/null")
  if not handle then return "" end
  local result = handle:read("*a"):gsub("%s+$", "")
  handle:close()
  return result
end

local function file_exists(path)
  local file = io.open(path, "r")
  if file then
    file:close()
    return true
  else
    return false
  end
end

local function dir_exists(path)
  local file = io.open(path, "r")
  if file then
    local isdir = file:read(1) == nil or file:seek("end") == 0
    file:close()
    return isdir
  else
    return false
  end
end

local function trim(s)
  return s:match("^%s*(.-)%s*$")
end

-- Konfiguration
local BASE_DIR = os.getenv("HOME") .. "/.openclaw"
local OUT_DIR = BASE_DIR .. "/workspace/vscode"

-- Zeitstempel
local NOW_UTC = os.date("!%Y-%m-%dT%H:%M:%SZ")
local NOW_LOCAL = os.date("%Y-%m-%d %H:%M:%S %Z")
local TS = os.date("%Y%m%d-%H%M%S")

-- Verzeichnis erstellen
os.execute("mkdir -p " .. OUT_DIR)

-- Dateipfade
local IST_FILE = OUT_DIR .. "/IST-ZUSTAND_GATEWAY-A_NODE1.md"
local INV_FILE = OUT_DIR .. "/ARTEFAKT-INVENTAR_GATEWAY-A_NODE1.md"
local CFG_FILE = OUT_DIR .. "/OPENCLAW-CONFIG-SNAPSHOT_GATEWAY-A_NODE1.md"
local ENV_FILE = OUT_DIR .. "/ENV-STATUS_GATEWAY-A_NODE1.md"
local RUN_FILE = OUT_DIR .. "/RUN-" .. TS .. ".md"

-- Konfigurationsdateien
local OPENCLAW_JSON = BASE_DIR .. "/openclaw.json"
local ENV_DOT = BASE_DIR .. "/.env"
local ENV_SYSTEMD = BASE_DIR .. "/gateway.systemd.env"
local VSCODE_DIR = BASE_DIR .. "/.vscode"

-- Systeminformationen sammeln
local HOSTNAME_FQDN = exec("hostname -f") ~= "" and exec("hostname -f") or exec("hostname")
local HOSTNAME_SHORT = exec("hostname")
local ARCH = exec("uname -m")
local KERNEL = exec("uname -r")
local OS_PRETTY = exec('grep "^PRETTY_NAME=" /etc/os-release 2>/dev/null | cut -d= -f2- | tr -d \'"\'')
local IPV4_ALL = exec("hostname -I"):gsub("%s+", " ")
local PUBLIC_IP = exec("curl -4 -s --max-time 4 ifconfig.me") ~= "" and exec("curl -4 -s --max-time 4 ifconfig.me") or "(nicht ermittelt)"
local TAILSCALE_IP = exec("tailscale ip -4"):match("[^\n]*") or "(nicht ermittelt)"
local OPENCLAW_VER = exec("openclaw --version") ~= "" and exec("openclaw --version") or "(nicht ermittelt)"
local NODE_VER = exec("node -v") ~= "" and exec("node -v") or "(nicht ermittelt)"

-- IST-Zustand
local ist_file = io.open(IST_FILE, "w")
if ist_file then
  ist_file:write([[
# IST-Zustand: Gateway A / Node 1

Stand (lokal): ]] .. NOW_LOCAL .. [[  
Stand (UTC): ]] .. NOW_UTC .. [[

## 1) Identitaet & System

- Gateway: **A**
- Node: **1**
- Hostname (short): `]] .. HOSTNAME_SHORT .. [[`
- Hostname (FQDN): `]] .. HOSTNAME_FQDN .. [[`
- Architektur: `]] .. ARCH .. [[`
- Kernel: `]] .. KERNEL .. [[`
- OS: `]] .. OS_PRETTY .. [[`
- IPv4 (lokal): `]] .. IPV4_ALL .. [[`
- Public IPv4: `]] .. PUBLIC_IP .. [[`
- Tailscale IPv4: `]] .. TAILSCALE_IP .. [[`
- OpenClaw Version: `]] .. OPENCLAW_VER .. [[`
- Node.js Version: `]] .. NODE_VER .. [[`

## 2) Arbeitsverzeichnisse

- Basis: `]] .. BASE_DIR .. [[`
- Funktionell VSCode: `]] .. VSCODE_DIR .. [[`
- Workspace Doku: `]] .. OUT_DIR .. [[`

## 3) Kernartefakte (Existenz)

- `]] .. OPENCLAW_JSON .. [[`: ]] .. (file_exists(OPENCLAW_JSON) and "vorhanden" or "fehlt") .. [[
- `]] .. ENV_DOT .. [[`: ]] .. (file_exists(ENV_DOT) and "vorhanden" or "fehlt") .. [[
- `]] .. ENV_SYSTEMD .. [[`: ]] .. (file_exists(ENV_SYSTEMD) and "vorhanden" or "fehlt") .. [[
- `]] .. BASE_DIR .. [[/plugins/installs.json`: ]] .. (file_exists(BASE_DIR .. "/plugins/installs.json") and "vorhanden" or "fehlt") .. [[
- `]] .. BASE_DIR .. [[/plugin-skills`: ]] .. (dir_exists(BASE_DIR .. "/plugin-skills") and "vorhanden" or "fehlt") .. "\n")
  ist_file:close()
end

-- Artefakt-Inventar
local inv_file = io.open(INV_FILE, "w")
if inv_file then
  inv_file:write("# Artefakt-Inventar: Gateway A / Node 1\n\n")
  inv_file:write("Stand: " .. NOW_LOCAL .. "\n\n")
  inv_file:write("## Top-Level in ~/.openclaw\n\n")
  inv_file:write("```text\n")
  
  local files = {}
  local handle = io.popen("ls -1 " .. BASE_DIR .. " 2>/dev/null")
  if handle then
    for line in handle:lines() do
      table.insert(files, line)
    end
    handle:close()
  end
  
  for _, file in ipairs(files) do
    inv_file:write(file .. "\n")
  end
  
  inv_file:write("```\n\n")
  inv_file:write("## ~/.openclaw/.vscode\n\n")
  inv_file:write("```text\n")
  
  if dir_exists(VSCODE_DIR) then
    local handle = io.popen("ls -la " .. VSCODE_DIR)
    if handle then
      for line in handle:lines() do
        inv_file:write(line .. "\n")
      end
      handle:close()
    end
  else
    inv_file:write("(nicht vorhanden)\n")
  end
  
  inv_file:write("```\n\n")
  inv_file:write("## plugin-skills/\n\n")
  inv_file:write("```text\n")
  
  if dir_exists(BASE_DIR .. "/plugin-skills") then
    local handle = io.popen("ls -1 " .. BASE_DIR .. "/plugin-skills")
    if handle then
      for line in handle:lines() do
        inv_file:write(line .. "\n")
      end
      handle:close()
    end
  else
    inv_file:write("(nicht vorhanden)\n")
  end
  
  inv_file:write("```\n\n")
  inv_file:write("## openclaw.json Backups\n\n")
  inv_file:write("```text\n")
  
  local backups = {}
  local handle = io.popen("ls -1 " .. BASE_DIR .. "/openclaw.json.bak* 2>/dev/null")
  if handle then
    for line in handle:lines() do
      table.insert(backups, line)
    end
    handle:close()
  end
  
  if #backups > 0 then
    for _, backup in ipairs(backups) do
      inv_file:write(backup .. "\n")
    end
  else
    inv_file:write("(keine gefunden)\n")
  end
  
  inv_file:write("```\n")
  inv_file:close()
end

-- OpenClaw Config Snapshot
local cfg_file = io.open(CFG_FILE, "w")
if cfg_file then
  cfg_file:write("# OpenClaw Config Snapshot: Gateway A / Node 1\n\n")
  cfg_file:write("Stand: " .. NOW_LOCAL .. "\n\n")
  cfg_file:write("## Schluesselpositionen (grep)\n\n")
  cfg_file:write("```text\n")
  
  if file_exists(OPENCLAW_JSON) then
    local handle = io.popen('grep -nE \'"gateway"|\"session\"|\"dmScope\"|\"auth\"|\"secrets\"|\"tools\"|\"plugins\"|\"profile\"|\"alsoAllow\"|\"denyCommands\"\' ' .. OPENCLAW_JSON)
    if handle then
      for line in handle:lines() do
        cfg_file:write(line .. "\n")
      end
      handle:close()
    end
  else
    cfg_file:write("openclaw.json fehlt\n")
  end
  
  cfg_file:write("```\n\n")
  cfg_file:write("## Ausschnitt gateway/session/auth\n\n")
  cfg_file:write("```json\n")
  
  if file_exists(OPENCLAW_JSON) then
    local handle = io.popen("sed -n '580,780p' " .. OPENCLAW_JSON)
    if handle then
      for line in handle:lines() do
        cfg_file:write(line .. "\n")
      end
      handle:close()
    end
  else
    cfg_file:write('{ "error": "openclaw.json fehlt" }\n')
  end
  
  cfg_file:write("```\n")
  cfg_file:close()
end

-- ENV-Status
local env_file = io.open(ENV_FILE, "w")
if env_file then
  env_file:write("# ENV-Status: Gateway A / Node 1\n\n")
  env_file:write("Stand: " .. NOW_LOCAL .. "\n\n")
  env_file:write("## Dateien\n\n")
  env_file:write("```text\n")
  
  local handle = io.popen("ls -la " .. ENV_DOT .. " " .. ENV_SYSTEMD .. " 2>/dev/null")
  if handle then
    for line in handle:lines() do
      env_file:write(line .. "\n")
    end
    handle:close()
  end
  
  env_file:write("```\n\n")
  env_file:write("## .env (vollstaendig)\n\n")
  env_file:write("```dotenv\n")
  
  if file_exists(ENV_DOT) then
    local handle = io.open(ENV_DOT, "r")
    if handle then
      for line in handle:lines() do
        env_file:write(line .. "\n")
      end
      handle:close()
    end
  else
    env_file:write("# .env fehlt\n")
  end
  
  env_file:write("```\n\n")
  env_file:write("## gateway.systemd.env (vollstaendig)\n\n")
  env_file:write("```dotenv\n")
  
  if file_exists(ENV_SYSTEMD) then
    local handle = io.open(ENV_SYSTEMD, "r")
    if handle then
      for line in handle:lines() do
        env_file:write(line .. "\n")
      end
      handle:close()
    end
  else
    env_file:write("# gateway.systemd.env fehlt\n")
  end
  
  env_file:write("```\n")
  env_file:close()
end

-- Laufprotokoll
local run_file = io.open(RUN_FILE, "w")
if run_file then
  run_file:write("# Laufprotokoll Gateway A / Node 1\n\n")
  run_file:write("- Zeit (lokal): " .. NOW_LOCAL .. "\n")
  run_file:write("- Zeit (UTC): " .. NOW_UTC .. "\n")
  run_file:write("- Script: " .. arg[0] .. "\n\n")
  run_file:write("## Erzeugte Dateien\n\n")
  run_file:write("- " .. IST_FILE:match("([^/]+)$") .. "\n")
  run_file:write("- " .. INV_FILE:match("([^/]+)$") .. "\n")
  run_file:write("- " .. CFG_FILE:match("([^/]+)$") .. "\n")
  run_file:write("- " .. ENV_FILE:match("([^/]+)$") .. "\n")
  run_file:close()
end

print("OK: IST-Zustand erfasst.")
local handle = io.popen("ls -1 " .. OUT_DIR)
if handle then
  for line in handle:lines() do
    print("- " .. line)
  end
  handle:close()
end
