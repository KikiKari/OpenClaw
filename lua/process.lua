#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "4911699aa0a8737e8188969a4f66543e4563ebb039da21bfb3d08e23dac8d776", "source_sha256": "d00d873eeab51d166892e3bc7f2dd08b6f535b2c11988d1bb7bc0c123b76e82d", "target_language": "lua"}
-- process.go — portiert nach lua
-- Quelle: go, workspace@local:skills/github-clones/openclaw/scripts/docs-i18n/process.go
-- Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

local yaml = require("lyaml")
local path = require("path")

-- Hilfsfunktionen
local function resolveDocsPath(docsRoot, filePath)
    local absPath = path.join(docsRoot, filePath)
    local relPath = filePath
    return absPath, relPath, nil
end

local function readFile(filePath)
    local file = io.open(filePath, "r")
    if not file then return nil, "file not found" end
    local content = file:read("*a")
    file:close()
    return content
end

local function splitFrontMatter(content)
    if not string.find(content, "^---") then
        return "", content
    end
    local lines = {}
    for line in string.gmatch(content, "([^\n]*)\n?") do
        table.insert(lines, line)
    end
    if #lines < 2 then
        return "", content
    end
    local endIndex = -1
    for i = 2, #lines do
        if string.match(lines[i], "^%s*---%s*$") then
            endIndex = i
            break
        end
    end
    if endIndex == -1 then
        return "", content
    end
    local frontLines = {}
    for i = 2, endIndex - 1 do
        table.insert(frontLines, lines[i])
    end
    local bodyLines = {}
    for i = endIndex + 1, #lines do
        table.insert(bodyLines, lines[i])
    end
    local front = table.concat(frontLines, "\n")
    local body = table.concat(bodyLines, "\n")
    if string.sub(body, 1, 1) == "\n" then
        body = string.sub(body, 2)
    end
    return front, body
end

local function encodeFrontMatter(frontData, relPath, source)
    if not frontData then frontData = {} end
    frontData["x-i18n"] = {
        source_path = relPath,
        source_hash = hashBytes(source),
        provider = docsPiProvider(),
        model = docsPiModel(),
        workflow = workflowVersion,
        generated_at = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }
    local encoded = yaml.dump({frontData})
    return "---\n" .. encoded .. "---\n\n"
end

