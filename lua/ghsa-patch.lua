#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "10ff9705064d0cb6ec6e19f092c36f13c0836eddda38fea31ea063c51d4cdc7b", "source_sha256": "f198925e5c21dc828628def1707ba79512014dafa5a425580bbf80881a4b0ed7", "target_language": "lua"}
-- ghsa-patch.mjs — portiert nach lua
-- Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/ghsa-patch.mjs
-- Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

local json = require("cjson")
local io = require("io")
local os = require("os")
local table = require("table")

-- Utility functions
local function fail(message)
  io.stderr:write(message .. "\n")
  os.exit(1)
end

local function usage()
  local lines = {
    "Usage:",
    "  node scripts/ghsa-patch.mjs --ghsa <GHSA-id-or-url> [--repo owner/name]",
    "    --summary <text> --severity <low|medium|high|critical>",
    "    --description-file <path>",
    "    --vulnerable-version-range <range>",
    "    --patched-versions <range-or-null>",
    "    [--package openclaw] [--ecosystem npm] [--cvss <vector>]",
  }
  for _, line in ipairs(lines) do
    io.stderr:write(line .. "\n")
  end
end

local function parseArgs(argv)
  local out = {}
  local i = 1
  while i <= #argv do
    local arg = argv[i]
    if not arg:match("^%-%-") then
      fail("Unexpected argument: " .. arg)
    end
    local key = arg:sub(3)
    local value = argv[i + 1]
    if not value or value:match("^%-%-") then
      fail("Missing value for --" .. key)
    end
    out[key] = value
    i = i + 2
  end
  return out
end

local function runGh(args)
  local cmd = "gh " .. table.concat(args, " ")
  local handle = io.popen(cmd, "r")
  local result = handle:read("*a")
  local success, exitReason, exitCode = handle:close()
  if not success then
    fail(result:match("%S+") or ("gh " .. table.concat(args, " ") .. " failed"))
  end
  return result
end

local function deriveRepoFromOrigin()
  local handle = io.popen("git remote get-url origin", "r")
  local remote = handle:read("*l"):gsub("%s+", "")
  handle:close()
  local httpsMatch = remote:match("github%.com[/:]([^/]+)/([^/.]+)%.git")
  if not httpsMatch then
    fail("Could not parse origin remote: " .. remote)
  end
  return httpsMatch:gsub("%.git$", "")
end

local function parseGhsaId(value)
  local match = value:match("GHSA%-[a-z0-9]+%-[a-z0-9]+%-[a-z0-9]+")
  if not match then
    fail("Could not parse GHSA id from: " .. value)
  end
  return match
end

local function writeTempJson(data)
  local filename = "/tmp/ghsa-patch-" .. tostring(os.time()) .. ".json"
  local file = io.open(filename, "w")
  file:write(json.encode(data))
  file:close()
  return filename
end

-- Main script logic
local args = parseArgs(arg)

if not args.ghsa or not args.summary or not args.severity or not args["description-file"] then
  usage()
  os.exit(1)
end

local repo = args.repo or deriveRepoFromOrigin()
local ghsaId = parseGhsaId(args.ghsa)
local advisoryPath = "/repos/" .. repo .. "/security-advisories/" .. ghsaId
local descriptionPath = args["description-file"]

if not io.open(descriptionPath, "r") then
  fail("Description file does not exist: " .. descriptionPath)
end

local current = json.decode(runGh({"api", "-H", "X-GitHub-Api-Version: 2022-11-28", advisoryPath}))
local restoredCvss = args.cvss or (current and current.cvss and current.cvss.vector_string) or nil

local ecosystem = args.ecosystem or "npm"
local packageName = args.package or "openclaw"
local vulnerableRange = args["vulnerable-version-range"]
local patchedVersionsRaw = args["patched-versions"]

if not vulnerableRange then
  fail("Missing --vulnerable-version-range")
end
if not patchedVersionsRaw then
  fail("Missing --patched-versions")
end

local patchedVersions = (patchedVersionsRaw == "null") and nil or patchedVersionsRaw

local descriptionFile = io.open(descriptionPath, "r")
local description = descriptionFile:read("*a")
descriptionFile:close()

local payload = {
  summary = args.summary,
  severity = args.severity,
  description = description,
  vulnerabilities = {{
    package = {
      ecosystem = ecosystem,
      name = packageName,
    },
    vulnerable_version_range = vulnerableRange,
    patched_versions = patchedVersions,
    vulnerable_functions = {},
  }},
}

local patchFile = writeTempJson(payload)
runGh({
  "api",
  "-H",
  "X-GitHub-Api-Version: 2022-11-28",
  "-X",
  "PATCH",
  advisoryPath,
  "--input",
  patchFile,
})

if restoredCvss then
  runGh({
    "api",
    "-H",
    "X-GitHub-Api-Version: 2022-11-28",
    "-X",
    "PATCH",
    advisoryPath,
    "-f",
    "cvss_vector_string=" .. restoredCvss,
  })
end

local refreshed = json.decode(runGh({"api", "-H", "X-GitHub-Api-Version: 2022-11-28", advisoryPath}))

print(json.encode({
  html_url = refreshed.html_url,
  state = refreshed.state,
  severity = refreshed.severity,
  summary = refreshed.summary,
  vulnerabilities = refreshed.vulnerabilities,
  cvss = refreshed.cvss,
  updated_at = refreshed.updated_at,
}))
