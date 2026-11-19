#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "09877f1a502a7762e7c0825ff45fe3cd315c2377c7137f5c215805bf55af9147", "source_sha256": "a243d1fdcbd0c82c97b2771c181438428885fd9c2feaed782f7e9eb8066fed59", "target_language": "lua"}
-- offscreen.html — portiert nach lua
-- Quelle: html, Projects@TikTok-Live-Companion:plugin-source/browser-extension/offscreen.html
-- auch in: Projects@TikTok-Live-Companion-Android:plugin-source/browser-extension/offscreen.html
-- auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/browser-extension/offscreen.html
-- auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/browser-extension/offscreen.html
-- Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

-- Funktion zum Erstellen der HTML-Struktur
local function createHTML()
    local html = {}
    
    -- DOCTYPE
    table.insert(html, "<!doctype html>")
    
    -- HTML-Tag mit Sprachattribut
    table.insert(html, "<html lang=\"de\">")
    
    -- HEAD-Bereich
    table.insert(html, "<head>")
    table.insert(html, "  <meta charset=\"utf-8\">")
    table.insert(html, "  <title>TikTok LIVE Companion Sprachausgabe</title>")
    table.insert(html, "</head>")
    
    -- BODY-Bereich
    table.insert(html, "<body>")
    table.insert(html, "  <script src=\"offscreen.js\"></script>")
    table.insert(html, "</body>")
    
    -- Abschluss HTML
    table.insert(html, "</html>")
    
    return table.concat(html, "\n")
end

-- Hauptprogramm
local function main()
    local filename = arg[1]
    
    if not filename then
        io.stderr:write("Fehler: Bitte geben Sie einen Dateinamen als Parameter an.\n")
        os.exit(1)
    end
    
    -- HTML-Inhalt erstellen
    local content = createHTML()
    
    -- In Datei schreiben
    local file, err = io.open(filename, "w")
    if not file then
        io.stderr:write("Fehler beim Öffnen der Datei " .. filename .. ": " .. err .. "\n")
        os.exit(1)
    end
    
    file:write(content)
    file:close()
    
    print("HTML-Datei erfolgreich erstellt: " .. filename)
end

-- Programmstart
main()