local function translateFrontMatter(ctx, translator, tm, data, relPath, srcLang, tgtLang)
    if not data or next(data) == nil then
        return nil
    end
    if data.summary and type(data.summary) == "string" then
        if docsI18nVerboseLogs() then
            print(string.format("docs-i18n: frontmatter start %s field=summary bytes=%d", relPath, #data.summary))
        end
        local translated, err = translateSnippet(ctx, translator, tm, relPath..":frontmatter:summary", data.summary, srcLang, tgtLang)
        if err then return err end
        if docsI18nVerboseLogs() then
            print(string.format("docs-i18n: frontmatter done %s field=summary out_bytes=%d", relPath, #translated))
        end
        data.summary = translated
    end
    if data.title and type(data.title) == "string" then
        if docsI18nVerboseLogs() then
            print(string.format("docs-i18n: frontmatter start %s field=title bytes=%d", relPath, #data.title))
        end
        local translated, err = translateSnippet(ctx, translator, tm, relPath..":frontmatter:title", data.title, srcLang, tgtLang)
        if err then return err end
        if docsI18nVerboseLogs() then
            print(string.format("docs-i18n: frontmatter done %s field=title out_bytes=%d", relPath, #translated))
        end
        data.title = translated
    end
    if data.read_when and type(data.read_when) == "table" then
        local translated = {}
        for idx, item in ipairs(data.read_when) do
            if type(item) ~= "string" then
                table.insert(translated, item)
            else
                if docsI18nVerboseLogs() then
                    print(string.format("docs-i18n: frontmatter start %s field=read_when[%d] bytes=%d", relPath, idx, #item))
                end
                local value, err = translateSnippet(ctx, translator, tm, string.format("%s:frontmatter:read_when:%d", relPath, idx), item, srcLang, tgtLang)
                if err then return err end
                if docsI18nVerboseLogs() then
                    print(string.format("docs-i18n: frontmatter done %s field=read_when[%d] out_bytes=%d", relPath, idx, #value))
                end
                table.insert(translated, value)
            end
        end
        data.read_when = translated
    end
    return nil
end

local function docsI18nVerboseLogs()
    local value = os.getenv("OPENCLAW_DOCS_I18N_VERBOSE_LOGS") or ""
    value = string.gsub(value, "%s+", "")
    if value == "" then
        return false
    end
    local lower = string.lower(value)
    if lower == "1" or lower == "true" or lower == "yes" or lower == "on" or lower == "debug" or lower == "verbose" then
        return true
    else
        return false
    end
end

local function translateSnippet(ctx, translator, tm, segmentID, textValue, srcLang, tgtLang)
    if string.match(textValue, "^%s*$") then
        return textValue
    end
    local namespace = cacheNamespace()
    local textHash = hashText(textValue)
    local ck = cacheKey(namespace, srcLang, tgtLang, segmentID, textHash)
    local entry = tm:Get(ck)
    if entry then
        return entry.Translated
    end
    local translated, err = translator:Translate(ctx, textValue, srcLang, tgtLang)
    if err then
        return nil, err
    end
    local shouldCache = true
    local validationErr = validateFrontmatterScalarTranslation(textValue, translated)
    if validationErr then
        print(string.format("docs-i18n: frontmatter fallback %s reason=%s", segmentID, tostring(validationErr)))
        translated = textValue
        shouldCache = false
    end
    local entry = {
        CacheKey = ck,
        SegmentID = segmentID,
        SourcePath = segmentID,
        TextHash = textHash,
        Text = textValue,
        Translated = translated,
        Provider = docsPiProvider(),
        Model = docsPiModel(),
        SrcLang = srcLang,
        TgtLang = tgtLang,
        UpdatedAt = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }
    if shouldCache then
        tm:Put(entry)
    end
    return translated
end

local function validateFrontmatterScalarTranslation(source, translated)
    local trimmed = string.gsub(translated, "^%s*(.-)%s*$", "%1")
    if trimmed == "" then
        return "empty translation"
    end
    local lower = string.lower(trimmed)
    if string.find(lower, "<frontmatter>") or string.find(lower, "</frontmatter>") or 
       string.find(lower, "<body>") or string.find(lower, "</body>") then
        return "tagged document wrapper detected"
    end
    if string.find(trimmed, "%[%[%[FM_") then
        return "frontmatter marker leaked into scalar translation"
    end
    if string.find(trimmed, "\n---\n") or string.find(trimmed, "^---\n") then
        return "yaml document boundary detected"
    end
    if not string.find(source, "\n") and select(2, string.gsub(trimmed, "\n", "")) >= 3 then
        return "unexpected multiline expansion"
    end
    local sourceLen = #(string.gsub(source, "^%s*(.-)%s*$", "%1"))
    local translatedLen = #trimmed
    if sourceLen > 0 then
        local limit = sourceLen * 8 + 256
        if limit < 512 then limit = 512 end
        if translatedLen > limit then
            return string.format("unexpected size expansion source=%d translated=%d", sourceLen, translatedLen)
        end
    end
    for _, key in ipairs({"title:", "summary:", "read_when:"}) do
        if string.find(lower, "\n"..key) or string.find(lower, "^"..key) then
            return "frontmatter key leaked into scalar translation"
        end
    end
    return nil
end

local function processFile(ctx, translator, tm, docsRoot, filePath, srcLang, tgtLang)
    local absPath, relPath, err = resolveDocsPath(docsRoot, filePath)
    if err then
        return false, "", err
    end

    local content, err = readFile(absPath)
    if err then
        return false, "", err
    end

    local frontMatter, body = splitFrontMatter(content)
    local frontData = {}
    if frontMatter ~= "" then
        frontData = yaml.load(frontMatter)
        if not frontData then
            return false, "", "frontmatter parse failed for " .. relPath
        end
    end

    local err = translateFrontMatter(ctx, translator, tm, frontData, relPath, srcLang, tgtLang)
    if err then
        return false, "", err
    end

    body, err = translateHTMLBlocks(ctx, translator, body, srcLang, tgtLang)
    if err then
        return false, "", err
    end

    local segments, err = extractSegments(body, relPath)
    if err then
        return false, "", err
    end

    local namespace = cacheNamespace()
    for i, seg in ipairs(segments) do
        seg.CacheKey = cacheKey(namespace, srcLang, tgtLang, seg.SegmentID, seg.TextHash)
        local entry = tm:Get(seg.CacheKey)
        if entry then
            seg.Translated = entry.Translated
        else
            local translated, err = translator:Translate(ctx, seg.Text, srcLang, tgtLang)
            if err then
                return false, "", "translate failed (" .. relPath .. "): " .. tostring(err)
            end
            seg.Translated = translated
            local entry = {
                CacheKey = seg.CacheKey,
                SegmentID = seg.SegmentID,
                SourcePath = relPath,
                TextHash = seg.TextHash,
                Text = seg.Text,
                Translated = translated,
                Provider = docsPiProvider(),
                Model = docsPiModel(),
                SrcLang = srcLang,
                TgtLang = tgtLang,
                UpdatedAt = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }
            tm:Put(entry)
        end
    end

    local translatedBody = applyTranslations(body, segments)
    local updatedFront, err = encodeFrontMatter(frontData, relPath, content)
    if err then
        return false, "", err
    end

    local outputPath = path.join(docsRoot, tgtLang, relPath)
    local dir = path.dirname(outputPath)
    -- In Lua gibt es kein direktes Äquivalent zu MkdirAll, daher wird hier angenommen, dass das Verzeichnis existiert
    local file = io.open(outputPath, "w")
    if not file then
        return false, "", "could not create file " .. outputPath
    end
    file:write(updatedFront .. translatedBody)
    file:close()

    return false, outputPath, nil
end

return {
    processFile = processFile,
    splitFrontMatter = splitFrontMatter,
    encodeFrontMatter = encodeFrontMatter,
    translateFrontMatter = translateFrontMatter,
    docsI18nVerboseLogs = docsI18nVerboseLogs,
    translateSnippet = translateSnippet,
    validateFrontmatterScalarTranslation = validateFrontmatterScalarTranslation
}
