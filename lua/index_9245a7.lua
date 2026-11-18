#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "dded6d5c44a9b422743201dc3e00a321e313a59be28382dd60b829011a77d501", "source_sha256": "9245a78489adb3949ae2a56f5e0987a465142b9a8ee97bddaca453f5011daef8", "target_language": "lua"}
-- index.html — portiert nach lua
-- Quelle: html, Projects@Program-Derivation:public/index.html
-- auch in: Projects@Vision-Check:public/index.html
-- auch in: Projects@Weather-Check:public/index.html
-- auch in: Projects@abstractions:public/index.html
-- auch in: 5 weiteren Fundstellen
-- Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

local function create_html_document()
    local html = {}
    
    -- DOCTYPE
    table.insert(html, "<!DOCTYPE html>")
    table.insert(html, "<html lang=\"de\">")
    
    -- Head section
    table.insert(html, "<head>")
    table.insert(html, "<meta charset=\"utf-8\">")
    table.insert(html, "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">")
    table.insert(html, "<meta http-equiv=\"refresh\" content=\"0; url=3d.html\">")
    table.insert(html, "<title>Weiterleitung zur 3D-Ansicht</title>")
    table.insert(html, "<link rel=\"canonical\" href=\"3d.html\">")
    table.insert(html, "<script>location.replace('3d.html');</script>")
    table.insert(html, "</head>")
    
    -- Body section
    table.insert(html, "<body>")
    table.insert(html, "<p><a href=\"3d.html\">3D-Ansicht öffnen</a></p>")
    table.insert(html, "</body>")
    
    table.insert(html, "</html>")
    
    return table.concat(html, "\n")
end

local function write_to_file(filename, content)
    local file = io.open(filename, "w")
    if file then
        file:write(content)
        file:close()
        return true
    else
        return false
    end
end

-- Main execution
local output_filename = arg[1] or "index.html"
local html_content = create_html_document()

if write_to_file(output_filename, html_content) then
    print("HTML document created successfully: " .. output_filename)
else
    print("Error: Could not write to file " .. output_filename)
    os.exit(1)
end
