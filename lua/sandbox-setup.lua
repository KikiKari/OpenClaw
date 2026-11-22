#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "2392c6ceb16045efa701f1f4e001142e8675e43660721cb9f766bd71c050af98", "source_sha256": "7b2c2cb6fd7efb0ae2db61fbe33805abf06e72ace6dee56ecc1c14b6e6bcf9cf", "target_language": "lua"}
-- sandbox-setup.sh — portiert nach lua
-- Quelle: shell, Onboarding@main:scripts/sandbox-setup.sh
-- Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

local SKIP_HEAVY = arg[1] == "--skip-heavy" and 1 or 0

local function dirname(path)
  local match = path:match("^(.*)[/\\][^/\\]*$")
  return match or "."
end

local script_dir = dirname(debug.getinfo(1).source:sub(2))
local root_dir = script_dir .. "/.."

local function log(msg)
  print("[sandbox-setup] " .. msg)
end

-- Change directory to project root
os.execute("cd " .. root_dir)

log("Node-Dependencies (npm install) …")
local npm_result = os.execute("npm install --no-audit --no-fund")
if not npm_result then
  log("FEHLER: npm install fehlgeschlagen")
  os.exit(1)
end

log("Python-Dependencies (backend/requirements-dev.txt) …")
local pip_result = os.execute("pip3 install --quiet -r backend/requirements-dev.txt")
if not pip_result then
  log("FEHLER: pip install fehlgeschlagen")
  os.exit(1)
end

local APT_UPDATED = 0

local function apt_install(pkg, bin)
  local handle = io.popen("command -v " .. bin .. " >/dev/null 2>&1 && echo found || echo missing")
  local result = handle:read("*l")
  handle:close()
  
  if result == "found" then
    local version_handle = io.popen(bin .. " --version 2>&1 | head -1")
    local version_output = version_handle:read("*l") or ""
    version_handle:close()
    log(pkg .. " bereits vorhanden (" .. version_output .. ")")
    return true
  end
  
  log("Installiere " .. pkg .. " …")
  if APT_UPDATED == 0 then
    local update_result = os.execute("DEBIAN_FRONTEND=noninteractive apt-get update -qq")
    if update_result then
      APT_UPDATED = 1
    end
  end
  
  local install_result = os.execute("DEBIAN_FRONTEND=noninteractive apt-get install -y -qq " .. pkg .. " >/dev/null 2>&1")
  if not install_result then
    log("WARNUNG: " .. pkg .. " konnte nicht installiert werden (Netzwerk-Policy?) — Medien-Schritte ggf. eingeschraenkt")
  end
  return install_result
end

apt_install("ffmpeg", "ffmpeg")
apt_install("imagemagick", "convert")

if SKIP_HEAVY == 0 then
  apt_install("gimp", "gimp")
  apt_install("blender", "blender")
end

apt_install("xvfb", "Xvfb")
apt_install("x11-utils", "xdpyinfo")
apt_install("libnss3-tools", "certutil")

-- Install Google Chrome
local chrome_handle = io.popen("command -v google-chrome-stable >/dev/null 2>&1 && echo found || echo missing")
local chrome_result = chrome_handle:read("*l")
chrome_handle:close()

if chrome_result == "missing" then
  log("Installiere Google Chrome Stable …")
  local tmpdeb = "/tmp/chrome.deb"
  local download_result = os.execute("curl -fsSL -o " .. tmpdeb .. " https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb")
  
  if download_result then
    local install_result = os.execute("DEBIAN_FRONTEND=noninteractive apt-get install -y -qq " .. tmpdeb .. " >/dev/null 2>&1")
    if install_result then
      local version_handle = io.popen("google-chrome-stable --version 2>/dev/null")
      local version_output = version_handle:read("*l") or ""
      version_handle:close()
      log("Chrome installiert: " .. version_output)
    else
      log("WARNUNG: Chrome-Installation fehlgeschlagen")
    end
  else
    log("WARNUNG: Chrome-Download fehlgeschlagen (Netzwerk-Policy?)")
  end
  os.remove(tmpdeb)
end

-- Import proxy CA into Chrome NSS DB
local certutil_handle = io.popen("command -v certutil >/dev/null 2>&1 && echo found || echo missing")
local certutil_result = certutil_handle:read("*l")
certutil_handle:close()

