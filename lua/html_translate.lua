#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "78f0fa67e1ae81d2319959df88035bd8a714b69cc55d122f2af83eac9ca2b69e", "source_sha256": "04efde297083102c20b5caf33f76d4e5638a8f6b50c3d7c5e9b15e889a91b227", "target_language": "lua"}
-- html_translate.go — portiert nach lua
-- Quelle: go, workspace@local:skills/github-clones/openclaw/scripts/docs-i18n/html_translate.go
-- Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

local html = require("htmlparser")
local utf8 = require("utf8")

-- htmlReplacement represents a replacement operation for HTML content
local htmlReplacement = {}
htmlReplacement.__index = htmlReplacement

function htmlReplacement:new(start, stop, value)
    local obj = {
        Start = start,
        Stop = stop,
        Value = value
    }
    setmetatable(obj, htmlReplacement)
    return obj
end

-- translateHTMLBlocks translates HTML blocks within markdown content
function translateHTMLBlocks(ctx, translator, body, srcLang, tgtLang)
    -- In Lua we don't have goldmark, so we'll use a simple approach to find HTML blocks
    -- This is a simplified version that looks for HTML blocks between ```html and ```
    
    local replacements = {}
    local pos = 1
    
    while true do
        local startPattern = "```html"
        local startIdx = body:find(startPattern, pos, true)
        if not startIdx then break end
        
        local contentStart = startIdx + #startPattern
        local endIdx = body:find("```", contentStart, true)
        if not endIdx then break end
        
        local htmlContent = body:sub(contentStart, endIdx - 1)
        local trimmedContent = htmlContent:gsub("^%s*(.-)%s*$", "%1")
        
        if #trimmedContent > 0 then
            local translated, err = translateHTMLBlock(ctx, translator, trimmedContent, srcLang, tgtLang)
            if err then return nil, err end
            
            local fullBlock = "```html" .. htmlContent .. "```"
            table.insert(replacements, htmlReplacement:new(startIdx - 1, endIdx + 2, "```html\n" .. translated .. "\n```"))
        end
        
        pos = endIdx + 3
    end
    
    if #replacements == 0 then
        return body, nil
    end
    
    return applyHTMLReplacements(body, replacements), nil
end

-- htmlBlockSpan determines the span of an HTML block in source
-- Simplified implementation for Lua
function htmlBlockSpan(block, source)
    -- This function would need proper implementation based on how HTML blocks are represented in Lua
    -- For now returning dummy values
    return 0, 0, false
end

-- applyHTMLReplacements applies replacements to the body
function applyHTMLReplacements(body, replacements)
    if #replacements == 0 then
        return body
    end
    
    sortHTMLReplacements(replacements)
    
    local out = {}
    local last = 1
    
    for _, rep in ipairs(replacements) do
        if rep.Start >= last then
            table.insert(out, body:sub(last, rep.Start))
            table.insert(out, rep.Value)
            last = rep.Stop + 1
        end
    end
    
    table.insert(out, body:sub(last))
    return table.concat(out)
end

-- sortHTMLReplacements sorts replacements by start position
function sortHTMLReplacements(replacements)
    table.sort(replacements, function(a, b)
        return a.Start < b.Start
    end)
end

-- translateHTMLBlock translates individual HTML content
function translateHTMLBlock(ctx, translator, htmlText, srcLang, tgtLang)
    local tokenizer = html.parser(htmlText)
    local out = {}
    local skipDepth = 0
    
    for _, token in ipairs(tokenizer:parse()) do
        local raw = token.raw or ""
        
        if token.type == "starttag" then
            table.insert(out, raw)
            if isSkipTag(string.lower(token.name or "")) then
                skipDepth = skipDepth + 1
            end
        elseif token.type == "endtag" then
            table.insert(out, raw)
            if isSkipTag(string.lower(token.name or "")) and skipDepth > 0 then
                skipDepth = skipDepth - 1
            end
        elseif token.type == "selftag" then
            table.insert(out, raw)
        elseif token.type == "text" then
            if shouldTranslateHTMLText(skipDepth, raw) then
                local translated, err = translator.Translate(ctx, raw, srcLang, tgtLang)
                if err then return nil, err end
                table.insert(out, translated)
            else
                table.insert(out, raw)
            end
        else
            table.insert(out, raw)
        end
    end
    
    return table.concat(out), nil
end

-- shouldTranslateHTMLText determines if text should be translated
function shouldTranslateHTMLText(skipDepth, text)
    if not text then return false end
    return skipDepth == 0 and text:match("%S") ~= nil
end

-- isSkipTag checks if a tag should be skipped during translation
function isSkipTag(tag)
    local skipTags = {
        code = true,
        pre = true,
        script = true,
        style = true
    }
    return skipTags[tag] or false
end

return {
    translateHTMLBlocks = translateHTMLBlocks,
    htmlBlockSpan = htmlBlockSpan,
    applyHTMLReplacements = applyHTMLReplacements,
    sortHTMLReplacements = sortHTMLReplacements,
    translateHTMLBlock = translateHTMLBlock,
    shouldTranslateHTMLText = shouldTranslateHTMLText,
    isSkipTag = isSkipTag
}
