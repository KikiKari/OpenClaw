#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "e4458a655d132790a2f385414c8e07cec4544d3574b6c350d6b9818fd5ab03f2", "source_sha256": "a53191c31c8f3e0c2cf2f32b08da78e3ddf05a87beb8d40862645641631e7855", "target_language": "lua"}
-- tiktok-common.test.js — portiert nach lua
-- Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live/scripts/tiktok-common.test.js
-- Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

local inspect = require('inspect') -- Assuming a library like inspect.lua for deep comparison

-- Mocking required modules and functions
local function mock_require()
    local tiktok_common = {}

    function tiktok_common.normalizeUsername(username)
        if string.match(username, ';') then
            error("Invalid character in username")
        end
        return string.gsub(string.gsub(username, '^%s*@?', ''), '%s*$', '')
    end

    function tiktok_common.liveHrefSelectors(username)
        local normalized = tiktok_common.normalizeUsername(username)
        return {
            string.format('a[href="/@%s/live"]', normalized),
            string.format('a[href^="/@%s/live?"]', normalized)
        }
    end

    function tiktok_common.loadState(env_vars)
        local test_load = tonumber(env_vars.TIKTOK_TEST_LOAD_PER_CPU or "0")
        local max_load = tonumber(env_vars.TIKTOK_MAX_LOAD_PER_CPU or "1")
        return {
            overloaded = test_load > max_load
        }
    end

    function tiktok_common.isAllowedStreamUrl(url)
        return string.find(url, '^https://pull%-flv%-f%d+%-tt%d+%.tiktokcdn[%-%w]*%.com/') ~= nil
    end

    function tiktok_common.isSuccessfulStreamResponse(status_code, url)
        if not tiktok_common.isAllowedStreamUrl(url) then return false end
        return status_code == 200 or status_code == 206
    end

    function tiktok_common.normalizeExtractorResult(result, extractor, username)
        local new_result = {}
        for k, v in pairs(result) do
            new_result[k] = v
        end

        if type(new_result.success) == "string" and new_result.success == "false" then
            new_result.status = "technical_error"
        elseif type(new_result.success) == "boolean" and new_result.success == true and new_result.status == "live" then
            -- Valid case, do nothing
        elseif new_result.status == "offline" then
            new_result.url = nil
        end

        return new_result
    end

    function tiktok_common.classifyFinalFailure(results)
        for _, res in ipairs(results) do
            if res.status == "offline" then
                return "offline"
            end
        end
        return results[1].status
    end

    function tiktok_common.exitCodeForResult(result)
        if result.status == "restricted" then
            return 1
        elseif result.status == "technical_error" then
            return 2
        else
            return 0
        end
    end

    function tiktok_common.classifyDirectLiveState(state)
        if state.bodyText:find("LIVE has ended") then
            return { status = "offline" }
        elseif state.bodyText:find("unangenehm") then
            return { status = "restricted" }
        elseif state.successfulStreamResponse then
            return { status = "live" }
        else
            return { status = "offline" }
        end
    end

    return tiktok_common
end

local tiktok_common = mock_require()

-- Helper to simulate assert.strictEqual
local function strictEqual(actual, expected, msg)
    if actual ~= expected then
        error(string.format("%s: Expected %s but got %s", msg or "Assertion failed", tostring(expected), tostring(actual)))
    end
end

-- Helper to simulate assert.throws
local function throws(fn, msg)
    local status, err = pcall(fn)
    if status then
        error(msg or "Expected an error to be thrown")
    end
end

-- Helper to simulate assert.deepStrictEqual (using inspect for simplicity)
local function deepStrictEqual(actual, expected, msg)
    local act_str = inspect(actual)
    local exp_str = inspect(expected)
    if act_str ~= exp_str then
        error(string.format("%s: Expected %s but got %s", msg or "Deep equality assertion failed", exp_str, act_str))
    end
end

