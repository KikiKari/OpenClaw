#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "d6367c5590e2c89758f36d90ab0bbad8be4bc36b848539fdefba227b6e9ce84b", "source_sha256": "735fe4b2c74b10f265f715cd4e85d574f46a7132d2e592703b5e712888470105", "target_language": "lua"}
-- index.html — portiert nach lua
-- Quelle: html, OpenClaw@main:index.html
-- Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

local function createHTMLDocument()
    local html = {}
    
    -- Helper function to add indented lines
    local function addLine(level, content)
        table.insert(html, ("  "):rep(level) .. content)
    end
    
    -- DOCTYPE
    table.insert(html, "<!DOCTYPE html>")
    table.insert(html, "<html lang=\"de\">")
    
    -- Head section
    addLine(1, "<head>")
    
    -- Meta tags
    addLine(2, "<meta charset=\"utf-8\" />")
    addLine(2, "<link rel=\"icon\" href=\"/favicon.ico\" />")
    addLine(2, "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />")
    addLine(2, "<meta name=\"theme-color\" content=\"#0b1020\" />")
    addLine(2, "<meta")
    addLine(3, "name=\"description\"")
    addLine(3, "content=\"OpenClaw Startseite für Repository, Dokumentation und Frontend-Branch.\"")
    addLine(2, "/>")
    addLine(2, "<link rel=\"apple-touch-icon\" href=\"/logo192.png\" />")
    
    -- Comment block
    addLine(2, "<!--")
    addLine(3, "manifest.json provides metadata used when your web app is installed on a")
    addLine(3, "user's mobile device or desktop. See https://developers.google.com/web/fundamentals/web-app-manifest/")
    addLine(2, "-->")
    
    addLine(2, "<link rel=\"manifest\" href=\"/manifest.json\" />")
    addLine(2, "<title>OpenClaw</title>")
    addLine(1, "</head>")
    
    -- Body section
    addLine(1, "<body>")
    addLine(2, "<noscript>You need to enable JavaScript to run this app.</noscript>")
    addLine(2, "<div id=\"root\"></div>")
    
    -- Comment block
    addLine(2, "<!--")
    addLine(3, "This HTML file is a template.")
    addLine(3, "If you open it directly in the browser, you will see an empty page.")
    addLine(3, "")
    addLine(3, "You can add webfonts, meta tags, or analytics to this file.")
    addLine(3, "The build step will place the bundled scripts into the <body> tag.")
    addLine(3, "")
    addLine(3, "To begin the development, run `npm start` or `yarn start`.")
    addLine(3, "To create a production bundle, use `npm run build` or `yarn build`.")
    addLine(2, "-->")
    
    addLine(1, "</body>")
    addLine(1, "<script type=\"module\" src=\"/src/index.jsx\"></script>")
    table.insert(html, "</html>")
    
    return table.concat(html, "\n")
end

-- Main execution
local filename = arg[1] or "index.html"
local content = createHTMLDocument()

local file = io.open(filename, "w")
if not file then
    print("Error: Could not open file " .. filename .. " for writing")
    os.exit(1)
end

file:write(content)
file:close()

print("HTML document written to " .. filename)
