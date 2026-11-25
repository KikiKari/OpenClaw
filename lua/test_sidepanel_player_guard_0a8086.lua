#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "e4eed43bc8282dcc534b429e048df71b38fc58d51ea3c4d3e85ee6c9a77a11a7", "source_sha256": "0a80863f7d5305d66ae7c2dfcaa6e16615668b16c0687d7ac00af549bb03e121", "target_language": "lua"}
-- test_sidepanel_player_guard.cjs — portiert nach lua
-- Quelle: javascript, Projects@vercel/install-and-configure-vercel-w-98sxlo:plugin-source/scripts/test_sidepanel_player_guard.cjs
-- Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

local fs = require("lfs")
local path = require("path")

-- Hilfsfunktion zur Suche von Substrings mit Startposition
local function find(source, pattern, init)
  local s, e = string.find(source, pattern, init, true)
  if s then
    return s
  else
    return -1
  end
end

-- Lese die sidepanel.js Datei
local file_path = path.join(path.dirname(debug.getinfo(1).source:match("@(.*)")), "../browser-extension/sidepanel.js")
local file = io.open(file_path, "r")
if not file then
  error("Could not open file: " .. file_path)
end
local source = file:read("*a")
file:close()

-- Finde die relevanten Funktionen im Source-Code
local start = find(source, "  async function refreshPlayer()")
local end_ = find(source, "  function setButtonBusy", start)

if start < 0 or end_ <= start then
  error("Function boundaries not found")
end

-- Extrahiere den relevanten Teil des Codes
local code_to_run = string.sub(source, start, end_ - 1)

-- Globale Variablen für Tests
local reply = nil
local calls = 0
local rendered = {}
local activeTabId = 1
local activeIsTikTok = true
local playerContextGeneration = 0

-- Mock-Funktionen
local function send()
  calls = calls + 1
  return {
    andThen = function(self, callback)
      -- Simuliere Promise-Auflösung durch Setzen von reply
      reply = callback
      return self
    end
  }
end

local function renderPlayer(state)
  table.insert(rendered, state)
end

-- Führe den extrahierten Code in einer Sandbox-Umgebung aus
local sandbox = {
  activeTabId = activeTabId,
  activeIsTikTok = activeIsTikTok,
  playerContextGeneration = playerContextGeneration,
  send = send,
  renderPlayer = renderPlayer
}

-- Definiere refreshPlayer innerhalb der Sandbox
load(code_to_run, nil, "t", sandbox)()

-- Testlogik
local pending = sandbox.refreshPlayer()
sandbox.activeTabId = 2
reply({response = {playerState = {playing = true}}})
-- Warte auf Abschluss (Lua hat keine echten Promises, daher simulieren wir das Verhalten)
-- In einer realen Umgebung würdest du eine Event Loop verwenden

-- Überprüfe Ergebnisse
assert(#rendered == 0, "Old tab response must be ignored")

sandbox.activeIsTikTok = false
sandbox.refreshPlayer()
assert(calls == 1, "Non-TikTok tabs must not be polled")

sandbox.activeIsTikTok = true
pending = sandbox.refreshPlayer()
reply({response = {playerState = {playing = true}}})
-- Warte auf Abschluss
assert(#rendered == 1, "Current tab response must render")

pending = sandbox.refreshPlayer()
sandbox.activeTabId = 3
sandbox.playerContextGeneration = sandbox.playerContextGeneration + 1
sandbox.activeTabId = 2
sandbox.playerContextGeneration = sandbox.playerContextGeneration + 1
reply({response = {playerState = {playing = false}}})
-- Warte auf Abschluss
assert(#rendered == 1, "Returning to the same tab must not revive an old response")

-- Prüfe ob der Kontext vor asynchroner Tab-Suche ungültig gemacht wird
assert(string.find(source, "async function refresh%(%s*%)%s*{%s*playerContextGeneration%+%+;") ~= nil,
       "Context invalidation must precede asynchronous tab lookup")

print("PASS: stale tab response ignored, non-TikTok polling skipped, current response rendered")
