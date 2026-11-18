#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "d721719815a1b067b9c95a23462f0557c0aa9b85f876c2e0138eb7501d0464ea", "source_sha256": "9411ee01f75190a7b3bf9f276fc6bb624d2c943629885c1ddfc9f71a0039070e", "target_language": "lua"}
-- gemini-ask.js — portiert nach lua
-- Quelle: javascript, OpenClaw@gateway1:scripts/gemini-ask.js
-- auch in: OpenClaw@gateway2:scripts/gemini-ask.js
-- Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

-- gemini-ask.lua - CLI tool for Google Gemini API
-- 
-- Usage:
--   lua gemini-ask.lua "Your question here"
--   echo "Your question" | lua gemini-ask.lua
--   lua gemini-ask.lua --file prompt.txt
--   lua gemini-ask.lua --model gemini-pro "Your question"
-- 
-- Environment:
--   GEMINI_API_KEY - Required API key
--   GEMINI_MODEL   - Optional default model (default: gemini-pro)

local http = require("socket.http")
local ltn12 = require("ltn12")
local json = require("json")

local DEFAULT_MODEL = os.getenv("GEMINI_MODEL") or "gemini-pro"

local function main()
    -- Check API key
    if not os.getenv("GEMINI_API_KEY") then
        io.stderr:write("Error: GEMINI_API_KEY environment variable is required\n")
        os.exit(1)
    end

    -- Parse arguments
    local prompt = ""
    local modelName = DEFAULT_MODEL
    local systemPrompt = ""
    local args = {}
    
    -- Parse command line arguments
    for i = 1, #arg do
        args[i] = arg[i]
    end

    -- Check for --model flag
    for i = 1, #args do
        if args[i] == "--model" or args[i] == "-m" then
            if args[i + 1] then
                modelName = args[i + 1]
                table.remove(args, i)
                table.remove(args, i)
                break
            end
        end
    end

    -- Check for --system flag (system prompt)
    for i = 1, #args do
        if args[i] == "--system" or args[i] == "-s" then
            if args[i + 1] then
                systemPrompt = args[i + 1]
                table.remove(args, i)
                table.remove(args, i)
                break
            end
        end
    end

    -- Check for --file flag
    local hasFileFlag = false
    local fileIndex = nil
    for i = 1, #args do
        if args[i] == "--file" or args[i] == "-f" then
            hasFileFlag = true
            fileIndex = i
            break
        end
    end

    if hasFileFlag and fileIndex then
        local filePath = args[fileIndex + 1]
        if not filePath then
            io.stderr:write("Error: No file specified\n")
            os.exit(1)
        end
        
        local file = io.open(filePath, "r")
        if not file then
            io.stderr:write("Error: Cannot open file " .. filePath .. "\n")
            os.exit(1)
        end
        
        prompt = file:read("*a")
        file:close()
        
        -- Remove --file and path from args
        table.remove(args, fileIndex)
        table.remove(args, fileIndex)
    elseif #args > 0 then
        prompt = table.concat(args, " ")
    else
        -- Read from stdin
        local input = io.read("*a")
        if input and input ~= "" then
            prompt = input
        end
    end

    if not prompt or prompt:trim() == "" then
        io.stderr:write("Error: No prompt provided\n")
        io.stderr:write("Usage: gemini-ask \"your question\"\n")
        io.stderr:write("       gemini-ask --model gemini-pro \"your question\"\n")
        io.stderr:write("       echo \"your question\" | gemini-ask\n")
        os.exit(1)
    end

    -- Prepare API request
    local apiKey = os.getenv("GEMINI_API_KEY")
    local url = "https://generativelanguage.googleapis.com/v1beta/models/" .. modelName .. ":generateContent?key=" .. apiKey
    
    local requestBody
    if systemPrompt ~= "" then
        -- Chat with system prompt
        requestBody = {
            contents = {
                {
                    role = "user",
                    parts = {
                        { text = systemPrompt }
                    }
                },
                {
                    role = "model",
                    parts = {
                        { text = "Understood. I will follow that instruction." }
                    }
                },
                {
                    role = "user",
                    parts = {
                        { text = prompt }
                    }
                }
            },
            generationConfig = {
                maxOutputTokens = 8192,
                temperature = 0.7,
                topP = 0.95
            }
        }
    else
        -- Direct generation
        requestBody = {
            contents = {
                {
                    role = "user",
                    parts = {
                        { text = prompt }
                    }
                }
            },
            generationConfig = {
                maxOutputTokens = 8192,
                temperature = 0.7,
                topP = 0.95
            }
        }
    end

    local responseBody = {}
    local request = {
        url = url,
        method = "POST",
        headers = {
            ["Content-Type"] = "application/json",
            ["Content-Length"] = tostring(#json.encode(requestBody))
        },
        source = ltn12.source.string(json.encode(requestBody)),
        sink = ltn12.sink.table(responseBody)
    }

    local _, statusCode = http.request(request)
    
    if statusCode ~= 200 then
        local response = table.concat(responseBody)
        local errorData = json.decode(response)
        io.stderr:write("Error: " .. (errorData.error and errorData.error.message or "API request failed") .. "\n")
        if statusCode == 401 then
            io.stderr:write("Make sure GEMINI_API_KEY is set correctly\n")
        end
        os.exit(1)
    end

    local response = table.concat(responseBody)
    local data = json.decode(response)
    
    if data and data.candidates and data.candidates[1] and data.candidates[1].content and data.candidates[1].content.parts and data.candidates[1].content.parts[1] then
        print(data.candidates[1].content.parts[1].text)
    else
        io.stderr:write("Error: Invalid response format from API\n")
        os.exit(1)
    end
end

-- Helper function to trim strings
function string.trim(s)
    return s:match("^%s*(.-)%s*$")
end

main()
