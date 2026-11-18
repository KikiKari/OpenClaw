#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "cbb3500731f43a99ca20428c06a1b49fa91c6cf6c4964e871af59a9c57eeb7ec", "source_sha256": "daf22c296c801d3d533083361cc59fbdc22e5bfe528aa4bad1973b54cc5448a4", "target_language": "lua"}
-- index.css — portiert nach lua
-- Quelle: css, OpenClaw@main:src/index.css
-- Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

local function generateCSS()
    local css = {}

    -- Add body styles
    table.insert(css, "body {")
    table.insert(css, "  margin: 0;")
    table.insert(css, "  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen',")
    table.insert(css, "    'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue',")
    table.insert(css, "    sans-serif;")
    table.insert(css, "  -webkit-font-smoothing: antialiased;")
    table.insert(css, "  -moz-osx-font-smoothing: grayscale;")
    table.insert(css, "}")
    table.insert(css, "")

    -- Add code styles
    table.insert(css, "code {")
    table.insert(css, "  font-family: source-code-pro, Menlo, Monaco, Consolas, 'Courier New',")
    table.insert(css, "    monospace;")
    table.insert(css, "}")

    return table.concat(css, "\n")
end

local function writeCSSToFile(filename)
    local content = generateCSS()
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
if #arg ~= 1 then
    print("Usage: " .. arg[0] .. " <output-file>")
    os.exit(1)
end

local outputFile = arg[1]
if writeCSSToFile(outputFile) then
    print("CSS file generated successfully: " .. outputFile)
else
    print("Error: Could not write to file " .. outputFile)
    os.exit(1)
end
