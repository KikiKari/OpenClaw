#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "0c19d905e126726e62981d051f085f6060c957163755d3b8a29b0460e007d664", "source_sha256": "969958657b3b071c8b5067af0ac0287ac68f3fbc6c5832a0339555e3a87d3357", "target_language": "lua"}
-- glossary.go — portiert nach lua
-- Quelle: go, workspace@local:skills/github-clones/openclaw/scripts/docs-i18n/glossary.go
-- Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

local json = require("cjson")

local function LoadGlossary(path)
    local file, err = io.open(path, "r")
    if not file then
        if string.find(err, "No such file or directory") then
            return {}
        end
        return nil, err
    end

    local content = file:read("*a")
    file:close()

    local success, entries = pcall(json.decode, content)
    if not success then
        return nil, "glossary parse failed: " .. entries
    end

    -- Konvertiere das JSON-Array in ein Lua-Array
    local result = {}
    for _, entry in ipairs(entries) do
        table.insert(result, {
            source = entry.source,
            target = entry.target
        })
    end

    return result
end

-- Exportiere die Funktion (falls in einem Modul verwendet)
return {
    LoadGlossary = LoadGlossary
}
