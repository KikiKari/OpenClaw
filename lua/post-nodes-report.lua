#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "56fc71e8ffcb6c2eca2c011e324f811015603fb00c329b09d18518d9aa2b0535", "source_sha256": "04afaeaf031d1de3a9c71606dba8c1d6ea78b3b575d8ecf94af9256d4dc3886d", "target_language": "lua"}
-- post-nodes-report.js — portiert nach lua
-- Quelle: javascript, OpenClaw@gateway1:scripts/post-nodes-report.js
-- auch in: OpenClaw@gateway2:scripts/post-nodes-report.js
-- Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

local fs = require("fs")
local path = require("path")

-- Pfade
local DASHBOARD_PATH = path.join(__dirname, "../dashboards/nodes-overview.md")
local REPORT_LOG = path.join(__dirname, "../logs/nodes-report.log")

-- Farbcodes
local C = {
    green = "\27[32m",
    yellow = "\27[33m",
    red = "\27[31m",
    reset = "\27[0m"
}

local function postReport()
    local content, err = fs.readFileSync(DASHBOARD_PATH, "utf-8")
    if err then
        io.stderr:write(C.red .. "❌ Fehler beim Lesen der Dashboard-Datei:" .. C.reset .. " " .. err .. "\n")
        return
    end

    -- Nachricht über OpenClaw message senden
    local escaped_content = content:gsub("\n", "\\n"):gsub('"', '\\"')
    local message_cmd = 'openclaw message send --target=main --message "' .. escaped_content .. '"'

    local handle = io.popen(message_cmd .. " 2>&1", "r")
    local result = handle:read("*a")
    local success, exit_reason, exit_code = handle:close()

    if success then
        print(C.green .. "✅ Report erfolgreich im 'main'-Channel gepostet." .. C.reset)
        fs.appendFileSync(REPORT_LOG, "[" .. os.date("!%Y-%m-%dT%H:%M:%SZ") .. "] Report posted.\n")
    else
        io.stderr:write(C.red .. "❌ Fehler beim Senden der Nachricht:" .. C.reset .. " " .. (result or exit_reason) .. "\n")
        fs.appendFileSync(REPORT_LOG, "[" .. os.date("!%Y-%m-%dT%H:%M:%SZ") .. "] Failed to post: " .. (result or exit_reason) .. "\n")
    end
end

-- Hauptausführung
print(C.yellow .. "📤 Sende Nodes-Übersicht in 'main'..." .. C.reset)
postReport()
