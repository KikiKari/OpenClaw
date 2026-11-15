#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "999abd1f6ba99feb2fbddc81e1fa50e31fa6e69893fb5ed846c2f10a1d7fa634", "source_sha256": "da890cc26fb848b78b6a85373d6cfa4e08f6e7c2002921e1c0247960b8b361d7", "target_language": "lua"}
-- collect_ist_gateway_b.sh — portiert nach lua
-- Quelle: shell, OpenClaw@gateway2:scripts/collect_ist_gateway_b.sh
-- Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

local os = require("os")
local io = require("io")
local table = require("table")

-- Hilfsfunktionen für Shell-Kommandos
local function execute_command(cmd)
  local handle = io.popen(cmd .. " 2>/dev/null", "r")
  if not handle then return nil end
  local result = handle:read("*a")
  handle:close()
  return result and result:gsub("%s+$", "") or nil
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
  local stat = os.execute("test -d " .. path .. " 2>/dev/null")
  return stat == 0 or stat == true
end

local function read_file(path)
  local file = io.open(path, "r")
  if file then
    local content = file:read("*a")
    file:close()
    return content
  else
    return nil
  end
end

-- Umgebungsvariablen und Zeitstempel
local HOME = os.getenv("HOME") or "/tmp"
local BASE_DIR = HOME .. "/.openclaw"
local OUT_DIR = BASE_DIR .. "/workspace/vscode"

-- Zeitstempel generieren
local NOW_UTC = os.date("!%Y-%m-%dT%H:%M:%SZ")
local NOW_LOCAL = os.date("%Y-%m-%d %H:%M:%S %Z")
local TS = os.date("%Y%m%d-%H%M%S")

-- Ausgabeverzeichnis erstellen
os.execute("mkdir -p " .. OUT_DIR)

-- Dateipfade definieren
local IST_FILE = OUT_DIR .. "/IST-ZUSTAND_GATEWAY-B_NODE7.md"
local INV_FILE = OUT_DIR .. "/ARTEFAKT-INVENTAR_GATEWAY-B_NODE7.md"
local CFG_FILE = OUT_DIR .. "/OPENCLAW-CONFIG-SNAPSHOT_GATEWAY-B_NODE7.md"
local ENV_FILE = OUT_DIR .. "/ENV-STATUS_GATEWAY-B_NODE7.md"
local RUN_FILE = OUT_DIR .. "/RUN-" .. TS .. ".md"

local OPENCLAW_JSON = BASE_DIR .. "/openclaw.json"
local ENV_DOT = BASE_DIR .. "/.env"
local ENV_SYSTEMD = BASE_DIR .. "/gateway.systemd.env"
local VSCODE_DIR = BASE_DIR .. "/.vscode"

-- Systeminformationen sammeln
local HOSTNAME_FQDN = execute_command("hostname -f") or execute_command("hostname") or "unbekannt"
local HOSTNAME_SHORT = execute_command("hostname") or "unbekannt"
local ARCH = execute_command("uname -m") or "unbekannt"
local KERNEL = execute_command("uname -r") or "unbekannt"
local OS_PRETTY = execute_command("grep '^PRETTY_NAME=' /etc/os-release 2>/dev/null | cut -d= -f2- | tr -d '\"'") or ""
local IPV4_ALL = execute_command("hostname -I") or ""
local PUBLIC_IP = execute_command("curl -4 -s --max-time 4 ifconfig.me") or "(nicht ermittelt)"
local TAILSCALE_IP = execute_command("tailscale ip -4 2>/dev/null | head -n1") or "(nicht ermittelt)"
local OPENCLAW_VER = execute_command("openclaw --version") or "(nicht ermittelt)"
local NODE_VER = execute_command("node -v") or "(nicht ermittelt)"

-- Fallback-Werte setzen
if PUBLIC_IP == "" then PUBLIC_IP = "(nicht ermittelt)" end
if TAILSCALE_IP == "" then TAILSCALE_IP = "(nicht ermittelt)" end
if OPENCLAW_VER == "" then OPENCLAW_VER = "(nicht ermittelt)" end
if NODE_VER == "" then NODE_VER = "(nicht ermittelt)" end

