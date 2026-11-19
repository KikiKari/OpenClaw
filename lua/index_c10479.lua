#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "940d1959a0be79065bd130fb29a8053aca61fa1fb17547ddaf153bea2f038fc4", "source_sha256": "c10479f79ca5554fe399cf2f5d70fb5b32e837c1c7a846eb7dd7c9e9e5319c66", "target_language": "lua"}
-- index.html — portiert nach lua
-- Quelle: html, Projects@TikTok-Live-Companion:site/index.html
-- auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:site/index.html
-- auch in: Projects@vercel/install-and-configure-vercel-w-98sxlo:site/index.html
-- Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

local function create_html_document()
    local html = {}

    -- Helper function to add a line with proper indentation
    local function add(level, content)
        table.insert(html, ("  "):rep(level) .. content)
    end

    -- Document type declaration
    table.insert(html, "<!doctype html>")
    
    -- Start of HTML document
    add(0, "<html lang=\"de\">")
    
    -- Head section
    add(1, "<head>")
    add(2, "<meta charset=\"UTF-8\" />")
    add(2, "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\" />")
    add(2, "<meta name=\"description\" content=\"Dokumentation für TikTok LIVE Companion 0.8.2 – Chat-TTS, Zuschauerstatistik, Songerkennung und Stream-Informationen direkt im Browser.\" />")
    add(2, "<meta name=\"theme-color\" content=\"#ffffff\" />")
    add(2, "<link rel=\"icon\" type=\"image/png\" href=\"/branding/staenderglobus-ios.png\" />")
    add(2, "<link rel=\"apple-touch-icon\" href=\"/branding/staenderglobus-ios.png\" />")
    add(2, "<title>TikTok LIVE Companion – Dokumentation</title>")
    add(1, "</head>")
    
    -- Body section
    add(1, "<body>")
    add(2, "<div id=\"root\"></div>")
    add(2, "<script type=\"module\" src=\"/src/main.tsx\"></script>")
    add(1, "</body>")
    
    -- End of HTML document
    add(0, "</html>")

    return table.concat(html, "\n")
end

-- Main execution
local function main()
    local filename = arg[1] or "index.html"
    local content = create_html_document()
    
    local file = io.open(filename, "w")
    if not file then
        error("Could not open file: " .. filename)
    end
    
    file:write(content)
    file:close()
    
    print("HTML document created successfully: " .. filename)
end

main()
