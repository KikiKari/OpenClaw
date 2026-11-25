#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "361df8d2d6fbba008fa9b1bf553699d66b4ad340136e3e7d71b52118c09b412a", "source_sha256": "982245244dd1863414e9d3aaedaf8afbfb270bbbc18cd490fbb288290b7667d3", "target_language": "lua"}
-- test_sidepanel_player_guard.cjs — portiert nach lua
-- Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_sidepanel_player_guard.cjs
-- auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_sidepanel_player_guard.cjs
-- auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_sidepanel_player_guard.cjs
-- auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_sidepanel_player_guard.cjs
-- Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

local fs = require("luv").fs
local path = require("path")

-- Simple assert function for strict equality
local function strictEqual(a, b, msg)
  if a ~= b then
    error(msg or ("Assertion failed: " .. tostring(a) .. " == " .. tostring(b)))
  end
end

-- Simple assert function for pattern matching
local function assertMatch(str, pattern, msg)
  if not string.find(str, pattern) then
    error(msg or ("Pattern not found: " .. pattern))
  end
end

-- Read file content
local function readFileSync(filepath)
  local fd = fs.openSync(filepath, "r")
  local stat = fs.fstatSync(fd)
  local data = fs.readSync(fd, stat.size, 0)
  fs.closeSync(fd)
  return data
end

-- Main test logic
local async = require("async")
local await = require("await")

local function main()
  local sourcePath = path.join(debug.getinfo(1).source:match("@(.*)[/\\]"), "../browser-extension/sidepanel.js")
  local source = readFileSync(sourcePath)

  local start = string.find(source, "  async function refreshPlayer%(")
  local endPos = string.find(source, "  function setButtonBusy", start)

  if not start or not endPos or endPos <= start then
    error("Could not find required function boundaries")
  end

  local reply
  local calls = 0
  local rendered = {}

  -- Create a sandboxed environment
  local context = {
    activeTabId = 1,
    activeIsTikTok = true,
    playerContextGeneration = 0,
    send = function()
      calls = calls + 1
      return {
        next = function(self, callback)
          reply = callback
        end
      }
    end,
    renderPlayer = function(state)
      table.insert(rendered, state)
    end
  }

  -- Extract and run the relevant code snippet
  local codeSnippet = string.sub(source, start, endPos - 1)
  
  -- Load and execute the code snippet in the context
  local func, err = load(codeSnippet, nil, "t", context)
  if not func then
    error("Failed to load code snippet: " .. err)
  end
  func()

  -- Test cases
  local pending = context.refreshPlayer()
  context.activeTabId = 2
  reply({response = {playerState = {playing = true}}})
  async.wait(pending)
  strictEqual(#rendered, 0, 'Old tab response must be ignored')

  context.activeIsTikTok = false
  async.wait(context.refreshPlayer())
  strictEqual(calls, 1, 'Non-TikTok tabs must not be polled')

  context.activeIsTikTok = true
  pending = context.refreshPlayer()
  reply({response = {playerState = {playing = true}}})
  async.wait(pending)
  strictEqual(#rendered, 1, 'Current tab response must render')

  pending = context.refreshPlayer()
  context.activeTabId = 3
  context.playerContextGeneration = context.playerContextGeneration + 1
  context.activeTabId = 2
  context.playerContextGeneration = context.playerContextGeneration + 1
  reply({response = {playerState = {playing = false}}})
  async.wait(pending)
  strictEqual(#rendered, 1, 'Returning to the same tab must not revive an old response')

  assertMatch(source, "async function refresh%(%)%s*{%s*playerContextGeneration%+%+;", 
    'Context invalidation must precede asynchronous tab lookup')

  print('PASS: stale tab response ignored, non-TikTok polling skipped, current response rendered')
end

-- Run main with error handling
local success, err = pcall(main)
if not success then
  print("Error: " .. tostring(err))
  os.exit(1)
end
