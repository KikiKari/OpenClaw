#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "d0004e507bbec39086090fd242296eef4aa21700c4d92c22277728d8d89d66ac", "source_sha256": "95f62a3e3f38308dd9be80e09ec85e4a14455ab95457febb8f915c0f54685141", "target_language": "lua"}
-- test_model_usage.py — portiert nach lua
-- Quelle: python, workspace@local:skills/github-clones/openclaw/skills/model-usage/scripts/test_model_usage.py
-- Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

--[[
Tests for model_usage helpers.
]]

local argparse = require "argparse"
local model_usage = require "model_usage"

local function TestCase()
    local self = {}
    
    function self.assertEqual(actual, expected)
        if actual ~= expected then
            error("Assertion failed: expected " .. tostring(expected) .. ", got " .. tostring(actual))
        end
    end
    
    function self.assertRaises(exception_type, func)
        local success, err = pcall(func)
        if success then
            error("Expected exception but none was raised")
        end
        -- In Lua we can't easily check exception type, so we just catch any error
    end
    
    return self
end

local function test_positive_int_accepts_valid_numbers()
    local tc = TestCase()
    tc.assertEqual(model_usage.positive_int("1"), 1)
    tc.assertEqual(model_usage.positive_int("7"), 7)
end

local function test_positive_int_rejects_zero_and_negative()
    local tc = TestCase()
    local function call_with_zero()
        model_usage.positive_int("0")
    end
    local function call_with_negative()
        model_usage.positive_int("-3")
    end
    
    tc.assertRaises("ArgumentError", call_with_zero)
    tc.assertRaises("ArgumentError", call_with_negative)
end

local function test_filter_by_days_keeps_recent_entries()
    local tc = TestCase()
    
    local function get_date_string(days_ago)
        local date_obj = os.date("*t")
        date_obj.day = date_obj.day - days_ago
        return os.date("%Y-%m-%d", os.time(date_obj))
    end
    
    local today_str = get_date_string(0)
    local five_days_ago_str = get_date_string(5)
    local one_day_ago_str = get_date_string(1)
    
    local entries = {
        {date = five_days_ago_str, modelBreakdowns = {}},
        {date = one_day_ago_str, modelBreakdowns = {}},
        {date = today_str, modelBreakdowns = {}}
    }
    
    local filtered = model_usage.filter_by_days(entries, 2)
    
    tc.assertEqual(#filtered, 2)
    tc.assertEqual(filtered[1].date, one_day_ago_str)
    tc.assertEqual(filtered[2].date, today_str)
end

-- Run tests
local function run_tests()
    print("Running tests...")
    test_positive_int_accepts_valid_numbers()
    print("test_positive_int_accepts_valid_numbers passed")
    
    test_positive_int_rejects_zero_and_negative()
    print("test_positive_int_rejects_zero_and_negative passed")
    
    test_filter_by_days_keeps_recent_entries()
    print("test_filter_by_days_keeps_recent_entries passed")
    
    print("All tests passed!")
end

run_tests()
