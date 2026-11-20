#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "ca95278e265602bbfba7aa89458a3bc2e777dc316e85d837ab23a40cacb02f97", "source_sha256": "c5da3d5a6d1b96d5dbfcceb3eeaaf1082185c08fa2edcbc7b87c36871484ccf2", "target_language": "lua"}
-- docker-e2e-logs.sh — portiert nach lua
-- Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/lib/docker-e2e-logs.sh
-- Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

function run_logged(label, ...)
  local tmpdir = os.getenv("TMPDIR") or "/tmp"
  local log_file = os.tmpname()
  
  -- Umleitung der Ausgabe in die Logdatei
  local old_stdout = io.stdout
  local old_stderr = io.stderr
  
  local file = io.open(log_file, "w")
  if not file then
    error("Konnte Logdatei nicht erstellen: " .. log_file)
  end
  
  io.stdout = file
  io.stderr = file
  
  -- Befehl ausführen
  local success, exit_code, exit_signal = os.execute(table.concat({...}, " "))
  
  file:close()
  
  -- Wiederherstellen der normalen Ausgabe
  io.stdout = old_stdout
  io.stderr = old_stderr
  
  -- Inhalt der Logdatei ausgeben, falls der Befehl fehlgeschlagen ist
  if not success then
    local file = io.open(log_file, "r")
    if file then
      io.stdout:write(file:read("*a"))
      file:close()
    end
    os.remove(log_file)
    return false
  end
  
  os.remove(log_file)
  return true
end
