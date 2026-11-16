#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "300edd0934bf485c2a5050a3e94e8e713acd90427f7baf06d4c69f891447cdbc", "source_sha256": "cff712785adbfe2fa94661b7b8457fbc21ec0b21bc3bc77e5cfa7018f473e486", "target_language": "lua"}
-- build_icon.sh — portiert nach lua
-- Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/build_icon.sh
-- Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

local function split(str, sep)
  local fields = {}
  local pattern = string.format("([^%s]+)", sep)
  str:gsub(pattern, function(c) fields[#fields+1] = c end)
  return fields
end

local function dirname(path)
  return path:match("(.+)/[^/]*$")
end

local function basename(path)
  return path:match("^.+/(.+)$") or path
end

local function file_exists(name)
  local f = io.open(name, "r")
  if f ~= nil then
    io.close(f)
    return true
  else
    return false
  end
end

-- Get command line arguments or set defaults
local args = {...}
local ROOT_DIR = dirname(dirname(arg[0])) or "."
local ICON_FILE = args[1] or (ROOT_DIR .. "/apps/macos/Icon.icon")
local BASENAME = args[2] or "OpenClaw"
local OUT_ROOT = args[3] or (ROOT_DIR .. "/apps/macos/build/icon")

-- Environment variable handling
local XCODE_APP = os.getenv("XCODE_APP") or "/Applications/Xcode.app"
local DEST_ICNS = os.getenv("DEST_ICNS") or (ROOT_DIR .. "/apps/macos/Sources/OpenClaw/Resources/OpenClaw.icns")

-- Find ictool executable
local ICTOOL = XCODE_APP .. "/Contents/Applications/Icon Composer.app/Contents/Executables/ictool"
if not file_exists(ICTOOL) then
  ICTOOL = XCODE_APP .. "/Contents/Applications/Icon Composer.app/Contents/Executables/icontool"
end

if not file_exists(ICTOOL) then
  io.stderr:write("ictool/icontool not found. Set XCODE_APP if Xcode is elsewhere.\n")
  os.exit(1)
end

-- Create directories
local ICONSET_DIR = OUT_ROOT .. "/" .. BASENAME .. ".iconset"
local TMP_DIR = OUT_ROOT .. "/tmp"

os.execute("mkdir -p '" .. ICONSET_DIR .. "' '" .. TMP_DIR .. "'")

local MASTER_ART = TMP_DIR .. "/icon_art_824.png"
local MASTER_1024 = TMP_DIR .. "/icon_1024.png"

-- Render inner art (no margin) with macOS Default appearance
local cmd = "'" .. ICTOOL .. "' '" .. ICON_FILE .. 
            "' --export-preview macOS Default 824 824 1 -45 '" .. MASTER_ART .. "'"
local success = os.execute(cmd)
if not success then
  io.stderr:write("Failed to render icon art\n")
  os.exit(1)
end

-- Pad to 1024x1024 with transparent border
cmd = "sips --padToHeightWidth 1024 1024 '" .. MASTER_ART .. "' --out '" .. MASTER_1024 .. "' >/dev/null"
success = os.execute(cmd)
if not success then
  io.stderr:write("Failed to pad image\n")
  os.exit(1)
end

-- Generate required sizes
local sizes = {16, 32, 64, 128, 256, 512, 1024}
for _, sz in ipairs(sizes) do
  local out = ICONSET_DIR .. "/icon_" .. sz .. "x" .. sz .. ".png"
  cmd = "sips -z " .. sz .. " " .. sz .. " '" .. MASTER_1024 .. "' --out '" .. out .. "' >/dev/null"
  success = os.execute(cmd)
  if not success then
    io.stderr:write("Failed to resize image to " .. sz .. "x" .. sz .. "\n")
    os.exit(1)
  end
  
  if sz ~= 1024 then
    local dbl = sz * 2
    local out2 = ICONSET_DIR .. "/icon_" .. sz .. "x" .. sz .. "@2x.png"
    cmd = "sips -z " .. dbl .. " " .. dbl .. " '" .. MASTER_1024 .. "' --out '" .. out2 .. "' >/dev/null"
    success = os.execute(cmd)
    if not success then
      io.stderr:write("Failed to resize image to " .. dbl .. "x" .. dbl .. "\n")
      os.exit(1)
    end
  end
end

-- 512x512@2x already covered by 1024; ensure it exists
cmd = "cp '" .. MASTER_1024 .. "' '" .. ICONSET_DIR .. "/icon_512x512@2x.png'"
os.execute(cmd)

-- Convert iconset to icns
cmd = "iconutil -c icns '" .. ICONSET_DIR .. "' -o '" .. OUT_ROOT .. "/" .. BASENAME .. ".icns'"
success = os.execute(cmd)
if not success then
  io.stderr:write("Failed to create icns file\n")
  os.exit(1)
end

-- Copy to destination
cmd = "mkdir -p '" .. dirname(DEST_ICNS) .. "'"
os.execute(cmd)
cmd = "cp '" .. OUT_ROOT .. "/" .. BASENAME .. ".icns' '" .. DEST_ICNS .. "'"
os.execute(cmd)

print("Icon.icns generated at " .. DEST_ICNS)
