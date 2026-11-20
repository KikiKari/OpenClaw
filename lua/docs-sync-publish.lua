#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "da02e2c8e50d07ab182c353b7ff89d3df167ee6c5ceb28249d1ae53bec1ff461", "source_sha256": "51ab4d0a9d189c9eda9b410805bf753ea3df4406b70d58c8757e52b4551325b6", "target_language": "lua"}
-- docs-sync-publish.mjs — portiert nach lua
-- Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/docs-sync-publish.mjs
-- Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

local uv = require("uv")
local fs = require("fs")
local path = require("path")
local json = require("json")

local function dirname(p)
  return path.dirname(p)
end

local function fileURLToPath(url)
  local protocol, pathname = string.match(url, "^(%a+://)(.*)$")
  if protocol == "file://" then
    return pathname
  end
  return url
end

local function fileURLToPathFromMeta(meta)
  -- In Lua we simulate getting the current script path
  local info = debug.getinfo(1, "S")
  local source = info.source:sub(2) -- remove '@'
  return path.dirname(source)
end

local HERE = fileURLToPathFromMeta()
local ROOT = path.resolve(HERE, "..")
local SOURCE_DOCS_DIR = path.join(ROOT, "docs")
local SOURCE_CONFIG_PATH = path.join(SOURCE_DOCS_DIR, "docs.json")

local GENERATED_LOCALES = {
  {
    language = "zh-Hans",
    dir = "zh-CN",
    navFile = "zh-Hans-navigation.json",
    tmFile = "zh-CN.tm.jsonl",
    navMode = "overlay",
  },
  {
    language = "ja",
    dir = "ja-JP",
    navFile = "ja-navigation.json",
    tmFile = "ja-JP.tm.jsonl",
    navMode = "clone-en",
  },
  {
    language = "es",
    dir = "es",
    navFile = "es-navigation.json",
    tmFile = "es.tm.jsonl",
    navMode = "clone-en",
  },
  {
    language = "pt-BR",
    dir = "pt-BR",
    navFile = "pt-BR-navigation.json",
    tmFile = "pt-BR.tm.jsonl",
    navMode = "clone-en",
  },
  {
    language = "ko",
    dir = "ko",
    navFile = "ko-navigation.json",
    tmFile = "ko.tm.jsonl",
    navMode = "clone-en",
  },
  {
    language = "de",
    dir = "de",
    navFile = "de-navigation.json",
    tmFile = "de.tm.jsonl",
    navMode = "clone-en",
  },
  {
    language = "fr",
    dir = "fr",
    navFile = "fr-navigation.json",
    tmFile = "fr.tm.jsonl",
    navMode = "clone-en",
  },
  {
    language = "ar",
    dir = "ar",
    navFile = "ar-navigation.json",
    tmFile = "ar.tm.jsonl",
    navMode = "clone-en",
  },
  {
    language = "it",
    dir = "it",
    navFile = "it-navigation.json",
    tmFile = "it.tm.jsonl",
    navMode = "clone-en",
  },
  {
    language = "tr",
    dir = "tr",
    navFile = "tr-navigation.json",
    tmFile = "tr.tm.jsonl",
    navMode = "clone-en",
  },
  {
    language = "uk",
    dir = "uk",
    navFile = "uk-navigation.json",
    tmFile = "uk.tm.jsonl",
    navMode = "clone-en",
  },
  {
    language = "id",
    dir = "id",
    navFile = "id-navigation.json",
    tmFile = "id.tm.jsonl",
    navMode = "clone-en",
  },
  {
    language = "pl",
    dir = "pl",
    navFile = "pl-navigation.json",
    tmFile = "pl.tm.jsonl",
    navMode = "clone-en",
  },
}

