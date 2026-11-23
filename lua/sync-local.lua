#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "c2a9c0d1333077c76c524ecfc285e2872094754918ddc6e5ab02510b59c0813b", "source_sha256": "b97ad7dc26be724af240b4c0c98ec196e729e0702664b99c65e0e3c435a1b5af", "target_language": "lua"}
-- sync-local.ps1 — portiert nach lua
-- Quelle: powershell, Onboarding@main:scripts/sync-local.ps1
-- Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

--[[
.SYNOPSIS
  Hält den lokalen Dev-Stack (docker-compose.dev.yml) inkrementell mit GitHub synchron.

.DESCRIPTION
  Pollt origin/<Branch> und zieht neue Commits per Fast-Forward. Danach entscheidet
  der Diff, was nötig ist:
    - nur Quellcode geändert            -> nichts tun, Hot-Reload übernimmt
    - package.json / package-lock.json  -> Frontend-Container neu starten
                                           (Entrypoint installiert Dependencies nur
                                           bei geändertem Lockfile-Hash nach)
    - backend/Dockerfile, requirements* -> Backend-Image gezielt neu bauen
    - docker-compose.dev.yml            -> Dev-Stack neu erzeugen
  Es wird nie „blind" der ganze Branch neu gebaut.

.EXAMPLE
  lua scripts/sync-local.lua                # Dauerbetrieb, 20-s-Intervall
  lua scripts/sync-local.lua --once         # genau ein Sync-Durchlauf
  lua scripts/sync-local.lua --branch main # anderen Branch verfolgen
--]]

local argparse = require("argparse")
local parser = argparse("sync-local", "Hält den lokalen Dev-Stack inkrementell mit GitHub synchron.")
parser:argument("--branch", "Zu verfolgender Branch"):default("claude/onboarding-persistent-sandbox-vjfmcx")
parser:option("--interval", "Polling-Intervall in Sekunden"):default(20):convert(tonumber)
parser:option("--compose-file", "Docker Compose Datei"):default("docker-compose.dev.yml")
parser:flag("--once", "Nur einen Sync-Durchlauf durchführen")

local args = parser:parse()

local function log(msg)
  print(os.date("%H:%M:%S") .. " " .. msg)
end

local function execute_command(cmd)
  local handle = io.popen(cmd)
  local result = handle:read("*a")
  local success, _, code = handle:close()
  return result, success, code
end

local function invoke_compose(compose_args)
  local cmd = "docker compose -f " .. args.compose_file .. " " .. table.concat(compose_args, " ")
  local _, success, code = execute_command(cmd)
  if not success then
    log("WARNUNG: docker compose " .. table.concat(compose_args, " ") .. " fehlgeschlagen (Exit " .. tostring(code) .. ")")
  end
end

-- Sicherstellen, dass der Ziel-Branch ausgecheckt ist.
local current_result, _, _ = execute_command("git rev-parse --abbrev-ref HEAD")
local current = current_result:gsub("^%s*(.-)%s*$", "%1")
if current ~= args.branch then
  log("Wechsle von '" .. current .. "' auf '" .. args.branch .. "' …")
  execute_command("git fetch origin " .. args.branch)
  local _, success, _ = execute_command("git switch " .. args.branch .. " 2>/dev/null")
  if not success then
    local _, success2, _ = execute_command("git switch -c " .. args.branch .. " --track origin/" .. args.branch)
    if not success2 then
      error("Branch '" .. args.branch .. "' konnte nicht ausgecheckt werden.")
    end
  end
end

log("Sync aktiv: origin/" .. args.branch .. " -> " .. os.getenv("PWD") .. " (Intervall " .. args.interval .. "s, Compose: " .. args.compose_file .. ")")

while true do
  local _, fetch_success, _ = execute_command("git fetch origin " .. args.branch .. " --quiet")
  if not fetch_success then
    log("Fetch fehlgeschlagen (Netzwerk?) — nächster Versuch in " .. args.interval .. "s")
  else
    local local_result, _, _ = execute_command("git rev-parse HEAD")
    local local_commit = local_result:gsub("^%s*(.-)%s*$", "%1")
    local remote_result, _, _ = execute_command("git rev-parse origin/" .. args.branch)
    local remote_commit = remote_result:gsub("^%s*(.-)%s*$", "%1")

    if local_commit ~= remote_commit then
      local _, ancestor_success, _ = execute_command("git merge-base --is-ancestor " .. local_commit .. " " .. remote_commit)
      if not ancestor_success then
        log("ACHTUNG: Lokaler Stand ist von origin/" .. args.branch .. " abgewichen (lokale Commits?). Kein automatischer Merge — bitte manuell auflösen.")
      else
        local changed_result, _, _ = execute_command("git diff --name-only " .. local_commit .. ".." .. remote_commit)
        local _, merge_success, _ = execute_command("git merge --ff-only " .. remote_commit .. " --quiet")
        if merge_success then
          log("Aktualisiert " .. local_commit:sub(1, 7) .. " -> " .. remote_commit:sub(1, 7) .. " (" .. #changed_result:split("\n") .. " Datei(en))")
        end

        local changed_files = {}
        for line in changed_result:gmatch("[^\r\n]+") do
          table.insert(changed_files, line)
        end

        local frontend_deps = false
        local backend_image = false
        local compose_changed = false

        for _, file in ipairs(changed_files) do
          if file == "package.json" or file == "package-lock.json" then
            frontend_deps = true
          elseif file:match("^backend/(Dockerfile$|requirements.*%.txt$)") then
            backend_image = true
          elseif file == args.compose_file then
            compose_changed = true
          end
        end

        if compose_changed then
          log("Compose-Datei geändert — erzeuge Dev-Stack neu …")
          invoke_compose({"up", "-d"})
        end
        if backend_image then
          log("Backend-Dependencies/Dockerfile geändert — baue nur das Backend neu …")
          invoke_compose({"up", "-d", "--build", "backend"})
        end
        if frontend_deps then
          log("Frontend-Dependencies geändert — starte Frontend neu (npm install läuft im Container) …")
          invoke_compose({"restart", "frontend"})
        end
        if not (compose_changed or backend_image or frontend_deps) then
          log("Nur Quellcode/Assets — Hot-Reload übernimmt, kein Build nötig.")
        end
      end
    end
  end

  if args.once then break end
  os.execute("sleep " .. args.interval)
end

function string:split(sep)
  local sep, fields = sep or " ", {}
  local pattern = string.format("([^%s]+)", sep)
  self:gsub(pattern, function(c) fields[#fields+1] = c end)
  return fields
end
