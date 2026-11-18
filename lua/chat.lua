#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "c354a60bd7deb651415dad83ddd10d2f33735a2de2920ab6306dead0cd6d4b94", "source_sha256": "f1fb75db28e47070c42c0b401c9bdae5ac468bcd98550232038e409983691fad", "target_language": "lua"}
-- chat.css — portiert nach lua
-- Quelle: css, workspace@local:skills/github-clones/openclaw/ui/src/styles/chat.css
-- Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

local function writeCSSFile(filename)
    local content = {
        "@import \"./chat/layout.css\";",
        "@import \"./chat/text.css\";",
        "@import \"./chat/grouped.css\";",
        "@import \"./chat/tool-cards.css\";",
        "@import \"./chat/sidebar.css\";"
    }
    
    local file = io.open(filename, "w")
    if not file then
        error("Cannot open file "..filename.." for writing")
    end
    
    for _, line in ipairs(content) do
        file:write(line.."\n")
    end
    
    file:close()
end

if #arg ~= 1 then
    print("Usage: "..arg[0].." <output-file>")
    os.exit(1)
end

writeCSSFile(arg[1])
