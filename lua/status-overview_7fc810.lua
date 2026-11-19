#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "2f18a557862f895ef4c6cc03e4e00bb5efe18ab5cf6effd63da9fc9febca0778", "source_sha256": "7fc810e8bcb817cb81407c2ad604d4bd70dce9f3ff8cb2bbfbcacfec00febd1c", "target_language": "lua"}
-- status-overview.html — portiert nach lua
-- Quelle: html, Projects@TikTok-Live-Companion:plugin-source/browser-extension/status-overview.html
-- Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

local function create_status_overview(output_file)
    local file = io.open(output_file, "w")
    if not file then
        error("Kann Datei nicht öffnen: " .. output_file)
    end

    -- Schreibe den HTML-Doctype
    file:write("<!doctype html>\n")
    
    -- Öffne das HTML-Dokument und setze das Sprachattribut
    file:write("<html lang=\"de\">")
    
    -- Kopfbereich
    file:write("<head>")
    file:write("<meta charset=\"utf-8\">")
    file:write("<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">")
    file:write("<title>STATUS-Overview</title>")
    file:write("<link rel=\"stylesheet\" href=\"status-overview.css\">")
    file:write("</head>")
    
    -- Körperbereich
    file:write("<body>")
    file:write("<main id=\"grid\" aria-label=\"LIVE-Übersicht\"></main>")
    file:write("<script src=\"vendor-mpegts.js\"></script>")
    file:write("<script src=\"status-overview-player.js\"></script>")
    file:write("</body>")
    
    -- Schließe das HTML-Dokument
    file:write("</html>")
    
    file:close()
end

-- Hauptprogramm
if #arg ~= 1 then
    print("Verwendung: " .. arg[0] .. " <ausgabedatei>")
    os.exit(1)
end

create_status_overview(arg[1])
print("Status-Overview wurde erfolgreich erstellt: " .. arg[1])
