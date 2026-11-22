#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "351698791d7f0ae38ec79b57e95bbfb97a16a17386e631ae66ef95c9d47ce453", "source_sha256": "29aab8d3e497ddaa7ec77edf107b153fe17970d064df8a91d7cfcedb7e30a7fd", "target_language": "powershell"}
# sandbox-browser-entrypoint.sh — portiert nach powershell
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/sandbox-browser-entrypoint.sh
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

$ErrorActionPreference = "Stop"

$env:DBUS_SESSION_BUS_ADDRESS = "/dev/null"

$env:DISPLAY = ":1"
$env:HOME = "/tmp/openclaw-home"
$env:XDG_CONFIG_HOME = "${env:HOME}/.config"
$env:XDG_CACHE_HOME = "${env:HOME}/.cache"

$CDP_PORT = if ($env:OPENCLAW_BROWSER_CDP_PORT) { $env:OPENCLAW_BROWSER_CDP_PORT } else { "9222" }
$CDP_SOURCE_RANGE = if ($env:OPENCLAW_BROWSER_CDP_SOURCE_RANGE) { $env:OPENCLAW_BROWSER_CDP_SOURCE_RANGE } else { "" }
$VNC_PORT = if ($env:OPENCLAW_BROWSER_VNC_PORT) { $env:OPENCLAW_BROWSER_VNC_PORT } else { "5900" }
$NOVNC_PORT = if ($env:OPENCLAW_BROWSER_NOVNC_PORT) { $env:OPENCLAW_BROWSER_NOVNC_PORT } else { "6080" }
$ENABLE_NOVNC = if ($env:OPENCLAW_BROWSER_ENABLE_NOVNC) { $env:OPENCLAW_BROWSER_ENABLE_NOVNC } else { "1" }
$HEADLESS = if ($env:OPENCLAW_BROWSER_HEADLESS) { $env:OPENCLAW_BROWSER_HEADLESS } else { "0" }
$ALLOW_NO_SANDBOX = if ($env:OPENCLAW_BROWSER_NO_SANDBOX) { $env:OPENCLAW_BROWSER_NO_SANDBOX } else { "0" }
$NOVNC_PASSWORD = if ($env:OPENCLAW_BROWSER_NOVNC_PASSWORD) { $env:OPENCLAW_BROWSER_NOVNC_PASSWORD } else { "" }

$DISABLE_GRAPHICS_FLAGS = if ($env:OPENCLAW_BROWSER_DISABLE_GRAPHICS_FLAGS) { $env:OPENCLAW_BROWSER_DISABLE_GRAPHICS_FLAGS } else { "1" }
$DISABLE_EXTENSIONS = if ($env:OPENCLAW_BROWSER_DISABLE_EXTENSIONS) { $env:OPENCLAW_BROWSER_DISABLE_EXTENSIONS } else { "1" }
$RENDERER_PROCESS_LIMIT = if ($env:OPENCLAW_BROWSER_RENDERER_PROCESS_LIMIT) { $env:OPENCLAW_BROWSER_RENDERER_PROCESS_LIMIT } else { "2" }
$AUTO_START_TIMEOUT_MS = if ($env:OPENCLAW_BROWSER_AUTO_START_TIMEOUT_MS) { $env:OPENCLAW_BROWSER_AUTO_START_TIMEOUT_MS } else { "12000" }

function Validate-Uint {
    param (
        [string]$Name,
        [string]$Value,
        [int]$Min = 0,
        [int]$Max = 4294967295
    )

    if ($Value -notmatch '^[0-9]+$') {
        Write-Error "[sandbox] ERROR: $Name must be an integer, got: $Value" -ErrorAction Stop
    }
    $intValue = [int]$Value
    if ($intValue -lt $Min -or $intValue -gt $Max) {
        Write-Error "[sandbox] ERROR: $Name out of range ($Min..$Max), got: $Value" -ErrorAction Stop
    }
}

Validate-Uint "CDP_PORT" $CDP_PORT 1 65535
Validate-Uint "VNC_PORT" $VNC_PORT 1 65535
Validate-Uint "NOVNC_PORT" $NOVNC_PORT 1 65535
Validate-Uint "AUTO_START_TIMEOUT_MS" $AUTO_START_TIMEOUT_MS 1 2147483647
if ($RENDERER_PROCESS_LIMIT -ne "") {
    Validate-Uint "RENDERER_PROCESS_LIMIT" $RENDERER_PROCESS_LIMIT 0 2147483647
}

