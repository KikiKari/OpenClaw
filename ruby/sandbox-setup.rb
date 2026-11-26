#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "1676e746adff227c53b6c1667c2acadb75203ca1cc53722263e40a4115dfb83f", "source_sha256": "7b2c2cb6fd7efb0ae2db61fbe33805abf06e72ace6dee56ecc1c14b6e6bcf9cf", "target_language": "ruby"}
# sandbox-setup.sh — portiert nach ruby
# Quelle: shell, Onboarding@main:scripts/sandbox-setup.sh
# Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

# Provisioniert die Claude-Code-Sandbox (Remote-Umgebung) reproduzierbar:
#   - Node-Dependencies (Frontend, npm)
#   - Python-Dependencies (Backend inkl. pytest)
#   - Medien-Tools: ffmpeg, ImageMagick, GIMP, Blender headless (apt) —
#     Fehlschlag blockiert die Session nicht; --skip-heavy laesst GIMP/Blender aus
# Idempotent: bereits Vorhandenes wird uebersprungen; der Container-Cache der
# Umgebung macht die apt-Installation zum Einmal-Aufwand.

require 'fileutils'
require 'open3'
require 'timeout'

def log(message)
  puts "[sandbox-setup] #{message}"
end

def run_command(command, error_message = nil, allow_failure: false)
  stdout, stderr, status = Open3.capture3(command)
  unless status.success? || allow_failure
    log(error_message || "FEHLER: Befehl fehlgeschlagen: #{command}")
    exit 1
  end
  [stdout.strip, stderr.strip, status]
end

def command_exists?(command)
  system("which #{command} > /dev/null 2>&1")
end

def apt_install(pkg, bin_name)
  if command_exists?(bin_name)
    version_output = `#{bin_name} --version 2>&1`.lines.first&.strip || ""
    log("#{pkg} bereits vorhanden (#{version_output})")
    return
  end

  log("Installiere #{pkg} …")
  unless @apt_updated
    ENV['DEBIAN_FRONTEND'] = 'noninteractive'
    run_command('apt-get update -qq', "FEHLER: apt-get update fehlgeschlagen", allow_failure: true)
    @apt_updated = true
  end

  result = system("DEBIAN_FRONTEND=noninteractive apt-get install -y -qq #{pkg} > /dev/null 2>&1")
  unless result
    log("WARNUNG: #{pkg} konnte nicht installiert werden (Netzwerk-Policy?) — Medien-Schritte ggf. eingeschraenkt")
  end
end

# Parse arguments
skip_heavy = ARGV.include?("--skip-heavy")

# Change to script directory
script_dir = File.dirname(File.realpath(__FILE__))
root_dir = File.join(script_dir, "..")
Dir.chdir(root_dir)

# Node dependencies
log("Node-Dependencies (npm install) …")
run_command("npm install --no-audit --no-fund", "FEHLER: npm install fehlgeschlagen")

# Python dependencies
log("Python-Dependencies (backend/requirements-dev.txt) …")
run_command("pip3 install --quiet -r backend/requirements-dev.txt", "FEHLER: pip install fehlgeschlagen")

# Media tools
@apt_updated = false
apt_install("ffmpeg", "ffmpeg")
apt_install("imagemagick", "convert")

unless skip_heavy
  apt_install("gimp", "gimp")
  apt_install("blender", "blender")
end

# Visual QA tools
apt_install("xvfb", "Xvfb")
apt_install("x11-utils", "xdpyinfo")
apt_install("libnss3-tools", "certutil")

# Install Google Chrome if not present
unless command_exists?("google-chrome-stable")
  log("Installiere Google Chrome Stable …")
  tmp_deb = "/tmp/chrome.deb"
  begin
    Timeout.timeout(30) do
      success = system("curl -fsSL -o #{tmp_deb} https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb")
      if success
        result = system("DEBIAN_FRONTEND=noninteractive apt-get install -y -qq #{tmp_deb} > /dev/null 2>&1")
        if result
          chrome_version = `google-chrome-stable --version 2>/dev/null`.strip rescue ""
          log("Chrome installiert: #{chrome_version}")
        else
          log("WARNUNG: Chrome-Installation fehlgeschlagen")
        end
      else
        log("WARNUNG: Chrome-Download fehlgeschlagen (Netzwerk-Policy?)")
      end
    end
  rescue Timeout::Error
    log("WARNUNG: Chrome-Download timeout")
  ensure
    FileUtils.rm_f(tmp_deb)
  end