-- IST-Zustand Datei schreiben
local ist_file = io.open(IST_FILE, "w")
if ist_file then
  ist_file:write("# IST-Zustand: Gateway B / Node 7\n\n")
  ist_file:write("Stand (lokal): " .. NOW_LOCAL .. "  \n")
  ist_file:write("Stand (UTC): " .. NOW_UTC .. "\n\n")
  ist_file:write("## 1) Identität & System\n\n")
  ist_file:write("- Gateway: **B**\n")
  ist_file:write("- Node: **7**\n")
  ist_file:write("- Hostname (short): `" .. HOSTNAME_SHORT .. "`\n")
  ist_file:write("- Hostname (FQDN): `" .. HOSTNAME_FQDN .. "`\n")
  ist_file:write("- Architektur: `" .. ARCH .. "`\n")
  ist_file:write("- Kernel: `" .. KERNEL .. "`\n")
  ist_file:write("- OS: `" .. OS_PRETTY .. "`\n")
  ist_file:write("- IPv4 (lokal): `" .. IPV4_ALL .. "`\n")
  ist_file:write("- Public IPv4: `" .. PUBLIC_IP .. "`\n")
  ist_file:write("- Tailscale IPv4: `" .. TAILSCALE_IP .. "`\n")
  ist_file:write("- OpenClaw Version: `" .. OPENCLAW_VER .. "`\n")
  ist_file:write("- Node.js Version: `" .. NODE_VER .. "`\n\n")
  ist_file:write("## 2) Arbeitsverzeichnisse\n\n")
  ist_file:write("- Basis: `" .. BASE_DIR .. "`\n")
  ist_file:write("- Funktionell VSCode: `" .. VSCODE_DIR .. "`\n")
  ist_file:write("- Workspace Doku: `" .. OUT_DIR .. "`\n\n")
  ist_file:write("## 3) Kernartefakte (Existenz)\n\n")
  ist_file:write("- `" .. OPENCLAW_JSON .. "`: " .. (file_exists(OPENCLAW_JSON) and "vorhanden" or "fehlt") .. "\n")
  ist_file:write("- `" .. ENV_DOT .. "`: " .. (file_exists(ENV_DOT) and "vorhanden" or "fehlt") .. "\n")
  ist_file:write("- `" .. ENV_SYSTEMD .. "`: " .. (file_exists(ENV_SYSTEMD) and "vorhanden" or "fehlt") .. "\n")
  ist_file:write("- `" .. BASE_DIR .. "/plugins/installs.json`: " .. (file_exists(BASE_DIR .. "/plugins/installs.json") and "vorhanden" or "fehlt") .. "\n")
  ist_file:write("- `" .. BASE_DIR .. "/plugin-skills`: " .. (dir_exists(BASE_DIR .. "/plugin-skills") and "vorhanden" or "fehlt") .. "\n\n")
  ist_file:write("## 4) Hinweis\n\n")
  ist_file:write("Diese Datei wird bei jedem Lauf neu geschrieben.\n")
  ist_file:write("Zusätzlich wird ein Laufprotokoll als `RUN-*.md` erzeugt.\n")
  ist_file:close()
end

-- Artefakt-Inventar Datei schreiben
local inv_file = io.open(INV_FILE, "w")
if inv_file then
  inv_file:write("# Artefakt-Inventar: Gateway B / Node 7\n\n")
  inv_file:write("Stand: " .. NOW_LOCAL .. "\n\n")
  inv_file:write("## Top-Level in ~/.openclaw\n\n")
  inv_file:write('```text\n')
  
  local files_list = execute_command("ls -1 " .. BASE_DIR)
  if files_list then
    inv_file:write(files_list .. "\n")
  end
  
  inv_file:write('```\n\n')
  inv_file:write("## ~/.openclaw/.vscode\n\n")
  inv_file:write('```text\n')
  
  if dir_exists(VSCODE_DIR) then
    local vscode_content = execute_command("ls -la " .. VSCODE_DIR)
    if vscode_content then
      inv_file:write(vscode_content .. "\n")
    end
  else
    inv_file:write("(nicht vorhanden)\n")
  end
  
  inv_file:write('```\n\n')
  inv_file:write("## plugin-skills/\n\n")
  inv_file:write('```text\n')
  
  if dir_exists(BASE_DIR .. "/plugin-skills") then
    local skills_content = execute_command("ls -1 " .. BASE_DIR .. "/plugin-skills")
    if skills_content then
      inv_file:write(skills_content .. "\n")
    end
  else
    inv_file:write("(nicht vorhanden)\n")
  end
  
  inv_file:write('```\n\n')
  inv_file:write("## openclaw.json Backups\n\n")
  inv_file:write('```text\n')
  
  local backup_files = execute_command("ls -1 " .. BASE_DIR .. "/openclaw.json.bak* 2>/dev/null")
  if backup_files and backup_files ~= "" then
    inv_file:write(backup_files .. "\n")
  else
    inv_file:write("(keine gefunden)\n")
  end
  
  inv_file:write('```\n')
  inv_file:close()
