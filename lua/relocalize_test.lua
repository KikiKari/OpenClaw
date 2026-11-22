#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "e896a8a4cde130157aa2c9b64757f3790aa6ff0df57afe5145cfa88d5a2e2b95", "source_sha256": "0ea8eb8a8b99710853b26300ab5929582995da3d28a8c027c201b8c2daca6811", "target_language": "lua"}
-- relocalize_test.go — portiert nach lua
-- Quelle: go, workspace@local:skills/github-clones/openclaw/scripts/docs-i18n/relocalize_test.go
-- Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

local fs = require("fs")
local path = require("path")
local lfs = require("lfs")

-- Hilfsfunktionen
local function writeFile(filepath, content)
    local file = io.open(filepath, "w")
    if not file then error("Could not open file for writing: " .. filepath) end
    file:write(content)
    file:close()
end

local function readFile(filepath)
    local file = io.open(filepath, "r")
    if not file then error("Could not open file for reading: " .. filepath) end
    local content = file:read("*a")
    file:close()
    return content
end

local function mkdir(dir)
    local success, err = lfs.mkdir(dir)
    if not success and err ~= "File exists" then
        error("Failed to create directory: " .. dir .. " - " .. tostring(err))
    end
end

local function rmdir(dir)
    for file in lfs.dir(dir) do
        if file ~= "." and file ~= ".." then
            local filepath = path.join(dir, file)
            local attr = lfs.attributes(filepath)
            if attr.mode == "directory" then
                rmdir(filepath)
            else
                os.remove(filepath)
            end
        end
    end
    lfs.rmdir(dir)
end

local function mkTempDir()
    local tmpname = os.tmpname()
    os.remove(tmpname) -- Remove the temporary file created by tmpname
    mkdir(tmpname)
    return tmpname
end

local function stringsJoin(...)
    local args = {...}
    return table.concat(args, "\n")
end

local function containsLine(text, want)
    for line in text:gmatch("[^\r\n]+") do
        if line == want then
            return true
        end
    end
    return false
end

-- Mock für postprocessLocalizedDocs (da nicht implementiert)
local function postprocessLocalizedDocs(docsRoot, lang, files)
    -- Dummy implementation - hier müsste die eigentliche Logik stehen
    print("Processing localized docs for language:", lang)
    for _, file in ipairs(files) do
        print("Processing file:", file)
    end
    return nil -- Kein Fehler
end

-- Test-Framework-Simulation
local testResults = {}
local currentTestName = ""

local function runTest(name, testFn)
    currentTestName = name
    local status, err = pcall(testFn)
    if status then
        table.insert(testResults, {name = name, passed = true})
        print("PASS: " .. name)
    else
        table.insert(testResults, {name = name, passed = false, error = err})
        print("FAIL: " .. name .. " - " .. tostring(err))
    end
end

-- Tests
local function TestPostprocessLocalizedDocsFixesStaleLinksAfterLaterPagesExist()
    local docsRoot = mkTempDir()
    
    writeFile(path.join(docsRoot, "docs.json"), '{"redirects":[]}')
    writeFile(path.join(docsRoot, "gateway", "index.md"), "# Gateway\n")
    writeFile(path.join(docsRoot, "gateway", "troubleshooting.md"), "# Troubleshooting\n")
    writeFile(path.join(docsRoot, "zh-CN", "gateway", "index.md"), stringsJoin(
        "---",
        "title: 网关",
        "x-i18n:",
        "  source_hash: test",
        "---",
        "",
        "See [Troubleshooting](/gateway/troubleshooting)."
    ))
    writeFile(path.join(docsRoot, "zh-CN", "gateway", "troubleshooting.md"), stringsJoin(
        "---",
        "title: 故障排除",
        "x-i18n:",
        "  source_hash: test",
        "---",
        "",
        "# 故障排除"
    ))

    local err = postprocessLocalizedDocs(docsRoot, "zh-CN", {
        path.join(docsRoot, "zh-CN", "gateway", "index.md"),
        path.join(docsRoot, "zh-CN", "gateway", "troubleshooting.md")
    })
    if err then
        error("postprocessLocalizedDocs failed: " .. tostring(err))
    end

    local got = readFile(path.join(docsRoot, "zh-CN", "gateway", "index.md"))
    if not containsLine(got, "---\ntitle: 网关\nx-i18n:\n  source_hash: test\n---\n\n") then
        error("front matter corrupted after rewrite:\n" .. got)
    end
    local want = "See [Troubleshooting](/zh-CN/gateway/troubleshooting)."
    if not containsLine(got, want) then
        error("expected rewritten localized link \"" .. want .. "\" in output:\n" .. got)
    end
    
    rmdir(docsRoot)
