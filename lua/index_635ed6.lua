#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "e6a8938173b0963072430cda1ce43c26acc13486303c9c073c25d7218276f8c3", "source_sha256": "635ed6e934aa27ffc7ad156af00126e0797ae1d1c065daddb996e2bddc8cbeb3", "target_language": "lua"}
-- index.html — portiert nach lua
-- Quelle: html, workspace@local:skills/github-clones/openclaw/extensions/qa-lab/web/index.html
-- Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

local function createHTMLDocument()
    local html = {}
    
    -- Helper function to add a line to our html table
    local function addLine(line)
        table.insert(html, line)
    end
    
    -- Add doctype
    addLine("<!doctype html>")
    
    -- Start html tag
    addLine("<html lang=\"en\">")
    
    -- Head section
    addLine("  <head>")
    addLine("    <meta charset=\"utf-8\" />")
    addLine("    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />")
    addLine("    <meta name=\"color-scheme\" content=\"light dark\" />")
    addLine("    <title>QA Lab</title>")
    addLine("  </head>")
    
    -- Body section
    addLine("  <body>")
    addLine("    <div id=\"app\"></div>")
    addLine("    <script type=\"module\" src=\"/src/main.ts\"></script>")
    addLine("  </body>")
    
    -- Close html tag
    addLine("</html>")
    
    return table.concat(html, "\n")
end

-- Main execution
local function main()
    local filename = arg[1]
    
    if not filename then
        print("Usage: " .. arg[0] .. " <output-file>")
        os.exit(1)
    end
    
    local content = createHTMLDocument()
    
    local file = io.open(filename, "w")
    if not file then
        print("Error: Could not open file " .. filename .. " for writing")
        os.exit(1)
    end
    
    file:write(content)
    file:close()
    
    print("HTML document written to " .. filename)
end

main()
