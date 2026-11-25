#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "e46e7d4f7730f97b4ef6c9bb1ba16d6895eba443becfa07823dc8ab60fb7083d", "source_sha256": "9c8abc93c198b77f804a6837db7baf1e85c902dc35a853c8086222a89f83fc89", "target_language": "lua"}
-- transcribe.sh — portiert nach lua
-- Quelle: shell, workspace@local:skills/github-clones/openclaw/skills/openai-whisper-api/scripts/transcribe.sh
-- Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

local function usage()
  io.stderr:write([[
Usage:
  transcribe.sh <audio-file> [--model whisper-1] [--out /path/to/out.txt] [--language en] [--prompt "hint"] [--json]
]])
  os.exit(2)
end

local args = {...}
if #args == 0 or args[1] == "-h" or args[1] == "--help" then
  usage()
end

local input_file = table.remove(args, 1)
local model = "whisper-1"
local out = ""
local language = ""
local prompt = ""
local response_format = "text"

local i = 1
while i <= #args do
  local arg = args[i]
  if arg == "--model" then
    model = args[i + 1] or ""
    i = i + 2
  elseif arg == "--out" then
    out = args[i + 1] or ""
    i = i + 2
  elseif arg == "--language" then
    language = args[i + 1] or ""
    i = i + 2
  elseif arg == "--prompt" then
    prompt = args[i + 1] or ""
    i = i + 2
  elseif arg == "--json" then
    response_format = "json"
    i = i + 1
  else
    io.stderr:write("Unknown arg: " .. arg .. "\n")
    usage()
  end
end

if not input_file or input_file == "" then
  io.stderr:write("No input file provided\n")
  os.exit(1)
end

local file = io.open(input_file, "r")
if not file then
  io.stderr:write("File not found: " .. input_file .. "\n")
  os.exit(1)
end
file:close()

local api_key = os.getenv("OPENAI_API_KEY")
if not api_key or api_key == "" then
  io.stderr:write("Missing OPENAI_API_KEY\n")
  os.exit(1)
end

if out == "" then
  local base = input_file:match("(.+)%..+$") or input_file
  if response_format == "json" then
    out = base .. ".json"
  else
    out = base .. ".txt"
  end
end

-- Create directory for output file
local out_dir = out:match("(.+)/[^/]*$")
if out_dir then
  os.execute("mkdir -p " .. out_dir)
end

local api_base = os.getenv("OPENAI_BASE_URL") or "https://api.openai.com/v1"
api_base = api_base:gsub("/$", "")

local curl_cmd = 'curl -sS "' .. api_base .. '/audio/transcriptions" ' ..
                  '-H "Authorization: Bearer ' .. api_key .. '" ' ..
                  '-H "Accept: application/json" ' ..
                  '-F "file=@' .. input_file .. '" ' ..
                  '-F "model=' .. model .. '" ' ..
                  '-F "response_format=' .. response_format .. '" '

if language ~= "" then
  curl_cmd = curl_cmd .. '-F "language=' .. language .. '" '
end

if prompt ~= "" then
  curl_cmd = curl_cmd .. '-F "prompt=' .. prompt .. '" '
end

curl_cmd = curl_cmd .. ' > "' .. out .. '"'

local success = os.execute(curl_cmd)
if success then
  print(out)
else
  os.exit(1)
end