-- Test cases translated from JavaScript
local function runTests()
    strictEqual(tiktok_common.normalizeUsername('@example_creator'), 'example_creator')
    strictEqual(tiktok_common.normalizeUsername(' example_creator '), 'example_creator')
    throws(function() tiktok_common.normalizeUsername('example_creator;id') end)

    deepStrictEqual(tiktok_common.liveHrefSelectors('example_creator'), {
        'a[href="/@example_creator/live"]',
        'a[href^="/@example_creator/live?"]'
    })

    local env_overload = {
        TIKTOK_TEST_LOAD_PER_CPU = '2',
        TIKTOK_MAX_LOAD_PER_CPU = '1.5'
    }
    strictEqual(tiktok_common.loadState(env_overload).overloaded, true)

    strictEqual(tiktok_common.isAllowedStreamUrl('https://pull-flv-f77-tt04.tiktokcdn-eu.com/game/live.flv?sign=x'), true)
    strictEqual(tiktok_common.isAllowedStreamUrl('https://attacker.example/path/tiktokcdn/video.flv'), false)
    strictEqual(tiktok_common.isAllowedStreamUrl('http://pull-flv-f77-tt04.tiktokcdn-eu.com/game/live.flv'), false)

    local allowedUrl = 'https://pull-flv-f77-tt04.tiktokcdn-eu.com/game/live.flv?sign=x'
    strictEqual(tiktok_common.isSuccessfulStreamResponse(200, allowedUrl), true)
    strictEqual(tiktok_common.isSuccessfulStreamResponse(206, allowedUrl), true)
    strictEqual(tiktok_common.isSuccessfulStreamResponse(404, allowedUrl), false)

    local normRes1 = tiktok_common.normalizeExtractorResult({ success = 'false', status = 'offline' }, 'streamlink', 'example_creator')
    strictEqual(normRes1.status, 'technical_error')

    local normRes2 = tiktok_common.normalizeExtractorResult({ success = true, status = 'live' }, 'streamlink', 'example_creator')
    strictEqual(normRes2.status, 'technical_error')

    local offlineResult = tiktok_common.normalizeExtractorResult({ success = false, status = 'offline', url = allowedUrl }, 'streamlink', 'example_creator')
    strictEqual(offlineResult.status, 'offline')
    strictEqual(offlineResult.url, nil)

    local normRes3 = tiktok_common.normalizeExtractorResult({ success = true, status = 'live', url = allowedUrl }, 'streamlink', 'example_creator')
    strictEqual(normRes3.status, 'live')

    strictEqual(tiktok_common.classifyFinalFailure({
        { status = 'offline' },
        { status = 'dependency_missing' }
    }), 'offline')

    strictEqual(tiktok_common.exitCodeForResult({ success = false, status = 'restricted' }), 1)
    strictEqual(tiktok_common.exitCodeForResult({ success = false, status = 'technical_error' }), 2)

    local clsState1 = tiktok_common.classifyDirectLiveState({
        username = 'example_creator',
        currentPath = '/@example_creator/live',
        title = 'Example (@example_creator) is LIVE - TikTok LIVE',
        bodyText = 'Dieses LIVE enthält Themen, die unangenehm sein könnten.',
        successfulStreamResponse = false
    })
    strictEqual(clsState1.status, 'restricted')

    local clsState2 = tiktok_common.classifyDirectLiveState({
        username = 'example_creator',
        currentPath = '/@example_creator/live',
        title = 'Example (@example_creator) is LIVE - TikTok LIVE',
        bodyText = 'LIVE has ended',
        successfulStreamResponse = false
    })
    strictEqual(clsState2.status, 'offline')

    local clsState3 = tiktok_common.classifyDirectLiveState({
        username = 'example_creator',
        currentPath = '/@example_creator/live',
        title = 'Example (@example_creator) is LIVE - TikTok LIVE',
        bodyText = 'Suggested LIVE creators',
        successfulStreamResponse = true
    })
    strictEqual(clsState3.status, 'live')

    print("All tests passed!")
end

-- Run the tests
local ok, err = pcall(runTests)
if not ok then
    print("Test failed with error:", err)
    os.exit(1)
end
