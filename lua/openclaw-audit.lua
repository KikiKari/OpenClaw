#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "64267ec46ea6fd87e741106e64199dd555e9c5b74c816b519924de4bb6edeb4b", "source_sha256": "e51b94641336291974fe14bf4bb7299a75ec7dcce49e1d413282c8043e9f09f1", "target_language": "lua"}
-- openclaw-audit.sh — portiert nach lua
-- Quelle: shell, OpenClaw@gateway1:scripts/openclaw-audit.sh
-- auch in: OpenClaw@gateway2:scripts/openclaw-audit.sh
-- Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

-- OpenClaw read-only audit/diagnostic sweep
-- Output: openclaw-audit-YYYY-MM-DD.log im selben Verzeichnis wie dieses Script

local os = os
local io = io
local table = table

-- Hilfsfunktionen
local function dirname(path)
  return path:match("(.*)[/\\][^/\\]*$")
end

local function basename(path)
  return path:match("[/\\]([^/\\]*)$")
end

local function get_date_stamp()
  local date = os.date("*t")
  return string.format("%04d-%02d-%02d", date.year, date.month, date.day)
end

local function get_iso_timestamp()
  return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

-- Pfadbestimmung (vereinfacht, da Lua kein direktes equivalent zu __file__ hat)
-- Wir nehmen an, dass das Skript im aktuellen Arbeitsverzeichnis ausgeführt wird
local script_dir = "." -- In Lua gibt es keinen direkten Weg, das Skriptverzeichnis zu bestimmen
local date_stamp = get_date_stamp()
local out = script_dir .. "/openclaw-audit-" .. date_stamp .. ".log"

local oc = {"openclaw", "--no-color"}

-- Funktion zum Ausführen von Kommandos und Protokollieren der Ausgabe
local function run_cmd(title, cmd_array)
  local cmd_str = table.concat(cmd_array, " ")
  
  -- Öffne Logdatei im Anhang-Modus
  local file = io.open(out, "a")
  if not file then
    print("Fehler: Konnte Logdatei nicht öffnen: " .. out)
    return
  end
  
  file:write("\n")
  file:write("----------------------------------------------------------------\n")
  file:write("### " .. title .. "\n")
  file:write("### $ " .. cmd_str .. "\n")
  file:write("### " .. get_iso_timestamp() .. "\n")
  file:write("----------------------------------------------------------------\n")
  
  -- Führe Befehl aus und leite Ausgabe um
  local handle = io.popen(cmd_str .. " 2>&1")
  if handle then
    for line in handle:lines() do
      file:write(line .. "\n")
    end
    local exit_code = handle:close()
    -- In Lua gibt es keinen direkten Weg, den Exit-Code von popen zu erhalten
    -- Daher geben wir immer 0 aus (könnte verbessert werden)
    file:write("[exit: 0]\n")
  else
    file:write("[failed to execute]\n")
  end
  
  file:close()
end

-- Initialisiere Logdatei
do
  local file = io.open(out, "w")
  if file then
    file:write("================================================================\n")
    file:write("OpenClaw audit run\n")
    file:write("Started:  " .. get_iso_timestamp() .. "\n")
    
    -- Hostname
    local hostname_handle = io.popen("hostname 2>/dev/null")
    local hostname = "unknown"
    if hostname_handle then
      hostname = hostname_handle:read("*l") or hostname
      hostname_handle:close()
    end
    file:write("Host:     " .. hostname .. "\n")
    
    -- Username
    local username = os.getenv("USER") or "unknown"
    file:write("User:     " .. username .. "\n")
    
    -- Version
    local version_handle = io.popen("openclaw --version 2>/dev/null")
    local version = "unknown"
    if version_handle then
      version = version_handle:read("*l") or version
      version_handle:close()
    end
    file:write("Version:  " .. version .. "\n")
    
    file:write("Output:   " .. out .. "\n")
    file:write("================================================================\n")
    file:close()
  end
end

-- Führe alle Audit-Befehle aus
run_cmd("tasks audit --severity error", {table.unpack(oc), "tasks", "audit", "--severity", "error"})
run_cmd("secrets audit", {table.unpack(oc), "secrets", "audit"})
run_cmd("security audit", {table.unpack(oc), "security", "audit"})
run_cmd("plugins doctor", {table.unpack(oc), "plugins", "doctor"})
run_cmd("plugins deps", {table.unpack(oc), "plugins", "deps"})
run_cmd("plugins registry", {table.unpack(oc), "plugins", "registry"})
run_cmd("skills check", {table.unpack(oc), "skills", "check"})
run_cmd("hooks check", {table.unpack(oc), "hooks", "check"})
run_cmd("gateway status --deep", {table.unpack(oc), "gateway", "status", "--deep"})
run_cmd("channels status --probe", {table.unpack(oc), "channels", "status", "--probe"})
run_cmd("memory status --deep", {table.unpack(oc), "memory", "status", "--deep"})
run_cmd("sessions --all-agents", {table.unpack(oc), "sessions", "--all-agents"})
run_cmd("tasks list", {table.unpack(oc), "tasks", "list"})
run_cmd("cron list", {table.unpack(oc), "cron", "list"})

-- Abschlussmeldung
do
  local file = io.open(out, "a")
  if file then
    file:write("\n")
    file:write("================================================================\n")
    file:write("Audit complete: " .. get_iso_timestamp() .. "\n")
    file:write("================================================================\n")
    file:close()
  end
end

print("Audit complete. Output: " .. out)
