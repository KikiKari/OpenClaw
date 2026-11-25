#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "28bff1258a6cc50b2520163bed27af120899033602f26c94a070fe9b5ec51efe", "source_sha256": "bd1408a3d37597ed2c41b37fe2104f806ee5ea009396e16c58748eb01356bfb6", "target_language": "lua"}
-- tm.go — portiert nach lua
-- Quelle: go, workspace@local:skills/github-clones/openclaw/scripts/docs-i18n/tm.go
-- Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

local json = require("cjson")
local posix = require("posix")

local TMEntry = {}
TMEntry.__index = TMEntry

function TMEntry:new(o)
    o = o or {}
    setmetatable(o, self)
    return o
end

local TranslationMemory = {}
TranslationMemory.__index = TranslationMemory

function TranslationMemory:new(path)
    local obj = {
        path = path,
        entries = {}
    }
    setmetatable(obj, self)
    return obj
end

function TranslationMemory:load()
    local file, err = io.open(self.path, "r")
    if not file then
        if string.find(err, "No such file or directory") then
            return true
        else
            return nil, err
        end
    end

    for line in file:lines() do
        local trimmed = line:match("^%s*(.-)%s*$")
        if trimmed ~= "" then
            local entry, decode_err = json.decode(trimmed)
            if not entry then
                file:close()
                return nil, "translation memory decode failed: " .. decode_err
            end
            if entry.cache_key and entry.cache_key ~= "" and (entry.translated or ""):match("%S") then
                self.entries[entry.cache_key] = TMEntry:new({
                    cache_key = entry.cache_key,
                    segment_id = entry.segment_id,
                    source_path = entry.source_path,
                    text_hash = entry.text_hash,
                    text = entry.text,
                    translated = entry.translated,
                    provider = entry.provider,
                    model = entry.model,
                    src_lang = entry.src_lang,
                    tgt_lang = entry.tgt_lang,
                    updated_at = entry.updated_at
                })
            end
        end
    end

    file:close()
    return true
end

function TranslationMemory:get(cacheKey)
    local entry = self.entries[cacheKey]
    if not entry then
        return nil, false
    end
    if not entry.translated or entry.translated:match("^%s*$") then
        return nil, false
    end
    return entry, true
end

function TranslationMemory:put(entry)
    if not entry.cache_key or entry.cache_key == "" then
        return
    end
    self.entries[entry.cache_key] = entry
end

function TranslationMemory:save()
    if not self.path or self.path == "" then
        return true
    end

    local dir = self.path:match("^(.+)/[^/]*$")
    if dir then
        local success, err = posix.mkdir(dir, "rwxr-xr-x")
        if not success and not string.find(err, "File exists") then
            return nil, err
        end
    end

    local tmpPath = self.path .. ".tmp"
    local file, err = io.open(tmpPath, "w")
    if not file then
        return nil, err
    end

    local keys = {}
    for key in pairs(self.entries) do
        table.insert(keys, key)
    end
    table.sort(keys)

    for _, key in ipairs(keys) do
        local entry = self.entries[key]
        local payload, encode_err = json.encode({
            cache_key = entry.cache_key,
            segment_id = entry.segment_id,
            source_path = entry.source_path,
            text_hash = entry.text_hash,
            text = entry.text,
            translated = entry.translated,
            provider = entry.provider,
            model = entry.model,
            src_lang = entry.src_lang,
            tgt_lang = entry.tgt_lang,
            updated_at = entry.updated_at
        })
        if not payload then
            file:close()
            os.remove(tmpPath)
            return nil, "JSON encoding error: " .. encode_err
        end
        local write_ok, write_err = file:write(payload .. "\n")
        if not write_ok then
            file:close()
            os.remove(tmpPath)
            return nil, write_err
        end
    end

    local flush_ok, flush_err = file:flush()
    if not flush_ok then
        file:close()
        os.remove(tmpPath)
        return nil, flush_err
    end

    local close_ok, close_err = file:close()
    if not close_ok then
        os.remove(tmpPath)
        return nil, close_err
    end

    local rename_ok, rename_err = os.rename(tmpPath, self.path)
    if not rename_ok then
        os.remove(tmpPath)
        return nil, rename_err
    end

    return true
end

function LoadTranslationMemory(path)
    local tm = TranslationMemory:new(path)
    local success, err = tm:load()
    if not success then
        return nil, err
    end
    return tm
end

-- Export functions
return {
    TMEntry = TMEntry,
    TranslationMemory = TranslationMemory,
    LoadTranslationMemory = LoadTranslationMemory
}
