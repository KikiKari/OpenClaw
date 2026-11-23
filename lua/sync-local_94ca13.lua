#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "41fd9af9b92fdf4d8be2d717005cc24bb2b4e14c9c315bf59fd89212b43be837", "source_sha256": "94ca1324b379194574325edaa6a3862182f09ae2d497d1200288dad11f17bde2", "target_language": "lua"}
-- sync-local.sh — portiert nach lua
-- Quelle: shell, Onboarding@main:scripts/sync-local.sh
-- Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

-- Lua-Äquivalent zu sync-local.ps1 — inkrementeller Git-Sync für den Dev-Stack.
-- Nutzung: scripts/sync-local.lua [--branch <name>] [--interval <s>] [--once]

local os = require("os")
local io = require("io")
local table = require("table")

local BRANCH = "claude/onboarding-persistent-sandbox-vjfmcx"
local INTERVAL = 20
local COMPOSE_FILE = "docker-compose.dev.yml"
local ONCE = false

local args = {...}
local i = 1
while i <= #args do
  local arg = args[i]
  if arg == "--branch" then
    BRANCH = args[i + 1]
    i = i + 2
  elseif arg == "--interval" then
    INTERVAL = tonumber(args[i + 1])
    i = i + 2
  elseif arg == "--once" then
    ONCE = true
    i = i + 1
  else
    io.stderr:write("Unbekannte Option: " .. arg .. "\n")
    os.exit(1)
  end
end

-- Hilfsfunktionen
local function dirname(path)
  return path:match("^(.*)[/\\]")
end

local function chdir(path)
  local success, err = os.execute("cd " .. path)
  if not success then
    error("Konnte nicht wechseln zu: " .. path .. " (" .. err .. ")")
  end
end

local function log(msg)
  local date = os.date("%H:%M:%S")
  print(string.format("[%s] %s", date, msg))
end

local function compose(...)
  local cmd = "docker compose -f " .. COMPOSE_FILE .. " " .. table.concat({...}, " ")
  local success = os.execute(cmd)
  if not success then
    log("WARNUNG: docker compose " .. table.concat({...}, " ") .. " fehlgeschlagen")
  end
end

-- In das Hauptverzeichnis wechseln
local script_path = arg[0]:gsub("\\", "/")
local dir = dirname(dirname(script_path))
chdir(dir)

-- Aktuellen Branch prüfen und ggf. wechseln
local function get_current_branch()
  local f = io.popen("git rev-parse --abbrev-ref HEAD 2>/dev/null")
  local output = f:read("*a"):gsub("\n$", "")
  f:close()
  return output
end

local current = get_current_branch()
if current ~= BRANCH then
  log("Wechsle von '" .. current .. "' auf '" .. BRANCH .. "' …")
  os.execute("git fetch origin " .. BRANCH)
  local success = os.execute("git switch " .. BRANCH .. " 2>/dev/null")
  if not success then
    os.execute("git switch -c " .. BRANCH .. " --track origin/" .. BRANCH)
  end
end

log("Sync aktiv: origin/" .. BRANCH .. " -> " .. dir .. " (Intervall " .. INTERVAL .. "s, Compose: " .. COMPOSE_FILE .. ")")

-- Hauptschleife
while true do
  local fetch_success = os.execute("git fetch origin " .. BRANCH .. " --quiet 2>/dev/null")
  if not fetch_success then
    log("Fetch fehlgeschlagen (Netzwerk?) — nächster Versuch in " .. INTERVAL .. "s")
  else
    local function git_rev_parse(ref)
      local f = io.popen("git rev-parse " .. ref .. " 2>/dev/null")
      local output = f:read("*a"):gsub("\n$", "")
      f:close()
      return output
    end

    local local_rev = git_rev_parse("HEAD")
    local remote_rev = git_rev_parse("origin/" .. BRANCH)

    if local_rev ~= remote_rev then
      local is_ancestor_cmd = "git merge-base --is-ancestor " .. local_rev .. " " .. remote_rev .. " 2>/dev/null"
      local is_ancestor = os.execute(is_ancestor_cmd)
      
      if not is_ancestor then
        log("ACHTUNG: Lokaler Stand von origin/" .. BRANCH .. " abgewichen — kein automatischer Merge, bitte manuell auflösen.")
      else
        local f = io.popen("git diff --name-only " .. local_rev .. ".." .. remote_rev .. " 2>/dev/null")
        local changed_lines = {}
        for line in f:lines() do
          table.insert(changed_lines, line)
        end
        f:close()

        local changed_count = #changed_lines
        os.execute("git merge --ff-only " .. remote_rev .. " --quiet 2>/dev/null")
        log("Aktualisiert " .. local_rev:sub(1, 7) .. " -> " .. remote_rev:sub(1, 7) .. " (" .. changed_count .. " Datei(en))")

        local needs_none = true
        local changed_set = {}
        for _, file in ipairs(changed_lines) do
          changed_set[file] = true
        end

        if changed_set[COMPOSE_FILE] then
          log("Compose-Datei geändert — erzeuge Dev-Stack neu …")
          compose("up", "-d")
          needs_none = false
        end

        for file, _ in pairs(changed_set) do
          if file:match("^backend/(Dockerfile$|requirements.*%.txt$)") then
            log("Backend-Dependencies/Dockerfile geändert — baue nur das Backend neu …")
            compose("up", "-d", "--build", "backend")
            needs_none = false
            break
          end
        end

        for file, _ in pairs(changed_set) do
          if file == "package.json" or file == "package-lock.json" then
            log("Frontend-Dependencies geändert — starte Frontend neu (npm install läuft im Container) …")
            compose("restart", "frontend")
            needs_none = false
            break
          end
        end

        if needs_none then
          log("Nur Quellcode/Assets — Hot-Reload übernimmt, kein Build nötig.")
        end
      end
    end
  end

  if ONCE then
    break
  end

  os.execute("sleep " .. INTERVAL)
end
