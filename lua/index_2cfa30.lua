#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "5fab601aa634dd015db9d7fe3383f2c3fd981e95feba645ddedef8e03652cbd0", "source_sha256": "2cfa301efe20d60c29e0e9f0746e5a99d405ea44a5d03839c72e6b525451fe07", "target_language": "lua"}
-- index.html — portiert nach lua
-- Quelle: html, Projects@TikTok-Live-Companion-Android:site/index.html
-- auch in: Projects@TikTok-Live-Companion-iOS:site/index.html
-- Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

local function createHtmlDocument()
    local html = {}
    
    -- Helper function to add indented lines
    local function add(level, content)
        table.insert(html, ("  "):rep(level) .. content)
    end
    
    -- DOCTYPE
    table.insert(html, "<!doctype html>")
    
    -- HTML root
    add(0, "<html lang=\"de\">")
    
    -- Head section
    add(1, "<head>")
    
    -- Meta tags
    add(2, "<meta charset=\"UTF-8\" />")
    add(2, "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\" />")
    add(2, "<meta name=\"description\" content=\"Dokumentation für TikTok LIVE Companion 0.8.0 – Chat-TTS, Zuschauerstatistik, Songerkennung und Stream-Informationen direkt im Browser.\" />")
    add(2, "<meta name=\"theme-color\" content=\"#ffffff\" />")
    
    -- Link tags
    add(2, "<link rel=\"icon\" type=\"image/png\" href=\"/branding/staenderglobus-ios.png\" />")
    add(2, "<link rel=\"apple-touch-icon\" href=\"/branding/staenderglobus-ios.png\" />")
    
    -- Title
    add(2, "<title>TikTok LIVE Companion – Dokumentation</title>")
    
    add(1, "</head>")
    
    -- Body section
    add(1, "<body>")
    
    -- Root div
    add(2, "<div id=\"root\"></div>")
    
    -- Script tag
    add(2, "<script type=\"module\" src=\"/src/main.tsx\"></script>")
    
    add(1, "</body>")
    add(0, "</html>")
    
    return table.concat(html, "\n")
end

local function writeToFile(content, filename)
    local file = io.open(filename, "w")
    if not file then
        error("Could not open file: " .. filename)
    end
    file:write(content)
    file:close()
end

-- Main execution
local args = {...}
local outputFile = args[1] or "index.html"

local htmlContent = createHtmlDocument()
writeToFile(htmlContent, outputFile)

print("HTML document created successfully: " .. outputFile)
