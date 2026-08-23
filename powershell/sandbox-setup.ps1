#!/usr/bin/env pwsh
# sandbox-setup.sh — portiert nach powershell
# Quelle: shell, Onboarding@main:scripts/sandbox-setup.sh
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

# Provisioniert die Claude-Code-Sandbox (Remote-Umgebung) reproduzierbar:
#   - Node-Dependencies (Frontend, npm)
#   - Python-Dependencies (Backend inkl. pytest)
#   - Medien-Tools: ffmpeg, ImageMagick, GIMP, Blender headless (apt) —
#     Fehlschlag blockiert die Session nicht; --skip-heavy laesst GIMP/Blender aus
# Idempotent: bereits Vorhandenes wird uebersprungen; der Container-Cache der
# Umgebung macht die apt-Installation zum Einmal-Aufwand.

$ErrorActionPreference = "Stop"
$SKIP_HEAVY = 0
if ($args.Count -gt 0 -and $args[0] -eq "--skip-heavy") {
    $SKIP_HEAVY = 1
}

Set-Location "$(Split-Path $PSScriptRoot)/.."

function Log($message) {
    Write-Host "[sandbox-setup] $message"
}

Log "Node-Dependencies (npm install) …"
npm install --no-audit --no-fund
if ($LASTEXITCODE -ne 0) {
    Log "FEHLER: npm install fehlgeschlagen"
    exit 1
}

Log "Python-Dependencies (backend/requirements-dev.txt) …"
pip3 install --quiet -r backend/requirements-dev.txt
if ($LASTEXITCODE -ne 0) {
    Log "FEHLER: pip install fehlgeschlagen"
    exit 1
}

$APT_UPDATED = 0

function AptInstall($pkg, $bin) {
    if (Get-Command $bin -ErrorAction SilentlyContinue) {
        try {
            $versionOutput = & $bin "-version" 2>&1 | Select-Object -First 1
        } catch {
            $versionOutput = ""
        }
        Log "$pkg bereits vorhanden ($versionOutput)"
        return
    }
    
    Log "Installiere $pkg …"
    if ($script:APT_UPDATED -eq 0) {
        $env:DEBIAN_FRONTEND = "noninteractive"
        apt-get update -qq
        if ($LASTEXITCODE -eq 0) {
            $script:APT_UPDATED = 1
        }
    }
    
    $env:DEBIAN_FRONTEND = "noninteractive"
    apt-get install -y -qq $pkg 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Log "WARNUNG: $pkg konnte nicht installiert werden (Netzwerk-Policy?) — Medien-Schritte ggf. eingeschraenkt"
    }
}

AptInstall "ffmpeg" "ffmpeg"
AptInstall "imagemagick" "convert"
if ($SKIP_HEAVY -eq 0) {
    AptInstall "gimp" "gimp"
    AptInstall "blender" "blender"
}

# Visual QA: echtes Google Chrome (H.264/AAC-Codecs → Videos sichtbar; der
# Playwright-Bundle-Chromium hat keine proprietären Codecs), Xvfb (headed-Läufe
# für echte Web-Logins) und NSS-Tools, um die Proxy-CA in Chromes Trust-Store zu
# importieren. Ohne all das: Videos schwarz bzw. TLS-Fehler beim externen Surfen.
AptInstall "xvfb" "Xvfb"
AptInstall "x11-utils" "xdpyinfo"
AptInstall "libnss3-tools" "certutil"

if (-not (Get-Command google-chrome-stable -ErrorAction SilentlyContinue)) {
    Log "Installiere Google Chrome Stable …"
    $TMPDEB = [System.IO.Path]::GetTempFileName() + ".deb"
    try {
        Invoke-WebRequest -Uri "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb" -OutFile $TMPDEB -UseBasicParsing
        if (Test-Path $TMPDEB) {
            $env:DEBIAN_FRONTEND = "noninteractive"
            apt-get install -y -qq $TMPDEB 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $chromeVersion = & google-chrome-stable --version 2>$null
                Log "Chrome installiert: $chromeVersion"
            } else {
                Log "WARNUNG: Chrome-Installation fehlgeschlagen"
            }
            Remove-Item $TMPDEB -Force
        }
    } catch {
        Log "WARNUNG: Chrome-Download fehlgeschlagen (Netzwerk-Policy?)"
        if (Test-Path $TMPDEB) {
            Remove-Item $TMPDEB -Force
        }
    }
}

