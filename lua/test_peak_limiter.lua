#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "e17046d0bd2dc6053df1e932701a4479f18315284e2ec4736f6839a8d801a099", "source_sha256": "8e7a477eeeb754ba1e86a22a033ce29eb66d4c0500493fe596a60daf5ac9d10c", "target_language": "lua"}
-- test_peak_limiter.cjs — portiert nach lua
-- Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_peak_limiter.cjs
-- auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_peak_limiter.cjs
-- auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_peak_limiter.cjs
-- auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_peak_limiter.cjs
-- Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

local math = require("math")
local table = require("table")

-- Mocking node:test functionality
local test_results = {}
local function test(name, func)
    table.insert(test_results, {name = name, func = func})
end

local function assert_equal(a, b, msg)
    if a ~= b then
        error(string.format("Assertion failed [%s]: expected %s, got %s", msg or "", tostring(b), tostring(a)))
    end
end

local function assert_ok(condition, msg)
    if not condition then
        error("Assertion failed: " .. (msg or ""))
    end
end

local function assert_deep_equal(a, b)
    if #a ~= #b then
        error("Arrays have different lengths")
    end
    for i = 1, #a do
        if a[i] ~= b[i] then
            error(string.format("Array mismatch at index %d: %s ~= %s", i, tostring(a[i]), tostring(b[i])))
        end
    end
end

-- Simplified version of content-core functions
local function limiterStrengthToDbfs(strength)
    return -0.01 * strength * strength
end

