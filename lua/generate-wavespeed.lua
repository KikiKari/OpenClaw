#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "2b35caf7dbd24d4522d4539f3e5510d896e7a0ba6f433efb43b97c7e85cda9c5", "source_sha256": "3fed8b6be2b9b8639b55bcaf18c09c0395ac005ab02c27f2dff26ca20b5d5825", "target_language": "lua"}
-- generate-wavespeed.mjs — portiert nach lua
-- Quelle: javascript, Onboarding@main:scripts/generate-wavespeed.mjs
-- Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

local json = require("cjson")
local https = require("ssl.https")
local ltn12 = require("ltn12")
local mime = require("mime")
local base64 = require("base64")
local filesystem = require("filesystem")
local shell = require("shell")

-- Helper function to read file content
local function readFile(path)
  local file = io.open(path, "rb")
  if not file then return nil end
  local content = file:read("*all")
  file:close()
  return content
end

-- Helper function to write file content
local function writeFile(path, content)
  local file = io.open(path, "wb")
  if not file then error("Could not open file for writing: " .. path) end
  file:write(content)
  file:close()
end

-- Helper function to check if file exists
local function fileExists(path)
  local attr = filesystem.attributes(path)
  return attr and attr.mode == "file"
end

-- Helper function to make directories recursively
local function mkdirRecursive(path)
  local parts = {}
  local current = ""
  for part in string.gmatch(path, "[^/]+") do
    current = current .. part .. "/"
    table.insert(parts, current)
  end
  for _, dir in ipairs(parts) do
    if not filesystem.exists(dir) then
      filesystem.makeDirectory(dir)
    end
  end
end

-- Helper function to sleep
local function sleep(seconds)
  local start = os.time()
  repeat until os.time() > start + seconds
end

-- Get API key from environment variable
local key = os.getenv("WAVESPEED_API_KEY")
if not key then
  error("WAVESPEED_API_KEY missing.")
end

-- Define paths
local scriptPath = debug.getinfo(1, "S").source:sub(2):match("(.*/)")
local jobsPath = scriptPath .. "../media-production/wavespeed-jobs.json"
local rawDir = scriptPath .. "../media-production/raw/"
local publicDir = scriptPath .. "../public/media/"
local resultUrl = scriptPath .. "../media-production/wavespeed-results.json"

-- Create directories
mkdirRecursive(rawDir)
mkdirRecursive(publicDir)

-- Load jobs
local jobsFile = assert(io.open(jobsPath, "r"))
local jobsContent = jobsFile:read("*all")
jobsFile:close()
local jobs = json.decode(jobsContent)

-- Load or initialize log
local log = {}
if fileExists(resultUrl) then
  local logFile = assert(io.open(resultUrl, "r"))
  local logContent = logFile:read("*all")
  logFile:close()
  log = json.decode(logContent)
else
  log = {}
end

-- Process each job
for _, job in ipairs(jobs) do
  local rawPath = rawDir .. job.id .. ".png"
  local targetPath = publicDir .. job.output .. ".png"
  
  -- Check if already generated
  if fileExists(rawPath) then
    local found = false
    for _, entry in ipairs(log) do
      if entry.id == job.id then
        found = true
        break
      end
    end
    if not found then
      table.insert(log, {
        id = job.id,
        requestId = "completed-before-resume",
        model = "google/nano-banana-2/edit",
        resolution = "4k",
        plannedCostUsd = 0.14,
        output = job.output .. ".png"
      })
      writeFile(resultUrl, json.encode(log))
    end
    print("Skipped: " .. job.id .. " already exists.")
    goto continue
  end
  
  -- Prepare images
  local images = {}
  for _, image in ipairs(job.images) do
    if string.match(image, "^https?:") or string.match(image, "^data:") then
      table.insert(images, image)
    else
      local imagePath = scriptPath .. "../" .. image
      local imageData = readFile(imagePath)
      if imageData then
        local encoded = base64.enc(imageData)
        table.insert(images, "data:image/png;base64," .. encoded)
      else
        error("Failed to read image: " .. imagePath)
      end
    end
  end
  
  -- Submit request
  local requestBody = json.encode({
    prompt = job.prompt,
    images = images,
    aspect_ratio = job.aspectRatio,
    resolution = "4k",
    output_format = "png",
    enable_web_search = false,
    enable_image_search = false,
    enable_sync_mode = false,
    enable_base64_output = false,
  })
  
  local response_body = {}
  local res, code, headers, status = https.request{
    url = "https://api.wavespeed.ai/api/v3/google/nano-banana-2/edit",
    method = "POST",
    headers = {
      ["Authorization"] = "Bearer " .. key,
      ["Content-Type"] = "application/json",
      ["Content-Length"] = tostring(#requestBody)
    },
    source = ltn12.source.string(requestBody),
    sink = ltn12.sink.table(response_body)
  }
  
  if code ~= 200 then
    error("WaveSpeed submit failed: " .. code .. " " .. table.concat(response_body))
  end
  
  local submitted = json.decode(table.concat(response_body))
  local requestId = submitted.data and submitted.data.id or submitted.id
  
  -- Poll for result
  local result
  for attempt = 1, 90 do
    sleep(4)
    local poll_response = {}
    local poll_res, poll_code, poll_headers, poll_status = https.request{
      url = "https://api.wavespeed.ai/api/v3/predictions/" .. requestId .. "/result",
      method = "GET",
      headers = {
        ["Authorization"] = "Bearer " .. key
      },
      sink = ltn12.sink.table(poll_response)
    }
    
    result = json.decode(table.concat(poll_response))
    if result.data and result.data.status == "completed" then
      break
    elseif result.data and result.data.status == "failed" then
      error("WaveSpeed job failed: " .. job.id)
    end
  end
  
  -- Download and save image
  local imageUrl = result.data.outputs[1]
  if not imageUrl then
    error("No output for " .. job.id)
  end
  
  local imageResponse = {}
  local imageRes, imageCode, imageHeaders, imageStatus = https.request{
    url = imageUrl,
    method = "GET",
    sink = ltn12.sink.table(imageResponse)
  }
  
  if imageCode == 200 then
    local imageData = table.concat(imageResponse)
    writeFile(rawPath, imageData)
    writeFile(targetPath, imageData)
    
    table.insert(log, {
      id = job.id,
      requestId = requestId,
      model = "google/nano-banana-2/edit",
      resolution = "4k",
      plannedCostUsd = 0.14,
      output = job.output .. ".png"
    })
    
    writeFile(resultUrl, json.encode(log))
    print("Completed: " .. job.id)
  else
    error("Failed to download image: " .. imageUrl)
  end
  
  ::continue::
end

-- Finalize
writeFile(resultUrl, json.encode(log))
print("WaveSpeed completed: " .. #log .. " assets, planned base cost $" .. string.format("%.2f", #log * 0.14) .. ".")