local function parseArgs(argv)
  local args = {
    target = "",
    sourceRepo = "",
    sourceSha = "",
  }

  local index = 1
  while index <= #argv do
    local part = argv[index]
    if part == "--target" then
      args.target = argv[index + 1] or ""
      index = index + 1
    elseif part == "--source-repo" then
      args.sourceRepo = argv[index + 1] or ""
      index = index + 1
    elseif part == "--source-sha" then
      args.sourceSha = argv[index + 1] or ""
      index = index + 1
    else
      error("unknown arg: " .. part)
    end
    index = index + 1
  end

  if args.target == "" then
    error("missing --target")
  end

  return args
end

local function run(command, args, options)
  options = options or {}
  local cwd = options.cwd or ROOT
  local stdio = options.stdio or "inherit"
  
  -- Convert args table to command line string
  local cmd_args = ""
  for i, arg in ipairs(args) do
    cmd_args = cmd_args .. " " .. arg
  end
  
  local full_command = command .. cmd_args
  local result = os.execute(full_command)
  if result ~= 0 then
    error("Command failed: " .. full_command)
  end
end

local function ensureDir(dirPath)
  fs.mkdirSync(dirPath, { recursive = true })
end

local function readJson(filePath)
  local file = io.open(filePath, "r")
  if not file then
    error("Could not open file: " .. filePath)
  end
  local content = file:read("*all")
  file:close()
  return json.decode(content)
end

local function writeJson(filePath, value)
  ensureDir(path.dirname(filePath))
  local file = io.open(filePath, "w")
  if not file then
    error("Could not write file: " .. filePath)
  end
  file:write(json.encode(value))
  file:close()
end

local function prefixLocalePage(entry, localeDir)
  if type(entry) == "string" then
    return localeDir .. "/" .. entry
  end
  if type(entry) == "table" and #entry > 0 then
    local result = {}
    for i, item in ipairs(entry) do
      result[i] = prefixLocalePage(item, localeDir)
    end
    return result
  end
  if not entry or type(entry) ~= "table" then
    return entry
  end

  local clone = {}
  for k, v in pairs(entry) do
    clone[k] = v
  end
  if type(clone.page) == "string" then
    clone.page = localeDir .. "/" .. clone.page
  end
  if type(clone.pages) == "table" and #clone.pages > 0 then
    local new_pages = {}
    for i, item in ipairs(clone.pages) do
      new_pages[i] = prefixLocalePage(item, localeDir)
    end
    clone.pages = new_pages
  end
  return clone
end

local function cloneEnglishLanguageNav(englishNav, locale)
  if not englishNav then
    error("docs/docs.json is missing navigation.languages.en")
  end
  local result = {}
  for k, v in pairs(englishNav) do
    result[k] = v
  end
  result.language = locale.language
  if type(englishNav.tabs) == "table" and #englishNav.tabs > 0 then
    local new_tabs = {}
    for i, tab in ipairs(englishNav.tabs) do
      local new_tab = {}
      for k, v in pairs(tab) do
        new_tab[k] = v
      end
      if type(tab.pages) == "table" and #tab.pages > 0 then
        local new_pages = {}
        for j, entry in ipairs(tab.pages) do
          new_pages[j] = prefixLocalePage(entry, locale.dir)
        end
        new_tab.pages = new_pages
      end
      if type(tab.groups) == "table" and #tab.groups > 0 then
        local new_groups = {}
        for j, group in ipairs(tab.groups) do
          local new_group = {}
          for k, v in pairs(group) do
            new_group[k] = v
          end
          if type(group.pages) == "table" and #group.pages > 0 then
            local new_group_pages = {}
            for l, entry in ipairs(group.pages) do
              new_group_pages[l] = prefixLocalePage(entry, locale.dir)
            end
            new_group.pages = new_group_pages
          end
          new_groups[j] = new_group
        end
        new_tab.groups = new_groups
      end
      new_tabs[i] = new_tab
    end
    result.tabs = new_tabs
  else
    result.tabs = englishNav.tabs
  end
  return result
end

local function composeLocaleNav(locale, englishNav)
  if locale.navMode == "clone-en" then
    return cloneEnglishLanguageNav(englishNav, locale)
  end
  return readJson(path.join(SOURCE_DOCS_DIR, ".i18n", locale.navFile))
