#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "5e784c9d2ff0179e64e0cc8b8af091dd996760e7bc3dd45b711b3c5ac96db585", "source_sha256": "da890cc26fb848b78b6a85373d6cfa4e08f6e7c2002921e1c0247960b8b361d7", "target_language": "lua"}
-- collect_ist_gateway_b.sh — portiert nach lua
-- Quelle: shell, OpenClaw@gateway2:scripts/collect_ist_gateway_b.sh
-- Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

local os = require("os")
local io = require("io")
local table = require("table")

-- Hilfsfunktionen
local function exec(cmd)
  local handle = io.popen(cmd)
  local result = handle:read("*a")
  handle:close()
  return result:gsub("%s+$", "")
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
  local handle = io.popen("test -d '" .. path .. "' && echo 'exists'")
  local result = handle:read("*l")
  handle:close()
  return result == "exists"
end

local function basename(path)
  return string.match(path, "([^/]+)$")
end

-- Konfiguration
local HOME = os.getenv("HOME") or "/tmp"
local BASE_DIR = HOME .. "/.openclaw"
local OUT_DIR = BASE_DIR .. "/workspace/vscode"

-- Zeitstempel
local NOW_UTC = os.date("!%Y-%m-%dT%H:%M:%SZ")
local NOW_LOCAL = os.date("%Y-%m-%d %H:%M:%S %Z")
local TS = os.date("%Y%m%d-%H%M%S")

-- Ordner erstellen
os.execute("mkdir -p '" .. OUT_DIR .. "'")

-- Dateipfade
local IST_FILE = OUT_DIR .. "/IST-ZUSTAND_GATEWAY-B_NODE7.md"
local INV_FILE = OUT_DIR .. "/ARTEFAKT-INVENTAR_GATEWAY-B_NODE7.md"
local CFG_FILE = OUT_DIR .. "/OPENCLAW-CONFIG-SNAPSHOT_GATEWAY-B_NODE7.md"
local ENV_FILE = OUT_DIR .. "/ENV-STATUS_GATEWAY-B_NODE7.md"
local RUN_FILE = OUT_DIR .. "/RUN-" .. TS .. ".md"

-- Dateipfade für Checks
local OPENCLAW_JSON = BASE_DIR .. "/openclaw.json"
local ENV_DOT = BASE_DIR .. "/.env"
local ENV_SYSTEMD = BASE_DIR .. "/gateway.systemd.env"
local VSCODE_DIR = BASE_DIR .. "/.vscode"

-- Systeminformationen sammeln
local HOSTNAME_FQDN = exec("hostname -f 2>/dev/null || hostname") or "unbekannt"
local HOSTNAME_SHORT = exec("hostname") or "unbekannt"
local ARCH = exec("uname -m") or "unbekannt"
local KERNEL = exec("uname -r") or "unbekannt"
local OS_PRETTY = exec("grep '^PRETTY_NAME=' /etc/os-release 2>/dev/null | cut -d= -f2- | tr -d '\"'") or ""
local IPV4_ALL = exec("hostname -I 2>/dev/null | xargs") or ""
local PUBLIC_IP = exec("curl -4 -s --max-time 4 ifconfig.me 2>/dev/null") or ""
local TAILSCALE_IP = exec("tailscale ip -4 2>/dev/null | head -n1") or ""
local OPENCLAW_VER = exec("openclaw --version 2>/dev/null") or ""
local NODE_VER = exec("node -v 2>/dev/null") or ""

-- Fallbacks setzen
if PUBLIC_IP == "" then PUBLIC_IP = "(nicht ermittelt)" end
if TAILSCALE_IP == "" then TAILSCALE_IP = "(nicht ermittelt)" end
if OPENCLAW_VER == "" then OPENCLAW_VER = "(nicht ermittelt)" end
if NODE_VER == "" then NODE_VER = "(nicht ermittelt)" end

