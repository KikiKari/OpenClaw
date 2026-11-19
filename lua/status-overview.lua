#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "e1798408553b7129d784c75f3282b429acaf59c1cea7b5b820cd7be36d11a5c4", "source_sha256": "f95cba00197f4650dddde02431fe14a0ca1baea932052e66b16f5778582e944f", "target_language": "lua"}
-- status-overview.css — portiert nach lua
-- Quelle: css, Projects@TikTok-Live-Companion:plugin-source/browser-extension/status-overview.css
-- Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

local function generate_css(output_file)
    local css = [[
* {
    box-sizing: border-box;
}

html, body {
    margin: 0;
    min-height: 100%;
    background: #101015;
    color: #fff;
    font: 14px system-ui, sans-serif;
}

body {
    display: flex;
    flex-direction: column;
    height: 100vh;
}

header {
    display: flex;
    gap: 1em;
    align-items: baseline;
    padding: 0 12px;
}

h1 {
    font-size: 17px;
    margin: 8px 0;
}

header p {
    font-size: 12px;
    color: #bbb;
    margin: 0;
}

main {
    flex: 1;
    min-height: 0;
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    grid-template-rows: repeat(3, minmax(0, 1fr));
    gap: 4px;
    padding: 0;
}

.tile {
    min-width: 0;
    min-height: 0;
    display: flex;
    flex-direction: column;
    background: #202026;
    border: 1px solid #393940;
}

.tile h2 {
    font-size: 13px;
    margin: 3px 8px;
}

.tile video {
    min-height: 0;
    width: 100%;
    flex: 1;
    object-fit: contain;
    background: #000;
}

.tile p {
    font-size: 11px;
    margin: 3px 8px;
    color: #ddd;
}

main.grid2 {
    grid-template-columns: repeat(2, minmax(0, 1fr));
    grid-template-rows: repeat(2, minmax(0, 1fr));
}

.tile[hidden] {
    display: none;
}
]]

    local file = io.open(output_file, "w")
    if not file then
        error("Could not open file for writing: " .. output_file)
    end
    
    file:write(css)
    file:close()
end

-- Main execution
local output_path = arg[1] or "status-overview.css"
generate_css(output_path)
print("CSS file generated: " .. output_path)
