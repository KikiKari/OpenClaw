#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "a125afb5e0edd10baf60dc88dff2d682b5b4152d03fc4e0ac8b1ea64162cf653", "source_sha256": "e31da3d72f8d806a159d6709f37f55500c7f16939f04c094f2ab46a959e70c57", "target_language": "lua"}
-- translation-worker-node5.ps1 — portiert nach lua
-- Quelle: powershell, workspace@local:skills/multi-nodes-utils/scripts/translation-worker-node5.ps1
-- Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

local argparse = require 'argparse'
local sha2 = require 'sha2'
local posix = require 'posix'

-- Hilfsfunktionen
local function file_exists(path)
    local f = io.open(path, "r")
    if f then
        f:close()
        return true
    else
        return false
    end
end

local function get_file_hash(filepath)
    local f = assert(io.open(filepath, "rb"))
    local content = f:read("*all")
    f:close()
    local hash = sha2.sha256(content)
    return hash:lower()
end

local function which(name)
    local separator = package.config:sub(1,1) == "\\" and ";" or ":"
    for path in (os.getenv("PATH") or ""):gmatch("[^"..separator.."]+") do
        local filepath = path .. "/" .. name
        if file_exists(filepath) then
            return filepath
        end
    end
    return nil
end

-- Argumente parsen
local parser = argparse.ArgumentParser()
parser:add_argument('action'):choices({'prepare', 'run'})
local args = parser:parse()

-- Fehlerbehandlung aktivieren
-- In Lua wird ein Fehler mit error() ausgelöst, was dem Verhalten entspricht

-- Konfiguration
local worker = os.getenv("HOME") .. "/.openclaw/workers/translation_worker.py"
local expected = "9f8e810dd49f30fbc05064a98faf280d1f2480fdb8f125115ad006d486cd555b"

-- Prüfung ob Worker existiert
if not file_exists(worker) then
    error("Worker missing: " .. worker)
end

-- Prüfung auf symbolischen Link (vereinfacht)
-- Hinweis: Dies ist eine vereinfachte Prüfung. In einer echten Umgebung könnte dies komplexer sein.
local stat = posix.stat(worker, "type")
if stat == "link" then
    error("Worker link rejected")
end

-- Prüfung der Prüfsumme
local actual_hash = get_file_hash(worker)
if actual_hash ~= expected then
    error("Worker checksum mismatch")
end

-- Python-Pfad finden
local python_path = which("python3") or which("python")
if not python_path then
    error("Python not found")
end

-- Aktion ausführen
if args.action == "prepare" then
    print("Worker verified: " .. worker)
    os.exit(0)
elseif args.action == "run" then
    -- Skript ausführen
    local result = os.execute(python_path .. " " .. worker)
    if type(result) == "number" then
        os.exit(result)
    else
        -- Für Lua 5.1, os.execute gibt true/false zurück
        os.exit(result and 0 or 1)
    end
end
