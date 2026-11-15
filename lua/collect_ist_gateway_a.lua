#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "9a331e0c42f499afa7f12ed97969a6990b4bcb5538789351880a87a21f71263f", "source_sha256": "47064dbc7b32c01d57d42222f8cc3ac7caf9c8d82b98029dc5fc6ecb0d32f2c9", "target_language": "lua"}
-- collect_ist_gateway_a.sh — portiert nach lua
-- Quelle: shell, OpenClaw@gateway1:scripts/collect_ist_gateway_a.sh
-- Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

local os = require("os")
local io = require("io")
local table = require("table")

-- Hilfsfunktionen für Shell-Befehle
local function execute(cmd)
  local handle = io.popen(cmd .. " 2>/dev/null", "r")
  if not handle then return nil end
  local result = handle:read("*a")
  handle:close()
  return result and result:gsub("%s+$", "") or ""
end

local function file_exists(path)
  local f = io.open(path, "r")
  if f then f:close() return true end
  return false
end

local function dir_exists(path)
  local f = io.open(path, "r")
  if f then
    local ok, _, code = f:read(1)
    f:close()
    return code == 21  -- EISDIR error code simulation
  end
  return false
end

local function read_file(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local content = f:read("*a")
  f:close()
  return content
end

local function basename(path)
  return path:match("^.+/(.+)$") or path
end

-- Konfiguration
local HOME = os.getenv("HOME") or "/tmp"
local BASE_DIR = HOME .. "/.openclaw"
local OUT_DIR = BASE_DIR .. "/workspace/vscode"

-- Zeitstempel
local NOW_UTC = os.date("!%Y-%m-%dT%H:%M:%SZ")
local NOW_LOCAL = os.date("%Y-%m-%d %H:%M:%S %Z")
local TS = os.date("%Y%m%d-%H%M%S")

-- Ausgabedateien
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
local HOSTNAME_FQDN = execute("hostname -f") or execute("hostname") or "unknown"
local HOSTNAME_SHORT = execute("hostname") or "unknown"
local ARCH = execute("uname -m") or "unknown"
local KERNEL = execute("uname -r") or "unknown"

local OS_PRETTY = "(nicht ermittelt)"
do
  local os_release = read_file("/etc/os-release")
  if os_release then
    for line in os_release:gmatch("[^\r\n]+") do
      if line:match("^PRETTY_NAME=") then
        OS_PRETTY = line:match("^PRETTY_NAME=(.*)"):gsub("^[%s\"]*(.-)[%s\"]*$", "%1") or OS_PRETTY
        break
      end
    end
  end
end

local IPV4_ALL = execute("hostname -I") or ""
if IPV4_ALL ~= "" then
  local parts = {}
  for part in IPV4_ALL:gmatch("%S+") do
    table.insert(parts, part)
  end
  IPV4_ALL = table.concat(parts, " ")
else
  IPV4_ALL = "(nicht ermittelt)"
end

local PUBLIC_IP = execute("curl -4 -s --max-time 4 ifconfig.me") or ""
if PUBLIC_IP == "" then PUBLIC_IP = "(nicht ermittelt)" end

local TAILSCALE_IP = execute("tailscale ip -4") or ""
if TAILSCALE_IP == "" then TAILSCALE_IP = "(nicht ermittelt)" end

local OPENCLAW_VER = execute("openclaw --version") or ""
if OPENCLAW_VER == "" then OPENCLAW_VER = "(nicht ermittelt)" end

local NODE_VER = execute("node -v") or ""
if NODE_VER == "" then NODE_VER = "(nicht ermittelt)" end

-- Verzeichnisse erstellen
os.execute("mkdir -p " .. OUT_DIR)

-- IST-Zustand schreiben
do
  local f = io.open(IST_FILE, "w")
  f:write("# IST-Zustand: Gateway A / Node 1\n\n")
  f:write("Stand (lokal): " .. NOW_LOCAL .. "  \n")
  f:write("Stand (UTC): " .. NOW_UTC .. "\n\n")
  f:write("## 1) Identitaet & System\n\n")
  f:write("- Gateway: **A**\n")
  f:write("- Node: **1**\n")
  f:write("- Hostname (short): `" .. HOSTNAME_SHORT .. "`\n")
  f:write("- Hostname (FQDN): `" .. HOSTNAME_FQDN .. "`\n")
  f:write("- Architektur: `" .. ARCH .. "`\n")
  f:write("- Kernel: `" .. KERNEL .. "`\n")
  f:write("- OS: `" .. OS_PRETTY .. "`\n")
  f:write("- IPv4 (lokal): `" .. IPV4_ALL .. "`\n")
  f:write("- Public IPv4: `" .. PUBLIC_IP .. "`\n")
  f:write("- Tailscale IPv4: `" .. TAILSCALE_IP .. "`\n")
  f:write("- OpenClaw Version: `" .. OPENCLAW_VER .. "`\n")
  f:write("- Node.js Version: `" .. NODE_VER .. "`\n\n")
  f:write("## 2) Arbeitsverzeichnisse\n\n")
  f:write("- Basis: `" .. BASE_DIR .. "`\n")
  f:write("- Funktionell VSCode: `" .. VSCODE_DIR .. "`\n")
  f:write("- Workspace Doku: `" .. OUT_DIR .. "`\n\n")
  f:write("## 3) Kernartefakte (Existenz)\n\n")
  
  local artifacts = {
    {OPENCLAW_JSON, "openclaw.json"},
    {ENV_DOT, ".env"},
    {ENV_SYSTEMD, "gateway.systemd.env"},
    {BASE_DIR .. "/plugins/installs.json", "plugins/installs.json"},
    {BASE_DIR .. "/plugin-skills", "plugin-skills"}
  }
  
  for _, artifact in ipairs(artifacts) do
    local status = "fehlt"
    if artifact[2] == "plugin-skills" then
      if dir_exists(artifact[1]) then status = "vorhanden" end
    else
      if file_exists(artifact[1]) then status = "vorhanden" end
    end
    f:write("- `" .. artifact[1] .. "`: " .. status .. "\n")
  end
  
  f:close()
end

-- Artefakt-Inventar schreiben
do
  local f = io.open(INV_FILE, "w")
  f:write("# Artefakt-Inventar: Gateway A / Node 1\n\n")
  f:write("Stand: " .. NOW_LOCAL .. "\n\n")
  f:write("## Top-Level in ~/.openclaw\n\n")
  f:write('```text\n')
  
  local listing = execute("ls -1 " .. BASE_DIR)
  if listing and listing ~= "" then
    f:write(listing .. "\n")
  end
  
  f:write('```\n\n')
  f:write("## ~/.openclaw/.vscode\n\n")
  f:write('```text\n')
  
  if dir_exists(VSCODE_DIR) then
    local listing = execute("ls -la " .. VSCODE_DIR)
    if listing then f:write(listing .. "\n") end
  else
    f:write("(nicht vorhanden)\n")
  end
  
  f:write('```\n\n')
  f:write("## plugin-skills/\n\n")
  f:write('```text\n')
  
  if dir_exists(BASE_DIR .. "/plugin-skills") then
    local listing = execute("ls -1 " .. BASE_DIR .. "/plugin-skills")
    if listing then f:write(listing .. "\n") end
  else
    f:write("(nicht vorhanden)\n")
  end
  
  f:write('```\n\n')
  f:write("## openclaw.json Backups\n\n")
  f:write('```text\n')
  
  local backups = execute("ls -1 " .. BASE_DIR .. "/openclaw.json.bak*")
  if backups and backups ~= "" then
    f:write(backups .. "\n")
  else
    f:write("(keine gefunden)\n")
  end
  
  f:write('```\n')
  f:close()
end

-- Config Snapshot schreiben
do
  local f = io.open(CFG_FILE, "w")
  f:write("# OpenClaw Config Snapshot: Gateway A / Node 1\n\n")
  f:write("Stand: " .. NOW_LOCAL .. "\n\n")
  f:write("## Schluesselpositionen (grep)\n\n")
  f:write('```text\n')
  
  if file_exists(OPENCLAW_JSON) then
    local grep_result = execute('grep -nE \'"gateway"|\\\"session\\\"|\\\"dmScope\\\"|\\\"auth\\\"|\\\"secrets\\\"|\\\"tools\\\"|\\\"plugins\\\"|\\\"profile\\\"|\\\"alsoAllow\\\"|\\\"denyCommands\\\"\' ' .. OPENCLAW_JSON)
    if grep_result and grep_result ~= "" then
      f:write(grep_result .. "\n")
    end
  else
    f:write("openclaw.json fehlt\n")
  end
  
  f:write('```\n\n')
  f:write("## Ausschnitt gateway/session/auth\n\n")
  f:write('```json\n')
  
  if file_exists(OPENCLAW_JSON) then
    local content = read_file(OPENCLAW_JSON)
    if content then
      local lines = {}
      for line in content:gmatch("[^\r\n]*") do
        table.insert(lines, line)
      end
      
      for i = 580, math.min(780, #lines) do
        f:write(lines[i] .. "\n")
      end
    end
  else
    f:write('{ "error": "openclaw.json fehlt" }\n')
  end
  
  f:write('```\n')
  f:close()
end

-- ENV-Status schreiben
do
  local f = io.open(ENV_FILE, "w")
  f:write("# ENV-Status: Gateway A / Node 1\n\n")
  f:write("Stand: " .. NOW_LOCAL .. "\n\n")
  f:write("## Dateien\n\n")
  f:write('```text\n')
  
  local listing = execute("ls -la " .. ENV_DOT .. " " .. ENV_SYSTEMD)
  if listing and listing ~= "" then
    f:write(listing .. "\n")
  end
  
  f:write('```\n\n')
  f:write("## .env (vollstaendig)\n\n")
  f:write('```dotenv\n')
  
  if file_exists(ENV_DOT) then
    local content = read_file(ENV_DOT)
    if content then f:write(content) end
  else
    f:write("# .env fehlt\n")
  end
  
  f:write('```\n\n')
  f:write("## gateway.systemd.env (vollstaendig)\n\n")
  f:write('```dotenv\n')
  
  if file_exists(ENV_SYSTEMD) then
    local content = read_file(ENV_SYSTEMD)
    if content then f:write(content) end
  else
    f:write("# gateway.systemd.env fehlt\n")
  end
  
  f:write('```\n')
  f:close()
end

-- Run-Datei schreiben
do
  local f = io.open(RUN_FILE, "w")
  f:write("# Laufprotokoll Gateway A / Node 1\n\n")
  f:write("- Zeit (lokal): " .. NOW_LOCAL .. "\n")
  f:write("- Zeit (UTC): " .. NOW_UTC .. "\n")
  f:write("- Script: collect_ist_gateway_a.sh\n\n")  -- Hardcoded da Lua keinen einfachen Weg hat, den Skriptnamen zu erhalten
  f:write("## Erzeugte Dateien\n\n")
  f:write("- " .. basename(IST_FILE) .. "\n")
  f:write("- " .. basename(INV_FILE) .. "\n")
  f:write("- " .. basename(CFG_FILE) .. "\n")
  f:write("- " .. basename(ENV_FILE) .. "\n")
  f:close()
end

-- Erfolgsmeldung ausgeben
print("OK: IST-Zustand erfasst.")
local listing = execute("ls -1 " .. OUT_DIR)
if listing then
  for line in listing:gmatch("[^\r\n]+") do
    print("- " .. line)
  end
end