local function createPeakLimiter(rate)
    local attackSec = 0.001
    local releaseSec = 0.1
    local lookAheadSec = 0.005
    
    local attackCoeff = 1 - math.exp(-1 / (rate * attackSec))
    local releaseCoeff = 1 - math.exp(-1 / (rate * releaseSec))
    local delaySamples = math.ceil(lookAheadSec * rate)
    
    local envelope = 0
    local bufferPos = 0
    local buffer = {}
    for ch = 1, 2 do
        buffer[ch] = {}
        for i = 1, delaySamples do
            buffer[ch][i] = 0
        end
    end
    
    local function process(inputs, outputs, enabled, strength)
        local numChannels = #inputs
        local numFrames = inputs[1] and #inputs[1] or 0
        
        -- Initialize outputs if needed
        if #outputs == 0 then
            for ch = 1, numChannels do
                outputs[ch] = {}
                for i = 1, numFrames do
                    outputs[ch][i] = 0
                end
            end
        end
        
        if numFrames == 0 then
            -- Drain buffer when no input
            for ch = 1, numChannels do
                for i = 1, math.min(#outputs[ch], delaySamples) do
                    outputs[ch][i] = buffer[ch][bufferPos + i] or 0
                end
            end
            
            -- Shift buffer
            for ch = 1, numChannels do
                for i = 1, delaySamples - numFrames do
                    buffer[ch][bufferPos + i] = buffer[ch][bufferPos + i + numFrames] or 0
                end
                for i = delaySamples - numFrames + 1, delaySamples do
                    buffer[ch][bufferPos + i] = 0
                end
            end
            return
        end
        
        -- Calculate target gain
        local targetGain = 1
        if enabled then
            local peak = 0
            for i = 1, numFrames do
                for ch = 1, numChannels do
                    local val = inputs[ch][i] or 0
                    if val ~= val or val == math.huge or val == -math.huge then
                        val = 0
                    end
                    peak = math.max(peak, math.abs(val))
                end
            end
            
            local ceiling = 10^(limiterStrengthToDbfs(strength) / 20)
            if peak > ceiling then
                targetGain = ceiling / peak
            end
        end
        
        -- Update envelope
        if targetGain < envelope then
            envelope = targetGain
        else
            envelope = envelope + releaseCoeff * (targetGain - envelope)
        end
        
        -- Process each frame
        for i = 1, numFrames do
            -- Buffer input samples
            for ch = 1, numChannels do
                local pos = (bufferPos + i - 1) % delaySamples + 1
                local val = inputs[ch][i] or 0
                if val ~= val or val == math.huge or val == -math.huge then
                    val = 0
                end
                buffer[ch][pos] = val
            end
            
            -- Output processed samples
            local gain = envelope
            for ch = 1, numChannels do
                local readPos = (bufferPos + i - delaySamples - 1) % delaySamples + 1
                outputs[ch][i] = (buffer[ch][readPos] or 0) * gain
            end
        end
        
        bufferPos = (bufferPos + numFrames) % delaySamples
    end
    
    return {
        process = process,
        delaySamples = delaySamples
    }
end

-- Helper functions
local function map(array, func)
    local result = {}
    for i = 1, #array do
        result[i] = func(array[i])
    end
    return result
end

local function reduce(array, func, initial)
    local result = initial
    for i = 1, #array do
        result = func(result, array[i])
    end
    return result
end

local function slice(array, from, to)
    local result = {}
    local len = #array
    from = from or 1
    to = to or len
    if from < 0 then from = len + from + 1 end
    if to < 0 then to = len + to end
    for i = from, math.min(to, len) do
        result[#result + 1] = array[i]
    end
    return result
end

local function fill(array, value)
    for i = 1, #array do
        array[i] = value
    end
    return array
end

local function peak(channel)
    return reduce(channel, function(result, value)
        return math.max(result, math.abs(value))
    end, 0)
end

local function render(signal, strength, rate, enabled)
    rate = rate or 48000
    enabled = enabled ~= false  -- default true
    
    local kernel = createPeakLimiter(rate)
    local output = {}
    
    for ch = 1, #signal do
        output[ch] = {}
        for i = 1, #signal[ch] + kernel.delaySamples do
            output[ch][i] = 0
        end
    end
    
    for start = 1, #output[1], 128 do
        local length = math.min(128, #output[1] - start + 1)
        local input = {}
        
        for ch = 1, #signal do
            input[ch] = {}
            for i = 1, length do
                local idx = start + i - 1
                input[ch][i] = signal[ch][idx] or 0
            end
        end
        
        local out_segment = {}
        for ch = 1, #output do
            out_segment[ch] = {}
            for i = 1, length do
                local idx = start + i - 1
                out_segment[ch][i] = output[ch][idx]
            end
        end
        
        kernel.process(input, out_segment, enabled, strength)
        
        -- Copy results back to output
        for ch = 1, #output do
            for i = 1, length do
                local idx = start + i - 1
                output[ch][idx] = out_segment[ch][i]
            end
        end
    end
    
    return { output = output, delay = kernel.delaySamples }
end

-- Tests
for _, rate in ipairs({44100, 48000, 96000}) do
    test("isolated and high-frequency peaks are bounded at " .. rate .. " Hz", function()
        local signal = {}
        for i = 1, rate do
            signal[i] = 0
        end
        signal[2] = 1
        signal[128] = -1
        for i = 1001, 1100 do
            signal[i] = math.sin(2 * math.pi * 8000 * (i-1) / rate)
        end
        
        local previous = 1
        for _, strength in ipairs({25, 75, 100}) do
            local result = render({signal}, strength, rate)
            local output = result.output
            local delay = result.delay
            
            local measured = peak(output[1])
            local ceiling = 10^(limiterStrengthToDbfs(strength) / 20)
            
            assert_ok(measured <= ceiling + 1e-7, measured .. " exceeds " .. ceiling)
            assert_ok(measured < previous, "higher strength must attenuate more")
            assert_ok(delay / rate <= 0.01)
            previous = measured
        end
    end)
end

test("bypass preserves every sample with the documented delay", function()
    local signal = {}
    for i = 1, 10000 do
        signal[i] = math.sin(i * 0.7) * 0.8
    end
    
    local result = render({signal}, 100, 48000, false)
    local output = result.output
    local delay = result.delay
    
    local sliced = slice(output[1], delay + 1)
    assert_deep_equal(sliced, signal)
end)

test("quiet speech-band signal is not permanently attenuated", function()
    local signal = {}
    for i = 1, 48000 do
        signal[i] = 0.01 * math.sin(i * 2 * math.pi * 200 / 48000)
    end
    
    local result = render({signal}, 100)
    local output = result.output
    local delay = result.delay
    
    local sliced = slice(output[1], delay + 1)
    assert_deep_equal(sliced, signal)
end)

test("linked stereo gain preserves balance and limits either channel", function()
    local left = {}
    for i = 1, 1000 do
        left[i] = 0
    end
    left[128] = 0.5
    
    local right = {}
    for i = 1, 1000 do
        right[i] = 0
    end
    right[128] = 1
    
    local result = render({left, right}, 100)
    local output = result.output
    local delay = result.delay
    
    assert_equal(output[1][128 + delay] * 2, output[2][128 + delay])
    assert_ok(peak(output[2]) <= 10^(-30 / 20) + 1e-7)
end)

test("gain recovers after a transient and invalid samples cannot poison the graph", function()
    local signal = {}
    for i = 1, 48000 do
        signal[i] = 0
    end
    signal[11] = 1
    signal[101] = 0/0  -- NaN
    signal[201] = math.huge  -- Infinity
    for i = 24001, 48000 do
        signal[i] = 0.01
    end
    
    local result = render({signal}, 100)
    local output = result.output
    
    -- Check all values are finite
    for i = 1, #output[1] do
        assert_ok(output[1][i] == output[1][i] and output[1][i] ~= math.huge and output[1][i] ~= -math.huge)
    end
    
    -- Check recovery in later part
    local sum = 0
    for i = 40000, 48000 do
        sum = sum + output[1][i]
    end
    assert_ok(sum > 0.00999 * 8000)  -- Approximate check
end)

test("empty input drains delayed audio and then returns to silence", function()
    local kernel = createPeakLimiter(48000)
    local block = {}
    for i = 1, 128 do
        block[i] = 0.01
    end
    local out = {}
    for i = 1, 128 do
        out[i] = 0
    end
    
    kernel.process({block}, {out}, true, 100)
    
    for n = 1, 4 do
        kernel.process({}, {out}, true, 100)
    end
    
    assert_equal(peak(out), 0)
end)

-- Run tests
for _, t in ipairs(test_results) do
    print("Running test: " .. t.name)
    local success, err = pcall(t.func)
    if success then
        print("  PASS")
    else
        print("  FAIL: " .. err)
    end
end