end

local function TestPostprocessLocalizedDocsRewritesPublishedPageLinksForEachLocale()
    local tests = {
        {name = "zh-CN", lang = "zh-CN", title = "网关", wantPrefix = "/zh-CN"},
        {name = "ja-JP", lang = "ja-JP", title = "ゲートウェイ", wantPrefix = "/ja-JP"}
    }

    for _, tt in ipairs(tests) do
        local docsRoot = mkTempDir()
        writeFile(path.join(docsRoot, "docs.json"), '{"redirects":[]}')
        writeFile(path.join(docsRoot, "gateway", "index.md"), "# Gateway\n")
        writeFile(path.join(docsRoot, "gateway", "troubleshooting.md"), "# Troubleshooting\n")
        writeFile(path.join(docsRoot, "providers", "example-provider.md"), "# Example provider\n")
        writeFile(path.join(docsRoot, tt.lang, "gateway", "troubleshooting.md"), "# Localized troubleshooting\n")
        writeFile(path.join(docsRoot, tt.lang, "providers", "example-provider.md"), "# Localized example provider\n")

        local pagePath = path.join(docsRoot, tt.lang, "gateway", "index.md")
        writeFile(pagePath, stringsJoin(
            "---",
            "title: "..tt.title,
            "x-i18n:",
            "  source_hash: test",
            "---",
            "",
            "See [Troubleshooting](/gateway/troubleshooting).",
            "",
            "See [Example provider](/providers/example-provider).",
            "",
            '<Card href="/gateway/troubleshooting" title="Troubleshooting" />',
            '<Card href="'..tt.wantPrefix..'/providers/example-provider" title="Example provider" />'
        ))

        local err = postprocessLocalizedDocs(docsRoot, tt.lang, {pagePath})
        if err then
            error("postprocessLocalizedDocs failed: " .. tostring(err))
        end

        local got = readFile(pagePath)
        local expectedLinks = {
            "See [Troubleshooting](" .. tt.wantPrefix .. "/gateway/troubleshooting).",
            "See [Example provider](" .. tt.wantPrefix .. "/providers/example-provider).",
            '<Card href="' .. tt.wantPrefix .. '/gateway/troubleshooting" title="Troubleshooting" />',
            '<Card href="' .. tt.wantPrefix .. '/providers/example-provider" title="Example provider" />'
        }
        for _, want in ipairs(expectedLinks) do
            if not containsLine(got, want) then
                error("expected rewritten link \"" .. want .. "\" in output:\n" .. got)
            end
        end
        
        rmdir(docsRoot)
    end
end