# Proxy-CA in Chromes NSS-DB, damit externes HTTPS ohne Zertifikatsfehler läuft.
if ((Get-Command certutil -ErrorAction SilentlyContinue) -and (Test-Path "/root/.ccr/ca-bundle.crt")) {
    $NSSDBPath = "$HOME/.pki/nssdb"
    New-Item -ItemType Directory -Path $NSSDBPath -Force | Out-Null
    & certutil -d "sql:$NSSDBPath" -N --empty-password 2>$null
    $certList = & certutil -d "sql:$NSSDBPath" -L 2>$null
    if (-not ($certList -match "ccr-proxy-ca")) {
        & certutil -d "sql:$NSSDBPath" -A -t "C,," -n ccr-proxy-ca -i /root/.ccr/ca-bundle.crt 2>$null
        if ($LASTEXITCODE -eq 0) {
            Log "Proxy-CA in Chrome-NSS-Store importiert"
        }
    }
}

# Playwright-Node-Module ins Projekt verlinken (visual-qa.mjs / browser-session.mjs).
if ((Test-Path "node_modules") -and -not (Test-Path "node_modules/playwright")) {
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        npm install --no-audit --no-fund --no-save playwright 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Log "Playwright (Node) installiert"
        } else {
            Log "WARNUNG: Playwright-npm-Install fehlgeschlagen"
        }
    }
}

# Git-Push-Weg: Der Session-Git-Proxy (origin) ist read-only. Pushes laufen
# direkt zu github.com mit dem Nutzer-PAT (GH_ACCESS_TOKEN aus Umgebungs-Env
# oder .env, geliefert vom Credential-Helper — kein Secret in der Git-Config).
try {
    if (& git rev-parse --is-inside-work-tree 2>$null) {
        $scriptDir = Get-Location
        & git config credential."https://x-access-token@github.com".helper "!$scriptDir/.claude/git-credential-pat.sh"
        & git remote set-url --push origin "https://x-access-token@github.com/KikiKari/Onboarding.git"
        Log "Git-Push-Route: direkt zu github.com (PAT via Credential-Helper)"
    }
} catch {}

# Docker-Daemon fuer Dev-Compose-Verifikation in der Sandbox.
# Docker-Hub-Blobs (cloudfront.docker.com) sind von der Netz-Policy blockiert —
# mirror.gcr.io liefert die Library-Images. Container brauchen zusaetzlich die
# Proxy-CA (siehe docker-compose.sandbox.yml).
if ((Get-Command dockerd -ErrorAction SilentlyContinue) -and -not (& docker info 2>$null)) {
    Log "Starte Docker-Daemon (Registry-Mirror: mirror.gcr.io) …"
    New-Item -ItemType Directory -Path "/etc/docker" -Force | Out-Null
    if (-not (Test-Path "/etc/docker/daemon.json")) {
        '{"registry-mirrors":["https://mirror.gcr.io"]}' | Out-File -FilePath "/etc/docker/daemon.json" -Encoding utf8
    }
    
    Start-Job -ScriptBlock {
        & dockerd > "/tmp/dockerd.log" 2>&1
    } | Out-Null
    
    for ($i = 1; $i -le 15; $i++) {
        if (& docker info 2>$null) {
            break
        }
        Start-Sleep -Seconds 1
    }
    
    if (& docker info 2>$null) {
        Log "Docker-Daemon laeuft"
    } else {
        Log "WARNUNG: Docker-Daemon nicht gestartet"
    }
}

Log "Fertig. Versionen:"
& node --version | ForEach-Object { "[sandbox-setup]   node $_" }
& python3 --version | ForEach-Object { "[sandbox-setup]   $_" }
if (Get-Command ffmpeg -ErrorAction SilentlyContinue) {
    & ffmpeg -version 2>$null | Select-Object -First 1 | ForEach-Object { "[sandbox-setup]   $_" }
}
if (Get-Command convert -ErrorAction SilentlyContinue) {
    & convert -version 2>$null | Select-Object -First 1 | ForEach-Object { "[sandbox-setup]   $_" }
}
if (Get-Command gimp -ErrorAction SilentlyContinue) {
    & gimp --version 2>$null | Select-Object -First 1 | ForEach-Object { "[sandbox-setup]   $_" }
}
if (Get-Command blender -ErrorAction SilentlyContinue) {
    & blender --version 2>$null | Select-Object -First 1 | ForEach-Object { "[sandbox-setup]   $_" }
}

exit 0