if certutil_result == "found" and os.execute("[ -f /root/.ccr/ca-bundle.crt ]") then
  os.execute("mkdir -p \"$HOME/.pki/nssdb\"")
  os.execute("certutil -d sql:\"$HOME/.pki/nssdb\" -N --empty-password 2>/dev/null || true")
  
  local cert_check = io.popen("certutil -d sql:\"$HOME/.pki/nssdb\" -L 2>/dev/null | grep -q ccr-proxy-ca && echo found || echo missing")
  local cert_found = cert_check:read("*l")
  cert_check:close()
  
  if cert_found == "missing" then
    local import_result = os.execute("certutil -d sql:\"$HOME/.pki/nssdb\" -A -t \"C,,\" -n ccr-proxy-ca -i /root/.ccr/ca-bundle.crt 2>/dev/null")
    if import_result then
      log("Proxy-CA in Chrome-NSS-Store importiert")
    end
  end
end

-- Install Playwright
if os.execute("[ -d node_modules ]") and not os.execute("[ -e node_modules/playwright ]") then
  local npm_handle = io.popen("command -v npm >/dev/null 2>&1 && echo found || echo missing")
  local npm_result = npm_handle:read("*l")
  npm_handle:close()
  
  if npm_result == "found" then
    local install_result = os.execute("npm install --no-audit --no-fund --no-save playwright >/dev/null 2>&1")
    if install_result then
      log("Playwright (Node) installiert")
    else
      log("WARNUNG: Playwright-npm-Install fehlgeschlagen")
    end
  end
end

-- Configure Git push route
local git_handle = io.popen("git rev-parse --is-inside-work-tree >/dev/null 2>&1 && echo inside || echo outside")
local git_result = git_handle:read("*l")
git_handle:close()

if git_result == "inside" then
  os.execute("git config credential.\"https://x-access-token@github.com\".helper \"!$(pwd)/.claude/git-credential-pat.sh\"")
  os.execute("git remote set-url --push origin \"https://x-access-token@github.com/KikiKari/Onboarding.git\"")
  log("Git-Push-Route: direkt zu github.com (PAT via Credential-Helper)")
end

-- Start Docker daemon
local docker_handle = io.popen("command -v dockerd >/dev/null 2>&1 && echo found || echo missing")
local docker_result = docker_handle:read("*l")
docker_handle:close()

if docker_result == "found" then
  local docker_info_handle = io.popen("docker info >/dev/null 2>&1 && echo running || echo stopped")
  local docker_info_result = docker_info_handle:read("*l")
  docker_info_handle:close()
  
  if docker_info_result == "stopped" then
    log("Starte Docker-Daemon (Registry-Mirror: mirror.gcr.io) …")
    os.execute("mkdir -p /etc/docker")
    
    local daemon_exists = io.open("/etc/docker/daemon.json", "r")
    if not daemon_exists then
      local daemon_file = io.open("/etc/docker/daemon.json", "w")
      if daemon_file then
        daemon_file:write('{"registry-mirrors":["https://mirror.gcr.io"]}')
        daemon_file:close()
      end
    else
      daemon_exists:close()
    end
    
    os.execute("(dockerd >/tmp/dockerd.log 2>&1 &)")

    for i = 1, 15 do
      local check_handle = io.popen("docker info >/dev/null 2>&1 && echo running || echo stopped")
      local check_result = check_handle:read("*l")
      check_handle:close()
      
      if check_result == "running" then
        break
      end
      os.execute("sleep 1")
    end
    
    local final_check_handle = io.popen("docker info >/dev/null 2>&1 && echo running || echo stopped")
    local final_check_result = final_check_handle:read("*l")
    final_check_handle:close()
    
    if final_check_result == "running" then
      log("Docker-Daemon laeuft")
    else
      log("WARNUNG: Docker-Daemon nicht gestartet")
    end
  end
end

log("Fertig. Versionen:")
local node_version = io.popen("node --version 2>/dev/null"):read("*l")
if node_version then
  print("[sandbox-setup]   node " .. node_version)
end

local python_version = io.popen("python3 --version 2>/dev/null"):read("*l")
if python_version then
  print("[sandbox-setup]   " .. python_version)
end

local ffmpeg_version = io.popen("command -v ffmpeg >/dev/null && ffmpeg -version 2>/dev/null | head -1"):read("*l")
if ffmpeg_version then
  print("[sandbox-setup]   " .. ffmpeg_version)
end

local convert_version = io.popen("command -v convert >/dev/null && convert -version 2>/dev/null | head -1"):read("*l")
if convert_version then
  print("[sandbox-setup]   " .. convert_version)
end

local gimp_version = io.popen("command -v gimp >/dev/null && gimp --version 2>/dev/null | head -1"):read("*l")
if gimp_version then
  print("[sandbox-setup]   " .. gimp_version)
end

local blender_version = io.popen("command -v blender >/dev/null && blender --version 2>/dev/null | head -1"):read("*l")
if blender_version then
  print("[sandbox-setup]   " .. blender_version)
end

os.exit(0)