-- 1) IST-Zustand schreiben
local ist_file = io.open(IST_FILE, "w")
ist_file:write([[
# IST-Zustand: Gateway B / Node 7

Stand (lokal): ]] .. NOW_LOCAL .. [[  
Stand (UTC): ]] .. NOW_UTC .. [[

## 1) Identität & System

- Gateway: **B**
- Node: **7**
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

- `]] .. OPENCLAW_JSON .. [[: ]] .. (file_exists(OPENCLAW_JSON) and "vorhanden" or "fehlt") .. [[
- `]] .. ENV_DOT .. [[: ]] .. (file_exists(ENV_DOT) and "vorhanden" or "fehlt") .. [[
- `]] .. ENV_SYSTEMD .. [[: ]] .. (file_exists(ENV_SYSTEMD) and "vorhanden" or "fehlt") .. [[
- `]] .. BASE_DIR .. [[/plugins/installs.json: ]] .. (file_exists(BASE_DIR .. "/plugins/installs.json") and "vorhanden" or "fehlt") .. [[
- `]] .. BASE_DIR .. [[/plugin-skills: ]] .. (dir_exists(BASE_DIR .. "/plugin-skills") and "vorhanden" or "fehlt") .. [[

## 4) Hinweis

Diese Datei wird bei jedem Lauf neu geschrieben.
Zusätzlich wird ein Laufprotokoll als `RUN-*.md` erzeugt.
]])
ist_file:close()

-- 2) Artefakt-Inventar schreiben
local inv_file = io.open(INV_FILE, "w")
inv_file:write("# Artefakt-Inventar: Gateway B / Node 7\n\n")
inv_file:write("Stand: " .. NOW_LOCAL .. "\n\n")
inv_file:write("## Top-Level in ~/.openclaw\n\n")
inv_file:write("```text\n")
local top_level = exec("ls -1 '" .. BASE_DIR .. "' 2>/dev/null")
if top_level ~= "" then
  inv_file:write(top_level .. "\n")
end
inv_file:write("```\n\n")

inv_file:write("## ~/.openclaw/.vscode\n\n")
inv_file:write("```text\n")
if dir_exists(VSCODE_DIR) then
  local vscode_content = exec("ls -la '" .. VSCODE_DIR .. "'")
  inv_file:write(vscode_content .. "\n")
else
  inv_file:write("(nicht vorhanden)\n")
end
inv_file:write("```\n\n")

inv_file:write("## plugin-skills/\n\n")
inv_file:write("```text\n")
if dir_exists(BASE_DIR .. "/plugin-skills") then
  local skills_content = exec("ls -1 '" .. BASE_DIR .. "/plugin-skills'")
  inv_file:write(skills_content .. "\n")
else
  inv_file:write("(nicht vorhanden)\n")
end
inv_file:write("```\n\n")

inv_file:write("## openclaw.json Backups\n\n")
inv_file:write("```text\n")
local backups = exec("ls -1 '" .. BASE_DIR .. "'/openclaw.json.bak* 2>/dev/null")
if backups ~= "" then
  inv_file:write(backups .. "\n")
else
  inv_file:write("(keine gefunden)\n")
end
inv_file:write("```\n")
inv_file:close()

-- 3) Config Snapshot schreiben
local cfg_file = io.open(CFG_FILE, "w")
cfg_file:write("# OpenClaw Config Snapshot: Gateway B / Node 7\n\n")
cfg_file:write("Stand: " .. NOW_LOCAL .. "\n\n")
cfg_file:write("## Schlüsselpositionen (grep)\n\n")
cfg_file:write("```text\n")
if file_exists(OPENCLAW_JSON) then
  local key_positions = exec("grep -nE '\"gateway\"|\\\"session\\\"|\\\"dmScope\\\"|\\\"auth\\\"|\\\"secrets\\\"|\\\"tools\\\"|\\\"plugins\\\"|\\\"profile\\\"|\\\"alsoAllow\\\"|\\\"denyCommands\\\"' '" .. OPENCLAW_JSON .. "'")
  if key_positions ~= "" then
    cfg_file:write(key_positions .. "\n")
  end
else
  cfg_file:write("openclaw.json fehlt\n")
end
cfg_file:write("```\n\n")

cfg_file:write("## Ausschnitt gateway/session/auth (ungefiltert, betriebsnah)\n\n")
cfg_file:write("```json\n")
if file_exists(OPENCLAW_JSON) then
  local snippet = exec("sed -n '580,780p' '" .. OPENCLAW_JSON .. "'")
  cfg_file:write(snippet .. "\n")
else
  cfg_file:write("{ \"error\": \"openclaw.json fehlt\" }\n")
end
cfg_file:write("```\n")
cfg_file:close()

-- 4) ENV-Status schreiben
local env_file = io.open(ENV_FILE, "w")
env_file:write("# ENV-Status: Gateway B / Node 7\n\n")
env_file:write("Stand: " .. NOW_LOCAL .. "\n\n")
env_file:write("## Dateien\n\n")
env_file:write("```text\n")
local env_files = exec("ls -la '" .. ENV_DOT .. "' '" .. ENV_SYSTEMD .. "' 2>/dev/null")
if env_files ~= "" then
  env_file:write(env_files .. "\n")
end
env_file:write("```\n\n")

env_file:write("## .env (vollständig, ungefiltert)\n\n")
env_file:write("```dotenv\n")
if file_exists(ENV_DOT) then
  local env_content = exec("cat '" .. ENV_DOT .. "'")
  env_file:write(env_content .. "\n")
else
  env_file:write("# .env fehlt\n")
end
env_file:write("```\n\n")

env_file:write("## gateway.systemd.env (vollständig, ungefiltert)\n\n")
env_file:write("```dotenv\n")
if file_exists(ENV_SYSTEMD) then
  local systemd_content = exec("cat '" .. ENV_SYSTEMD .. "'")
  env_file:write(systemd_content .. "\n")
else
  env_file:write("# gateway.systemd.env fehlt\n")
end
env_file:write("```\n")
env_file:close()

-- 5) Laufprotokoll schreiben
local run_file = io.open(RUN_FILE, "w")
run_file:write("# Laufprotokoll Gateway B / Node 7\n\n")
run_file:write("- Zeit (lokal): " .. NOW_LOCAL .. "\n")
run_file:write("- Zeit (UTC): " .. NOW_UTC .. "\n")
run_file:write("- Script: " .. arg[0] .. "\n\n")
run_file:write("## Erzeugte Dateien\n\n")
run_file:write("- " .. basename(IST_FILE) .. "\n")
run_file:write("- " .. basename(INV_FILE) .. "\n")
run_file:write("- " .. basename(CFG_FILE) .. "\n")
run_file:write("- " .. basename(ENV_FILE) .. "\n")
run_file:close()

-- Ausgabe
print("OK: IST-Zustand erfasst.")
print("Ausgabeordner: " .. OUT_DIR)
print("Dateien:")
local files_list = exec("ls -1 '" .. OUT_DIR .. "'")
for line in files_list:gmatch("[^\r\n]+") do
  print("- " .. line)
end