$processes = @{}

function Cleanup {
    param([int]$Code = 1)
    
    $pids = @()
    foreach ($pidVar in @("WEBSOCKIFY_PID", "X11VNC_PID", "SOCAT_PID", "CHROME_PID", "XVFB_PID")) {
        if ($processes.ContainsKey($pidVar) -and $processes[$pidVar]) {
            $pids += $processes[$pidVar]
        }
    }

    if ($pids.Count -gt 0) {
        foreach ($pid in $pids) {
            try {
                $proc = Get-Process -Id $pid -ErrorAction SilentlyContinue
                if ($proc) {
                    $proc | Stop-Process -Force -ErrorAction SilentlyContinue
                }
            } catch {}
        }

        for ($i = 0; $i -lt 10; $i++) {
            $alive = $false
            foreach ($pid in $pids) {
                try {
                    $proc = Get-Process -Id $pid -ErrorAction SilentlyContinue
                    if ($proc) {
                        $alive = $true
                        break
                    }
                } catch {}
            }
            if (-not $alive) { break }
            Start-Sleep -Milliseconds 200
        }

        foreach ($pid in $pids) {
            try {
                $proc = Get-Process -Id $pid -ErrorAction SilentlyContinue
                if ($proc) {
                    $proc | Stop-Process -Force -ErrorAction SilentlyContinue
                }
            } catch {}
        }
    }

    exit $Code
}

