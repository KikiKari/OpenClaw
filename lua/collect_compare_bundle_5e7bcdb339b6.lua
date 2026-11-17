#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "5917a1efcb04d4741ad76c2ad791f73896d0f551f8973c9cc70ced836302a6d2", "source_sha256": "5aa602a80e57cbc63f54485d4cd66e205c54bd9f32bc03434218ff9bd388b3ab", "target_language": "lua"}
-- collect_compare_bundle.sh — portiert nach lua
-- Quelle: shell, OpenClaw@gateway1:scripts/collect_compare_bundle.sh
-- auch in: OpenClaw@gateway2:scripts/collect_compare_bundle.sh
-- Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

local ROOT = "/home/openclaw/.openclaw"
local OUT_DIR = ROOT .. "/workspace/vscode/compare"
local TRANSFER_DIR = OUT_DIR .. "/transfer"
local MD_FILE = OUT_DIR .. "/local-gateway-config.md"
local TREE_FILE = OUT_DIR .. "/tree.txt"
local BACKUP_FILE = "/home/openclaw/openclaw-backup.tar.gz"

-- Hilfsfunktionen für Datum und Hostname
local function get_local_time()
  local now = os.date("*t")
  return string.format("%04d-%02d-%02d %02d:%02d:%02d %s", 
    now.year, now.month, now.day, now.hour, now.min, now.sec, 
    os.date("%Z"))
end

local function get_utc_time()
  local utc_now = os.date("!*t")
  return string.format("%04d-%02d-%02dT%02d:%02d:%02dZ", 
    utc_now.year, utc_now.month, utc_now.day, utc_now.hour, utc_now.min, utc_now.sec)
end

local function get_hostname()
  local handle = io.popen("hostname -f 2>/dev/null || hostname")
  local result = handle:read("*l")
  handle:close()
  return result or "unknown"
end

local NOW_LOCAL = get_local_time()
local NOW_UTC = get_utc_time()
local HOST = get_hostname()

local OPENCLAW_JSON = ROOT .. "/openclaw.json"
local EXEC_APPROVALS_JSON = ROOT .. "/exec-approvals.json"
local GATEWAY_SYSTEMD_ENV = ROOT .. "/gateway.systemd.env"
local DOT_ENV = ROOT .. "/.env"
local CONFIG_DIR = ROOT .. "/.config"
local AGENTS_DIR = ROOT .. "/agents"

-- Erstelle Verzeichnisse
os.execute("mkdir -p " .. OUT_DIR)
os.execute("mkdir -p " .. TRANSFER_DIR)

-- Prüfe ob 'tree' verfügbar ist
local tree_check = io.popen("command -v tree >/dev/null 2>&1 && echo found")
local tree_available = tree_check:read("*l") == "found"
tree_check:close()

if not tree_available then
  print("Fehler: 'tree' ist nicht installiert.")
  os.exit(1)
end

-- Funktion zum Anhängen von Dateiinhalten
local function append_file_verbatim(label, path, lang)
  lang = lang or "text"
  local file = io.open(MD_FILE, "a")
  
  file:write("\n## " .. label .. "\n\n")
  file:write("Pfad: `" .. path .. "`\n\n")
  file:write("```" .. lang .. "\n")
  
  local content_file = io.open(path, "r")
  if content_file then
    file:write(content_file:read("*a"))
    content_file:close()
  else
    file:write("[FEHLT] " .. path .. "\n")
  end
  
  file:write("\n```\n")
  file:close()
end

-- Funktion zum Anhängen der Umgebungsvariablen
local function append_env_verbatim()
  local file = io.open(MD_FILE, "a")
  file:write("\n## Umgebungsvariablen (env)\n\n")
  file:write("```text\n")
  
  local env_handle = io.popen("env")
  file:write(env_handle:read("*a"))
  env_handle:close()
  
  file:write("```\n")
  file:close()
end

-- Funktion zum Rekursiven Sammeln von Dateien
local function get_files_recursive(dir)
  local files = {}
  local function scan(current_dir)
    local handle = io.popen("ls -A \"" .. current_dir .. "\" 2>/dev/null")
    for line in handle:lines() do
      if line ~= "." and line ~= ".." then
        local full_path = current_dir .. "/" .. line
        local attr = io.popen("stat -c '%F' \"" .. full_path .. "\" 2>/dev/null"):read("*l")
        if attr and attr:match("directory") then
          scan(full_path)
        elseif attr and attr:match("regular file") then
          table.insert(files, full_path)
        end
      end
    end
    handle:close()
  end
  scan(dir)
  table.sort(files)
  return files
end

-- Funktion zum Anhängen von Verzeichnisinhalten
local function append_dir_files_verbatim(section, dir)
  local file = io.open(MD_FILE, "a")
  file:write("\n## " .. section .. "\n\n")
  
  local attr = io.popen("stat -c '%F' \"" .. dir .. "\" 2>/dev/null"):read("*l")
  if not attr or not attr:match("directory") then
    file:write("[FEHLT] " .. dir .. "\n")
    file:close()
    return
  end
  
  file:write("Basisverzeichnis: `" .. dir .. "`\n")
  file:close()
  
  local files = get_files_recursive(dir)
  for _, f in ipairs(files) do
    local md = io.open(MD_FILE, "a")
    md:write("\n### Datei: `" .. f .. "`\n\n")
    md:write("```text\n")
    
    local content_file = io.open(f, "r")
    if content_file then
      md:write(content_file:read("*a"))
      content_file:close()
    end
    
    md:write("\n```\n")
    md:close()
  end
end

-- Initialisiere MD-Datei
local md_init = io.open(MD_FILE, "w")
md_init:write("# Lokaler Gateway-Konfigurationsstand\n\n")
md_init:write("Generiert: " .. NOW_LOCAL .. "\n")
md_init:write("UTC: " .. NOW_UTC .. "\n")
md_init:write("Host: " .. HOST .. "\n\n")
md_init:write("Diese Datei enthaelt den lokalen Stand mit unveraenderten Inhalten.\n")
md_init:close()

-- Führe Sammlungen durch
append_file_verbatim("openclaw.json", OPENCLAW_JSON, "json")
append_file_verbatim("exec-approvals.json", EXEC_APPROVALS_JSON, "json")
append_file_verbatim("gateway.systemd.env", GATEWAY_SYSTEMD_ENV, "dotenv")
append_file_verbatim(".env", DOT_ENV, "dotenv")
append_env_verbatim()
append_dir_files_verbatim(".config (alle Dateien rekursiv)", CONFIG_DIR)
append_dir_files_verbatim("agents (alle Dateien rekursiv)", AGENTS_DIR)

-- Erzeuge Baumansicht und Backup
os.execute("tree -a -L 6 \"" .. ROOT .. "\" > \"" .. TREE_FILE .. "\"")
os.execute("openclaw backup create --output \"" .. BACKUP_FILE .. "\" --verify")
os.execute("cp \"" .. BACKUP_FILE .. "\" \"" .. OUT_DIR .. "\"")

print("OK")
print("Erzeugt:")
print("- " .. MD_FILE)
print("- " .. TREE_FILE)
print("- " .. BACKUP_FILE)
print("- " .. TRANSFER_DIR .. " (leer)")
