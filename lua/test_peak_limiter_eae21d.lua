#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "6f57c526961afcbd479d028ca460d6b1e5cc2ec9c5c7baa083b45e74671dab41", "source_sha256": "eae21de9563d56348053e8960d0cb46932aedad7fc6eb85904cb2c5a7aa9d8e6", "target_language": "lua"}
-- test_peak_limiter.cjs — portiert nach lua
-- Quelle: javascript, Projects@vercel/install-and-configure-vercel-w-98sxlo:plugin-source/scripts/test_peak_limiter.cjs
-- Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

local math = require("math")
local table = require("table")

-- Mocking node:test behavior
local test_cases = {}

local function test(name, func)
    table.insert(test_cases, {name = name, func = func})
end

local function run_tests()
    for _, case in ipairs(test_cases) do
        print("Running test: " .. case.name)
        case.func()
    end
end

-- Simple assertion functions
local function deepEqual(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    
    for k, v in pairs(a) do
        if not deepEqual(v, b[k]) then return false end
    end
    
    for k, _ in pairs(b) do
        if a[k] == nil then return false end
    end
    
    return true
end

local function ok(condition, message)
    if not condition then
        error(message or "Assertion failed")
    end
end

local function equal(a, b, message)
    if a ~= b then
        error(message or ("Expected " .. tostring(a) .. " to equal " .. tostring(b)))
    end
end

-- Mocking content-core functionality
local function limiterStrengthToDbfs(strength)
    return -strength * 0.3
end

local function createPeakLimiter(rate)
    local delaySamples = math.floor(rate * 0.005) -- example delay of 5ms
    local envelope = 0
    local gain = 1
    
    local function process(input, output, enabled, strength)
        local attackCoef = 1 - math.exp(-1 / (rate * 0.001)) -- 1ms attack
        local releaseCoef = 1 - math.exp(-1 / (rate * 0.1))   -- 100ms release
        
        local ceiling = 10^(limiterStrengthToDbfs(strength) / 20)
        
        for i = 1, #output[1] do
            local peak = 0
            
            for ch = 1, #input do
                local sample = input[ch][i] or 0
                if sample ~= sample then sample = 0 end -- NaN check
                if math.abs(sample) == math.huge then sample = 0 end -- Infinity check
                peak = math.max(peak, math.abs(sample))
            end
            
            if peak > envelope then
                envelope = envelope + attackCoef * (peak - envelope)
            else
                envelope = envelope + releaseCoef * (peak - envelope)
            end
            
            if envelope > ceiling and envelope > 0 then
                gain = ceiling / envelope
            else
                gain = 1
            end
            
            for ch = 1, #output do
                local sample = input[ch][i] or 0
                if sample ~= sample then sample = 0 end
                if math.abs(sample) == math.huge then sample = 0 end
                
                if enabled then
                    output[ch][i] = sample * gain
                else
                    output[ch][i] = sample
                end
            end
        end
    end
    
    return {
        delaySamples = delaySamples,
        process = process
    }
end

local function render(signal, strength, rate, enabled)
    rate = rate or 48000
    enabled = enabled ~= nil and enabled or true
    
    local kernel = createPeakLimiter(rate)
    
    local output = {}
    for ch = 1, #signal do
        output[ch] = {}
        for i = 1, #signal[ch] + kernel.delaySamples do
            output[ch][i] = 0
        end
    end
    
    local blockSize = 128
    for start = 1, #output[1], blockSize do
        local length = math.min(blockSize, #output[1] - start + 1)
        
        local input = {}
        for ch = 1, #signal do
            input[ch] = {}
            for i = 1, length do
                local idx = start + i - 1
                input[ch][i] = signal[ch][idx] or 0
            end
        end
        
        local outBuffer = {}
        for ch = 1, #output do
            outBuffer[ch] = {}
            for i = 1, length do
                local idx = start + i - 1
                outBuffer[ch][i] = output[ch][idx]
            end
        end
        
        kernel.process(input, outBuffer, enabled, strength)
        
        -- Copy back to output
        for ch = 1, #output do
            for i = 1, length do
                local idx = start + i - 1
                output[ch][idx] = outBuffer[ch][i]
            end
        end
    end
    
    return { output = output, delay = kernel.delaySamples }
end

local function peak(channel)
    local result = 0
    for i = 1, #channel do
        result = math.max(result, math.abs(channel[i]))
    end
    return result
end

-- Test cases
for _, rate in ipairs({44100, 48000, 96000}) do
    test("isolated and high-frequency peaks are bounded at " .. rate .. " Hz", function()
        local signal = {}
        for i = 1, rate do signal[i] = 0 end
        signal[2] = 1
        signal[128] = -1
        for i = 1001, 1100 do 
            signal[i] = math.sin(2 * math.pi * 8000 * i / rate)
        end
        
        local previous = 1
        for _, strength in ipairs({25, 75, 100}) do
            local result = render({signal}, strength, rate)
            local output = result.output
            local delay = result.delay
            
            local measured = peak(output[1])
            local ceiling = 10^(limiterStrengthToDbfs(strength) / 20)
            
            ok(measured <= ceiling + 1e-7, tostring(measured) .. " exceeds " .. tostring(ceiling))
            ok(measured < previous, "higher strength must attenuate more")
            ok(delay / rate <= 0.01)
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
    
    local sliced = {}
    for i = delay + 1, #output[1] do
        sliced[#sliced + 1] = output[1][i]
    end
    
    ok(deepEqual(sliced, signal))
end)

test("quiet speech-band signal is not permanently attenuated", function()
    local signal = {}
    for i = 1, 48000 do 
        signal[i] = 0.01 * math.sin(i * 2 * math.pi * 200 / 48000)
    end
    
    local result = render({signal}, 100)
    local output = result.output
    local delay = result.delay
    
    local sliced = {}
    for i = delay + 1, #output[1] do
        sliced[#sliced + 1] = output[1][i]
    end
    
    ok(deepEqual(sliced, signal))
end)

test("linked stereo gain preserves balance and limits either channel", function()
    local left = {}
    for i = 1, 1000 do left[i] = 0 end
    left[128] = 0.5
    
    local right = {}
    for i = 1, 1000 do right[i] = 0 end
    right[128] = 1
    
    local result = render({left, right}, 100)
    local output = result.output
    local delay = result.delay
    
    equal(output[1][128 + delay] * 2, output[2][128 + delay])
    ok(peak(output[2]) <= 10^(-30/20) + 1e-7)
end)

test("gain recovers after a transient and invalid samples cannot poison the graph", function()
    local signal = {}
    for i = 1, 48000 do signal[i] = 0 end
    signal[11] = 1
    signal[101] = 0/0  -- NaN
    signal[201] = 1/0  -- Infinity
    for i = 24001, 48000 do signal[i] = 0.01 end
    
    local result = render({signal}, 100)
    local output = result.output
    
    for i = 1, #output[1] do
        ok(output[1][i] == output[1][i])  -- Check for NaN
        ok(math.abs(output[1][i]) ~= math.huge)  -- Check for Infinity
    end
    
    ok(output[1][40001] > 0.00999)
end)

test("empty input drains delayed audio and then returns to silence", function()
    local kernel = createPeakLimiter(48000)
    local block = {}
    for i = 1, 128 do block[i] = 0.01 end
    local out = {}
    for i = 1, 128 do out[i] = 0 end
    
    kernel.process({block}, {out}, true, 100)
    
    for n = 1, 4 do 
        kernel.process({}, {out}, true, 100)
    end
    
    equal(peak(out), 0)
end)

-- Run all tests
run_tests()
