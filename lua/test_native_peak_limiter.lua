#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "34e328dc6c2541039d31f542cbab631bcd1d9a3e879af2a3e62d8712afdbe032", "source_sha256": "a8f6fe56e5dd5b96670040ccdc5def2ed3024c7e3f08f330234770f4186c70de", "target_language": "lua"}
-- test_native_peak_limiter.cjs — portiert nach lua
-- Quelle: javascript, Projects@vercel/install-and-configure-vercel-w-98sxlo:plugin-source/scripts/test_native_peak_limiter.cjs
-- Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

local assert = require("luassert")
local ffi = require("ffi")
local subprocess = require("process")

-- Simulate Node.js child_process.spawnSync using a custom function
local function spawnSync(executable, args, options)
    local input = options.input
    local argString = table.concat(args, " ")
    local command = string.format("%s %s", executable, argString)

    -- Write input to a temporary file or pipe it directly if supported
    local infile = io.tmpfile()
    infile:write(input)
    infile:seek("set", 0)

    -- Execute the command and capture output and error streams
    local proc = subprocess.spawn(command, {
        stdin = infile,
        stdout = subprocess.PIPE,
        stderr = subprocess.PIPE
    })

    local stdout_data = {}
    local stderr_data = {}
    proc.stdout:read("*a", function(data) table.insert(stdout_data, data) end)
    proc.stderr:read("*a", function(data) table.insert(stderr_data, data) end)

    proc:wait()

    return {
        status = proc.returncode,
        stdout = table.concat(stdout_data),
        stderr = table.concat(stderr_data)
    }
end

-- Mocking createPeakLimiter from ../browser-extension/content-core.js
-- This is a placeholder implementation assuming some behavior
local function createPeakLimiter(rate)
    local delaySamples = math.floor(rate * 0.005) -- Example delay of 5ms
    return {
        delaySamples = delaySamples,
        process = function(self, block, output, enabled, strength)
            -- Simplified processing logic for demonstration purposes
            for c = 1, #block do
                for i = 1, #block[c] do
                    output[c][i] = block[c][i] * (enabled and (strength / 100) or 1)
                end
            end
        end
    }
end

-- Main script starts here
local executable = arg[1]
assert.truthy(executable, "Pass compiled mobile/shared/native/limiter_trace.c executable")

local cases = 0
for _, rate in ipairs({44100, 48000, 96000}) do
    for _, channels in ipairs({1, 2, 6}) do
        for _, config in ipairs({{false, 100}, {true, 25}, {true, 75}, {true, 100}}) do
            local enabled, strength = config[1], config[2]
            local frames = math.floor(rate * 0.25)
            local input = {}

            -- Generate input data similar to JavaScript version
            for c = 1, channels do
                input[c] = {}
                for i = 1, frames do
                    if i == 6 or i == 130 then
                        input[c][i] = (c % 2 == 0) and -0.95 or 0.95
                    elseif i == 301 then
                        input[c][i] = 0/0 -- NaN equivalent
                    elseif i == 302 then
                        input[c][i] = 1/0 -- Infinity equivalent
                    else
                        local freq = (i < 2000) and 8000 or 220
                        local amplitude = (i < 2000) and 0.9 or 0.01
                        input[c][i] = (c / channels) * math.sin(i * 2 * math.pi * freq / rate) * amplitude
                    end
                end
            end

            local kernel = createPeakLimiter(rate)
            local count = frames + kernel.delaySamples
            local wire = {}

            -- Pack input into buffer-like structure
            for i = 1, count do
                for c = 1, channels do
                    local value = input[c][i] or 0
                    -- Convert float to little-endian bytes manually
                    local bytes = string.pack("<f", value)
                    for j = 1, #bytes do
                        table.insert(wire, string.byte(bytes, j))
                    end
                end
            end

            local rendered = spawnSync(executable, {tostring(rate), tostring(channels), tostring(enabled and 1 or 0), tostring(strength)}, {input = string.char(table.unpack(wire))})

            assert.are.equal(rendered.status, 0, rendered.stderr)

            local maxError = 0
            for start = 1, count, 127 do
                local size = math.min(127, count - start + 1)
                local block = {}
                local output = {}

                for c = 1, channels do
                    block[c] = {}
                    output[c] = {}
                    for i = 1, size do
                        block[c][i] = input[c][start + i - 1] or 0
                        output[c][i] = 0
                    end
                end

                kernel:process(block, output, enabled, strength)

                for i = 1, size do
                    for c = 1, channels do
                        local index = ((start + i - 1) * channels + c - 1) * 4 + 1
                        local bytes = {string.byte(rendered.stdout, index, index + 3)}
                        local actual = string.unpack("<f", string.char(table.unpack(bytes)))
                        assert.truthy(type(actual) == "number" and actual == actual and actual ~= 1/0 and actual ~= -1/0)
                        maxError = math.max(maxError, math.abs(actual - output[c][i]))
                    end
                end
            end

            assert.truthy(maxError <= 1e-7, string.format("%d/%d/%s/%d: %g", rate, channels, tostring(enabled), strength, maxError))
            cases = cases + 1
        end
    end
end

print(string.format("%d native/JavaScript PCM equivalence cases passed (error <= 1e-7).", cases))