local function TestPostprocessLocalizedDocsOnlyTouchesScopedFiles()
    local docsRoot = mkTempDir()
    writeFile(path.join(docsRoot, "docs.json"), '{"redirects":[]}')
    writeFile(path.join(docsRoot, "gateway", "troubleshooting.md"), "# Troubleshooting\n")
    writeFile(path.join(docsRoot, "zh-CN", "gateway", "troubleshooting.md"), "# 故障排除\n")

    local scopedPath = path.join(docsRoot, "zh-CN", "gateway", "index.md")
    local unscopedPath = path.join(docsRoot, "zh-CN", "help", "index.md")

    writeFile(scopedPath, stringsJoin(
        "---",
        "title: 网关",
        "---",
        "",
        "See [Troubleshooting](/gateway/troubleshooting)."
    ))
    writeFile(unscopedPath, stringsJoin(
        "---",
        "title: 帮助",
        "---",
        "",
        "See [Troubleshooting](/gateway/troubleshooting)."
    ))

    local beforeUnscoped = readFile(unscopedPath)
    local err = postprocessLocalizedDocs(docsRoot, "zh-CN", {scopedPath})
    if err then
        error("postprocessLocalizedDocs failed: " .. tostring(err))
    end

    local gotScoped = readFile(scopedPath)
    if not containsLine(gotScoped, "See [Troubleshooting](/zh-CN/gateway/troubleshooting).") then
        error("expected scoped file rewrite, got:\n" .. gotScoped)
    end

    local afterUnscoped = readFile(unscopedPath)
    if afterUnscoped ~= beforeUnscoped then
        error("expected unscoped file to remain unchanged\nbefore:\n" .. beforeUnscoped .. "\nafter:\n" .. afterUnscoped)
    end
    
    rmdir(docsRoot)
end

local function TestPostprocessLocalizedDocsContinuesAfterUnchangedFile()
    local docsRoot = mkTempDir()
    writeFile(path.join(docsRoot, "docs.json"), '{"redirects":[]}')
    writeFile(path.join(docsRoot, "gateway", "troubleshooting.md"), "# Troubleshooting\n")
    writeFile(path.join(docsRoot, "zh-CN", "gateway", "troubleshooting.md"), "# 故障排除\n")

    local unchangedPath = path.join(docsRoot, "zh-CN", "gateway", "already-localized.md")
    local needsRewritePath = path.join(docsRoot, "zh-CN", "gateway", "index.md")

    writeFile(unchangedPath, stringsJoin(
        "---",
        "title: 已本地化",
        "---",
        "",
        "See [Troubleshooting](/zh-CN/gateway/troubleshooting)."
    ))
    writeFile(needsRewritePath, stringsJoin(
        "---",
        "title: 网关",
        "---",
        "",
        "See [Troubleshooting](/gateway/troubleshooting)."
    ))

    local err = postprocessLocalizedDocs(docsRoot, "zh-CN", {unchangedPath, needsRewritePath})
    if err then
        error("postprocessLocalizedDocs failed: " .. tostring(err))
    end

    local got = readFile(needsRewritePath)
    if not containsLine(got, "See [Troubleshooting](/zh-CN/gateway/troubleshooting).") then
        error("expected later file rewrite after unchanged file, got:\n" .. got)
    end
    
    rmdir(docsRoot)
end

-- Hauptprogramm
print("Running tests...")

runTest("TestPostprocessLocalizedDocsFixesStaleLinksAfterLaterPagesExist", 
        TestPostprocessLocalizedDocsFixesStaleLinksAfterLaterPagesExist)

runTest("TestPostprocessLocalizedDocsRewritesPublishedPageLinksForEachLocale", 
        TestPostprocessLocalizedDocsRewritesPublishedPageLinksForEachLocale)

runTest("TestPostprocessLocalizedDocsOnlyTouchesScopedFiles", 
        TestPostprocessLocalizedDocsOnlyTouchesScopedFiles)

runTest("TestPostprocessLocalizedDocsContinuesAfterUnchangedFile", 
        TestPostprocessLocalizedDocsContinuesAfterUnchangedFile)

-- Zusammenfassung
print("\nTest Results:")
local passed = 0
local failed = 0
for _, result in ipairs(testResults) do
    if result.passed then
        passed = passed + 1
    else
        failed = failed + 1
    end
end
print("Passed: " .. passed)
print("Failed: " .. failed)

if failed > 0 then
    os.exit(1)
else
    os.exit(0)
end