end

-- OpenClaw Config Snapshot Datei schreiben
local cfg_file = io.open(CFG_FILE, "w")
if cfg_file then
  cfg_file:write("# OpenClaw Config Snapshot: Gateway B / Node 7\n\n")
  cfg_file:write("Stand: " .. NOW_LOCAL .. "\n\n")
  cfg_file:write("## Schlüsselpositionen (grep)\n\n")
  cfg_file:write('```text\n')
  
  if file_exists(OPENCLAW_JSON) then
    local key_positions = execute_command("grep -nE '\"gateway\"|\\\"session\\\"|\\\"dmScope\\\"|\\\"auth\\\"|\\\"secrets\\\"|\\\"tools\\\"|\\\"plugins\\\"|\\\"profile\\\"|\\\"alsoAllow\\\"|\\\"denyCommands\\\"' " .. OPENCLAW_JSON)
    if key_positions then
      cfg_file:write(key_positions .. "\n")
    end
  else
    cfg_file:write("openclaw.json fehlt\n")
  end
  
  cfg_file:write('```\n\n')
  cfg_file:write("## Ausschnitt gateway/session/auth (ungefiltert, betriebsnah)\n\n")
  cfg_file:write('```json\n')
  
  if file_exists(OPENCLAW_JSON) then
    local snippet = execute_command("sed -n '580,780p' " .. OPENCLAW_JSON)
    if snippet then
      cfg_file:write(snippet .. "\n")
    end
  else
    cfg_file:write('{ "error": "openclaw.json fehlt" }\n')
  end
  
  cfg_file:write('```\n')
  cfg_file:close()
end

-- ENV-Status Datei schreiben
local env_file = io.open(ENV_FILE, "w")
if env_file then
  env_file:write("# ENV-Status: Gateway B / Node 7\n\n")
  env_file:write("Stand: " .. NOW_LOCAL .. "\n\n")
  env_file:write("## Dateien\n\n")
  env_file:write('```text\n')
  
  local env_files_info = execute_command("ls -la " .. ENV_DOT .. " " .. ENV_SYSTEMD .. " 2>/dev/null")
  if env_files_info then
    env_file:write(env_files_info .. "\n")
  end
  
  env_file:write('```\n\n')
  env_file:write("## .env (vollständig, ungefiltert)\n\n")
  env_file:write('```dotenv\n')
  
  if file_exists(ENV_DOT) then
    local env_content = read_file(ENV_DOT)
    if env_content then
      env_file:write(env_content)
    end
  else
    env_file:write("# .env fehlt\n")
  end
  
  env_file:write('```\n\n')
  env_file:write("## gateway.systemd.env (vollständig, ungefiltert)\n\n")
  env_file:write('```dotenv\n')
  
  if file_exists(ENV_SYSTEMD) then
    local systemd_content = read_file(ENV_SYSTEMD)
    if systemd_content then
      env_file:write(systemd_content)
    end
  else
    env_file:write("# gateway.systemd.env fehlt\n")
  end
  
  env_file:write('```\n')
  env_file:close()
end

-- Laufprotokoll Datei schreiben
local run_file = io.open(RUN_FILE, "w")
if run_file then
  run_file:write("# Laufprotokoll Gateway B / Node 7\n\n")
  run_file:write("- Zeit (lokal): " .. NOW_LOCAL .. "\n")
  run_file:write("- Zeit (UTC): " .. NOW_UTC .. "\n")
  run_file:write("- Script: " .. arg[0] .. "\n\n")
  run_file:write("## Erzeugte Dateien\n\n")
  run_file:write("- " .. IST_FILE:match("[^/]*$") .. "\n")
  run_file:write("- " .. INV_FILE:match("[^/]*$") .. "\n")
  run_file:write("- " .. CFG_FILE:match("[^/]*$") .. "\n")
  run_file:write("- " .. ENV_FILE:match("[^/]*$") .. "\n")
  run_file:close()
end

-- Erfolgsmeldung ausgeben
print("OK: IST-Zustand erfasst.")
print("Ausgabeordner: " .. OUT_DIR)
print("Dateien:")

local output_files = execute_command("ls -1 " .. OUT_DIR)
if output_files then
  for line in output_files:gmatch("[^\r\n]+") do
    print("- " .. line)
  end
end
