#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "738b7afaca802e2e1ed935bee7ad35399848b858e533dc53451705d77d0300ff", "source_sha256": "f6c7bd2581ab63fdb19f7caaff8e9c362e279303a47e4efe1873b2e652a7fbc8", "target_language": "lua"}
-- generate-host-env-security-policy-swift.mjs — portiert nach lua
-- Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/generate-host-env-security-policy-swift.mjs
-- Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

local fs = require("lfs")
local json = require("cjson")

-- Helper function to get script directory
local function script_path()
  local str = debug.getinfo(2, "S").source:sub(2)
  return str:match("(.*/)")
end

-- Helper function to read file
local function read_file(path)
  local file = io.open(path, "r")
  if not file then return nil end
  local content = file:read("*all")
  file:close()
  return content
end

-- Helper function to write file
local function write_file(path, content)
  local file = io.open(path, "w")
  if not file then return false end
  file:write(content)
  file:close()
  return true
end

-- Helper function to check if file exists
local function file_exists(path)
  local attr = lfs.attributes(path)
  return attr and attr.mode == "file"
end

-- Parse command line arguments
local args = {}
for i, arg in ipairs(arg) do
  args[arg] = true
end

local check_only = args["--check"] ~= nil
local write_mode = args["--write"] ~= nil or not check_only

if check_only and args["--write"] ~= nil then
  print("Use either --check or --write, not both.")
  os.exit(1)
end

-- Get paths
local here = script_path()
local repo_root = here .. ".." .. package.config:sub(1,1)
local policy_path = repo_root .. "src" .. package.config:sub(1,1) .. "infra" .. package.config:sub(1,1) .. "host-env-security-policy.json"
local output_path_parts = {
  repo_root, "apps", "macos", "Sources", "OpenClaw", "HostEnvSecurityPolicy.generated.swift"
}
local output_path = table.concat(output_path_parts, package.config:sub(1,1))

-- Load and parse policy
local policy_content = read_file(policy_path)
if not policy_content then
  print("Could not read policy file: " .. policy_path)
  os.exit(1)
end

local raw_policy = json.decode(policy_content)

-- Simulate loadHostEnvSecurityPolicy logic (assuming it just returns the input in this case)
local policy = raw_policy

-- Helper function to render Swift string array
local function render_swift_string_array(items)
  if not items then return "" end
  local result = {}
  for _, item in ipairs(items) do
    table.insert(result, '        "' .. item .. '"')
  end
  return table.concat(result, ",\n")
end

-- Generate Swift code
local generated = "// Generated file. Do not edit directly.\n"
  .. "// Source: src/infra/host-env-security-policy.json\n"
  .. "// Regenerate: lua scripts/generate-host-env-security-policy-swift.mjs --write\n\n"
  .. "import Foundation\n\n"
  .. "enum HostEnvSecurityPolicy {\n"
  .. "    static let blockedInheritedKeys: Set<String> = [\n"
  .. render_swift_string_array(policy.blockedInheritedKeys) .. "\n"
  .. "    ]\n\n"
  .. "    static let blockedInheritedPrefixes: [String] = [\n"
  .. render_swift_string_array(policy.blockedInheritedPrefixes) .. "\n"
  .. "    ]\n\n"
  .. "    static let blockedKeys: Set<String> = [\n"
  .. render_swift_string_array(policy.blockedKeys) .. "\n"
  .. "    ]\n\n"
  .. "    static let blockedOverrideKeys: Set<String> = [\n"
  .. render_swift_string_array(policy.blockedOverrideKeys) .. "\n"
  .. "    ]\n\n"
  .. "    static let blockedOverridePrefixes: [String] = [\n"
  .. render_swift_string_array(policy.blockedOverridePrefixes) .. "\n"
  .. "    ]\n\n"
  .. "    static let blockedPrefixes: [String] = [\n"
  .. render_swift_string_array(policy.blockedPrefixes) .. "\n"
  .. "    ]\n"
  .. "}\n"

-- Read current file if it exists
local current = nil
if file_exists(output_path) then
  current = read_file(output_path)
end

-- Check mode
if check_only then
  if current == generated then
    print("OK " .. output_path)
    os.exit(0)
  end
  print("Out of date " .. output_path .. ".")
  print("Run: lua scripts/generate-host-env-security-policy-swift.mjs --write")
  os.exit(1)
end

-- Write mode
if write_mode then
  if current ~= generated then
    if not write_file(output_path, generated) then
      print("Failed to write file: " .. output_path)
      os.exit(1)
    end
  end
  print("Wrote " .. output_path)
end