end

local function composeDocsConfig()
  local sourceConfig = readJson(SOURCE_CONFIG_PATH)
  local languages = sourceConfig.navigation and sourceConfig.navigation.languages

  if type(languages) ~= "table" or #languages == 0 then
    error("docs/docs.json is missing navigation.languages")
  end

  local englishNav = nil
  for _, entry in ipairs(languages) do
    if entry.language == "en" then
      englishNav = entry
      break
    end
  end

  local generatedLanguageSet = {}
  for _, entry in ipairs(GENERATED_LOCALES) do
    generatedLanguageSet[entry.language] = true
  end

  local withoutGenerated = {}
  for _, entry in ipairs(languages) do
    if not generatedLanguageSet[entry.language] then
      table.insert(withoutGenerated, entry)
    end
  end

  local enIndex = -1
  for i, entry in ipairs(withoutGenerated) do
    if entry.language == "en" then
      enIndex = i
      break
    end
  end

  local generated = {}
  for _, entry in ipairs(GENERATED_LOCALES) do
    table.insert(generated, composeLocaleNav(entry, englishNav))
  end

  if enIndex == -1 then
    for _, item in ipairs(generated) do
      table.insert(withoutGenerated, item)
    end
  else
    for i = #generated, 1, -1 do
      table.insert(withoutGenerated, enIndex + 1, generated[i])
    end
  end

  local result = {}
  for k, v in pairs(sourceConfig) do
    result[k] = v
  end
  result.navigation = {}
  for k, v in pairs(sourceConfig.navigation) do
    result.navigation[k] = v
  end
  result.navigation.languages = withoutGenerated

  return result
end

local function syncDocsTree(targetRoot)
  local targetDocsDir = path.join(targetRoot, "docs")
  ensureDir(targetDocsDir)

  local localeFilters = {}
  for _, entry in ipairs(GENERATED_LOCALES) do
    table.insert(localeFilters, "--filter")
    table.insert(localeFilters, "P " .. entry.dir .. "/")
    table.insert(localeFilters, "--filter")
    table.insert(localeFilters, "P .i18n/" .. entry.tmFile)
    table.insert(localeFilters, "--exclude")
    table.insert(localeFilters, entry.dir .. "/")
    table.insert(localeFilters, "--exclude")
    table.insert(localeFilters, ".i18n/" .. entry.tmFile)
  end

  local rsyncArgs = {
    "-a",
    "--delete",
    "--filter",
    "P .i18n/README.md",
    "--exclude",
    ".i18n/README.md",
  }

  for _, filter in ipairs(localeFilters) do
    table.insert(rsyncArgs, filter)
  end

  table.insert(rsyncArgs, SOURCE_DOCS_DIR .. "/")
  table.insert(rsyncArgs, targetDocsDir .. "/")

  run("rsync", rsyncArgs)

  for _, locale in ipairs(GENERATED_LOCALES) do
    local sourceTmPath = path.join(SOURCE_DOCS_DIR, ".i18n", locale.tmFile)
    local targetTmPath = path.join(targetDocsDir, ".i18n", locale.tmFile)
    if not fs.existsSync(targetTmPath) and fs.existsSync(sourceTmPath) then
      ensureDir(path.dirname(targetTmPath))
      fs.copyFileSync(sourceTmPath, targetTmPath)
    end
  end

  writeJson(path.join(targetDocsDir, "docs.json"), composeDocsConfig())
end

local function writeSyncMetadata(targetRoot, args)
  local metadata = {
    repository = args.sourceRepo or "",
    sha = args.sourceSha or "",
    syncedAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
  }
  writeJson(path.join(targetRoot, ".openclaw-sync", "source.json"), metadata)
end

local function main()
  local args = parseArgs(arg)
  local targetRoot = path.resolve(args.target)

  if not fs.existsSync(targetRoot) then
    error("target does not exist: " .. targetRoot)
  end

  syncDocsTree(targetRoot)
  writeSyncMetadata(targetRoot, args)
end

main()