end

# Proxy-CA in Chrome NSS store
if command_exists?("certutil") && File.exist?("/root/.ccr/ca-bundle.crt")
  nssdb_path = "#{ENV['HOME']}/.pki/nssdb"
  FileUtils.mkdir_p(nssdb_path)
  system("certutil -d sql:#{nssdb_path} -N --empty-password 2>/dev/null", out: File::NULL, err: File::NULL)
  
  if system("certutil -d sql:#{nssdb_path} -L 2>/dev/null | grep -q ccr-proxy-ca", out: File::NULL, err: File::NULL)
    # CA already exists
  else
    result = system("certutil -d sql:#{nssdb_path} -A -t \"C,,\" -n ccr-proxy-ca -i /root/.ccr/ca-bundle.crt 2>/dev/null", out: File::NULL, err: File::NULL)
    if result
      log("Proxy-CA in Chrome-NSS-Store importiert")
    end
  end
end

# Playwright installation
if Dir.exist?("node_modules") && !File.exist?("node_modules/playwright")
  if command_exists?("npm")
    result = system("npm install --no-audit --no-fund --no-save playwright > /dev/null 2>&1", out: File::NULL, err: File::NULL)
    if result
      log("Playwright (Node) installiert")
    else
      log("WARNUNG: Playwright-npm-Install fehlgeschlagen")
    end
  end
end

# Git push configuration
if system("git rev-parse --is-inside-work-tree > /dev/null 2>&1", out: File::NULL, err: File::NULL)
  credential_helper = "!#{Dir.pwd}/.claude/git-credential-pat.sh"
  run_command("git config credential.https://x-access-token@github.com.helper \"#{credential_helper}\"", allow_failure: true)
  run_command("git remote set-url --push origin \"https://x-access-token@github.com/KikiKari/Onboarding.git\"", allow_failure: true)
  log("Git-Push-Route: direkt zu github.com (PAT via Credential-Helper)")
end

# Docker daemon setup
if command_exists?("dockerd") && !system("docker info > /dev/null 2>&1", out: File::NULL, err: File::NULL)
  log("Starte Docker-Daemon (Registry-Mirror: mirror.gcr.io) …")
  FileUtils.mkdir_p("/etc/docker")
  
  daemon_config = "/etc/docker/daemon.json"
  unless File.exist?(daemon_config)
    File.write(daemon_config, '{"registry-mirrors":["https://mirror.gcr.io"]}')
  end
  
  # Start docker daemon in background
  system("(dockerd > /tmp/dockerd.log 2>&1 &)", out: File::NULL, err: File::NULL)
  
  # Wait for docker to start (max 15 seconds)
  15.times do
    if system("docker info > /dev/null 2>&1", out: File::NULL, err: File::NULL)
      break
    end
    sleep 1
  end
  
  if system("docker info > /dev/null 2>&1", out: File::NULL, err: File::NULL)
    log("Docker-Daemon laeuft")
  else
    log("WARNUNG: Docker-Daemon nicht gestartet")
  end
end

# Final version output
log("Fertig. Versionen:")
puts "[sandbox-setup]   node #{`node --version`.strip}"
puts "[sandbox-setup]   #{`python3 --version`.strip}"

if command_exists?("ffmpeg")
  version_line = `ffmpeg -version 2>/dev/null`.lines.first&.strip || ""
  puts "[sandbox-setup]   #{version_line}"
end

if command_exists?("convert")
  version_line = `convert -version 2>/dev/null`.lines.first&.strip || ""
  puts "[sandbox-setup]   #{version_line}"
end

if command_exists?("gimp") && !skip_heavy
  version_line = `gimp --version 2>/dev/null`.lines.first&.strip || ""
  puts "[sandbox-setup]   #{version_line}"
end

if command_exists?("blender") && !skip_heavy
  version_line = `blender --version 2>/dev/null`.lines.first&.strip || ""
  puts "[sandbox-setup]   #{version_line}"
end

exit 0