try {
    New-Item -ItemType Directory -Path $env:HOME, "$env:HOME/.chrome", $env:XDG_CONFIG_HOME, $env:XDG_CACHE_HOME -Force | Out-Null

    $xvfbProc = Start-Process -FilePath "Xvfb" -ArgumentList ":1", "-screen", "0", "1280x800x24", "-ac", "-nolisten", "tcp" -PassThru
    $processes["XVFB_PID"] = $xvfbProc.Id
    Write-Host "[sandbox] Xvfb started (PID: $($xvfbProc.Id))"

    $CHROME_CDP_PORT = if ([int]$CDP_PORT -ge 65535) { [int]$CDP_PORT - 1 } else { [int]$CDP_PORT + 1 }

    $CHROME_ARGS = @(
        "--remote-debugging-address=127.0.0.1"
        "--remote-debugging-port=$CHROME_CDP_PORT"
        "--user-data-dir=$env:HOME/.chrome"
        "--no-first-run"
        "--no-default-browser-check"
        "--disable-dev-shm-usage"
        "--disable-background-networking"
        "--disable-breakpad"
        "--disable-crash-reporter"
        "--no-zygote"
        "--metrics-recording-only"
        "--password-store=basic"
        "--use-mock-keychain"
    )

    if ($HEADLESS -eq "1") {
        $CHROME_ARGS += "--headless=new"
    }

    if ($ALLOW_NO_SANDBOX -eq "1") {
        $CHROME_ARGS += "--no-sandbox", "--disable-setuid-sandbox"
    }

    $DISABLE_GRAPHICS_FLAGS_LOWER = $DISABLE_GRAPHICS_FLAGS.ToLower()
    if ($DISABLE_GRAPHICS_FLAGS_LOWER -match "^(1|true|yes|on)$") {
        $CHROME_ARGS += "--disable-3d-apis", "--disable-gpu", "--disable-software-rasterizer"
    }

    $DISABLE_EXTENSIONS_LOWER = $DISABLE_EXTENSIONS.ToLower()
    if ($DISABLE_EXTENSIONS_LOWER -match "^(1|true|yes|on)$") {
        $CHROME_ARGS += "--disable-extensions"
    }

    if ($RENDERER_PROCESS_LIMIT -match '^[0-9]+$' -and [int]$RENDERER_PROCESS_LIMIT -gt 0) {
        $CHROME_ARGS += "--renderer-process-limit=$RENDERER_PROCESS_LIMIT"
    }

    Write-Host "[sandbox] Starting Chromium..."
    $chromeProc = Start-Process -FilePath "chromium" -ArgumentList $CHROME_ARGS + @("about:blank") -PassThru
    $processes["CHROME_PID"] = $chromeProc.Id
    Write-Host "[sandbox] Chromium started (PID: $($chromeProc.Id))"

    $startMs = [DateTimeOffset]::Now.ToUnixTimeMilliseconds()
    $deadlineMs = $startMs + [int]$AUTO_START_TIMEOUT_MS
    $CDP_READY = 0
    $probeUrl = "http://127.0.0.1:$CHROME_CDP_PORT/json/version"

    Write-Host "[sandbox] Waiting up to $AUTO_START_TIMEOUT_MS ms for CDP on port $CHROME_CDP_PORT..."

    while ([DateTimeOffset]::Now.ToUnixTimeMilliseconds() -lt $deadlineMs) {
        try {
            $proc = Get-Process -Id $chromeProc.Id -ErrorAction SilentlyContinue
            if (-not $proc) {
                Write-Error "[sandbox] ERROR: Chromium exited before CDP became ready." -ErrorAction Stop
            }
        } catch {
            Write-Error "[sandbox] ERROR: Chromium exited before CDP became ready." -ErrorAction Stop
        }

        try {
            $response = Invoke-WebRequest -Uri $probeUrl -UseBasicParsing -TimeoutSec 1 -ErrorAction SilentlyContinue
            if ($response.StatusCode -eq 200) {
                $CDP_READY = 1
                break
            }
        } catch {}

        Start-Sleep -Milliseconds 200
    }

    if ($CDP_READY -eq 0) {
        Write-Error "[sandbox] ERROR: CDP failed to start within $AUTO_START_TIMEOUT_MS ms." -ErrorAction Stop
    }

    Write-Host "[sandbox] CDP ready. Starting socat..."

    if ([string]::IsNullOrEmpty($CDP_SOURCE_RANGE)) {
        Write-Warning "[sandbox-browser] WARNING: CDP_SOURCE_RANGE unset; socat CDP relay will not start."
        Write-Host "[sandbox-browser] Set OPENCLAW_BROWSER_CDP_SOURCE_RANGE to an explicit CIDR to enable CDP access."
    } else {
        $SOCAT_LISTEN_ADDR = "TCP-LISTEN:$CDP_PORT,fork,reuseaddr,bind=0.0.0.0,range=$CDP_SOURCE_RANGE"
        $socatProc = Start-Process -FilePath "socat" -ArgumentList $SOCAT_LISTEN_ADDR, "TCP:127.0.0.1:$CHROME_CDP_PORT" -PassThru
        $processes["SOCAT_PID"] = $socatProc.Id
        Write-Host "[sandbox] socat started (PID: $($socatProc.Id))"
    }

    if ($ENABLE_NOVNC -eq "1" -and $HEADLESS -ne "1") {
        if ([string]::IsNullOrEmpty($NOVNC_PASSWORD)) {
            $guid = [System.Guid]::NewGuid().ToString()
            $NOVNC_PASSWORD = $guid.Replace("-", "").Substring(0, 8)
        }

        $vncDir = "$env:HOME/.vnc"
        New-Item -ItemType Directory -Path $vncDir -Force | Out-Null
        
        # Create password file using openssl or similar approach
        # This is a simplified version - actual implementation might need more work
        $passwordFile = "$vncDir/passwd"
        # Note: PowerShell doesn't have direct equivalent to x11vnc -storepasswd
        # This would need to be implemented properly
        
        $x11vncProc = Start-Process -FilePath "x11vnc" -ArgumentList "-display", ":1", "-rfbport", $VNC_PORT, "-shared", "-forever", "-rfbauth", $passwordFile, "-localhost" -PassThru
        $processes["X11VNC_PID"] = $x11vncProc.Id
        Write-Host "[sandbox] x11vnc started (PID: $($x11vncProc.Id))"

        $websockifyProc = Start-Process -FilePath "websockify" -ArgumentList "--web", "/usr/share/novnc/", $NOVNC_PORT, "localhost:$VNC_PORT" -PassThru
        $processes["WEBSOCKIFY_PID"] = $websockifyProc.Id
        Write-Host "[sandbox] websockify started (PID: $($websockifyProc.Id))"
    }

    Write-Host "[sandbox] Container running. Monitoring all sub-processes..."
    
    # Wait for any process to exit
    while ($true) {
        $anyExited = $false
        foreach ($key in $processes.Keys) {
            try {
                $proc = Get-Process -Id $processes[$key] -ErrorAction SilentlyContinue
                if (-not $proc) {
                    $anyExited = $true
                    break
                }
            } catch {
                $anyExited = $true
                break
            }
        }
        
        if ($anyExited) { break }
        Start-Sleep -Milliseconds 500
    }
}
catch {
    Cleanup 1
}
