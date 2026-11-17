#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "9e2c72ead5d814a0b1e8dc6c2fa2860f72336ff9409a0989860a636baeec0ebd", "source_sha256": "da890cc26fb848b78b6a85373d6cfa4e08f6e7c2002921e1c0247960b8b361d7", "target_language": "powershell"}
# collect_ist_gateway_b.sh — portiert nach powershell
# Quelle: shell, OpenClaw@gateway2:scripts/collect_ist_gateway_b.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

$ErrorActionPreference = "Stop"

$BASE_DIR = "$env:USERPROFILE\.openclaw"
$OUT_DIR = "$BASE_DIR\workspace\vscode"
$NOW_UTC = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$NOW_LOCAL = Get-Date
$TS = Get-Date -Format "yyyyMMdd-HHmmss"

New-Item -ItemType Directory -Path $OUT_DIR -Force | Out-Null

$IST_FILE = "$OUT_DIR\IST-ZUSTAND_GATEWAY-B_NODE7.md"
$INV_FILE = "$OUT_DIR\ARTEFAKT-INVENTAR_GATEWAY-B_NODE7.md"
$CFG_FILE = "$OUT_DIR\OPENCLAW-CONFIG-SNAPSHOT_GATEWAY-B_NODE7.md"
$ENV_FILE = "$OUT_DIR\ENV-STATUS_GATEWAY-B_NODE7.md"
$RUN_FILE = "$OUT_DIR\RUN-$TS.md"

$OPENCLAW_JSON = "$BASE_DIR\openclaw.json"
$ENV_DOT = "$BASE_DIR\.env"
$ENV_SYSTEMD = "$BASE_DIR\gateway.systemd.env"
$VSCODE_DIR = "$BASE_DIR\.vscode"

try {
    $HOSTNAME_FQDN = [System.Net.Dns]::GetHostEntryAsync($env:COMPUTERNAME).Result.HostName
} catch {
    $HOSTNAME_FQDN = $env:COMPUTERNAME
}
$HOSTNAME_SHORT = $env:COMPUTERNAME
$ARCH = $env:PROCESSOR_ARCHITECTURE
$KERNEL = [System.Environment]::OSVersion.VersionString
try {
    $OS_PRETTY = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").ProductName
} catch {
    $OS_PRETTY = ""
}
$IPV4_ALL = ((Test-Connection -ComputerName $env:COMPUTERNAME -Count 1).IPv4Address | ForEach-Object { $_.IPAddressToString }) -join " "
try {
    $PUBLIC_IP = (Invoke-RestMethod -Uri "http://ifconfig.me" -TimeoutSec 4)
} catch {
    $PUBLIC_IP = "(nicht ermittelt)"
}
try {
    $TAILSCALE_IP = (tailscale ip -4) | Select-Object -First 1
} catch {
    $TAILSCALE_IP = "(nicht ermittelt)"
}
try {
    $OPENCLAW_VER = openclaw --version 2>$null
} catch {
    $OPENCLAW_VER = "(nicht ermittelt)"
}
try {
    $NODE_VER = node -v 2>$null
} catch {
    $NODE_VER = "(nicht ermittelt)"
}

if ([string]::IsNullOrEmpty($PUBLIC_IP)) {
    $PUBLIC_IP = "(nicht ermittelt)"
}
if ([string]::IsNullOrEmpty($TAILSCALE_IP)) {
    $TAILSCALE_IP = "(nicht ermittelt)"
}
if ([string]::IsNullOrEmpty($OPENCLAW_VER)) {
    $OPENCLAW_VER = "(nicht ermittelt)"
}
if ([string]::IsNullOrEmpty($NODE_VER)) {
    $NODE_VER = "(nicht ermittelt)"
}

@"
# IST-Zustand: Gateway B / Node 7

Stand (lokal): $NOW_LOCAL  
Stand (UTC): $NOW_UTC

## 1) Identität & System

- Gateway: **B**
- Node: **7**
- Hostname (short): `$HOSTNAME_SHORT`
- Hostname (FQDN): `$HOSTNAME_FQDN`
- Architektur: `$ARCH`
- Kernel: `$KERNEL`
- OS: `$OS_PRETTY`
- IPv4 (lokal): `$IPV4_ALL`
- Public IPv4: `$PUBLIC_IP`
- Tailscale IPv4: `$TAILSCALE_IP`
- OpenClaw Version: `$OPENCLAW_VER`
- Node.js Version: `$NODE_VER`

## 2) Arbeitsverzeichnisse

- Basis: `$BASE_DIR`
- Funktionell VSCode: `$VSCODE_DIR`
- Workspace Doku: `$OUT_DIR`

## 3) Kernartefakte (Existenz)

- `$OPENCLAW_JSON`: $(if (Test-Path $OPENCLAW_JSON) { "vorhanden" } else { "fehlt" })
- `$ENV_DOT`: $(if (Test-Path $ENV_DOT) { "vorhanden" } else { "fehlt" })
- `$ENV_SYSTEMD`: $(if (Test-Path $ENV_SYSTEMD) { "vorhanden" } else { "fehlt" })
- `$BASE_DIR\plugins\installs.json`: $(if (Test-Path "$BASE_DIR\plugins\installs.json") { "vorhanden" } else { "fehlt" })
- `$BASE_DIR\plugin-skills`: $(if (Test-Path "$BASE_DIR\plugin-skills") { "vorhanden" } else { "fehlt" })

## 4) Hinweis

Diese Datei wird bei jedem Lauf neu geschrieben.
Zusätzlich wird ein Laufprotokoll als `RUN-*.md` erzeugt.
"@ | Set-Content -Path $IST_FILE -Encoding UTF8

# Artefakt-Inventar
@"
# Artefakt-Inventar: Gateway B / Node 7

Stand: $NOW_LOCAL

## Top-Level in ~/.openclaw

```text
$(@(
    Get-ChildItem -Path $BASE_DIR -ErrorAction SilentlyContinue | ForEach-Object { $_.Name }
) -join "`n")
```

## ~/.openclaw/.vscode

```text
$(@(
    if (Test-Path $VSCODE_DIR) {
        Get-ChildItem -Path $VSCODE_DIR -Force | ForEach-Object {
            if ($_.PSIsContainer) {
                "d----- $($_.LastWriteTime) $($_.Name)/"
            } else {
                "-a---- $($_.LastWriteTime) $($_.Name)"
            }
        }
    } else {
        "(nicht vorhanden)"
    }
) -join "`n")
```

## plugin-skills/

```text
$(@(
    if (Test-Path "$BASE_DIR\plugin-skills") {
        Get-ChildItem -Path "$BASE_DIR\plugin-skills" -Name
    } else {
        "(nicht vorhanden)"
    }
) -join "`n")
```

## openclaw.json Backups

```text
$(@(
    Get-ChildItem -Path $BASE_DIR -Filter "openclaw.json.bak*" -ErrorAction SilentlyContinue | ForEach-Object { $_.Name }
) -join "`n")
$(if ((Get-ChildItem -Path $BASE_DIR -Filter "openclaw.json.bak*" -ErrorAction SilentlyContinue).Count -eq 0) { "(keine gefunden)" })
```
"@ | Set-Content -Path $INV_FILE -Encoding UTF8

# OpenClaw Config Snapshot
@"
# OpenClaw Config Snapshot: Gateway B / Node 7

Stand: $NOW_LOCAL

## Schlüsselpositionen (grep)

```text
$(@(
    if (Test-Path $OPENCLAW_JSON) {
        $content = Get-Content $OPENCLAW_JSON -Raw
        $pattern = '"gateway"|\"session\"|\"dmScope\"|\"auth\"|\"secrets\"|\"tools\"|\"plugins\"|\"profile\"|\"alsoAllow\"|\"denyCommands\"'
        $lines = $content -split "`n"
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match $pattern) {
                "$($i + 1): $($lines[$i].Trim())"
            }
        }
    } else {
        "openclaw.json fehlt"
    }
) -join "`n")
```

## Ausschnitt gateway/session/auth (ungefiltert, betriebsnah)

```json
$(@(
    if (Test-Path $OPENCLAW_JSON) {
        $lines = Get-Content $OPENCLAW_JSON
        $start = 579
        $end = 779
        if ($lines.Count -ge $start) {
            if ($lines.Count -lt $end) {
                $end = $lines.Count
            }
            $lines[$start..$end]
        }
    } else {
        "{ ""error"": ""openclaw.json fehlt"" }"
    }
) -join "`n")
```
"@ | Set-Content -Path $CFG_FILE -Encoding UTF8

# ENV-Status
@"
# ENV-Status: Gateway B / Node 7

Stand: $NOW_LOCAL

## Dateien

```text
$(@(
    Get-ChildItem -Path $ENV_DOT, $ENV_SYSTEMD -ErrorAction SilentlyContinue | ForEach-Object {
        "$($_.LastWriteTime) $($_.Length) $($_.Name)"
    }
) -join "`n")
```

## .env (vollständig, ungefiltert)

```dotenv
$(@(
    if (Test-Path $ENV_DOT) {
        Get-Content $ENV_DOT
    } else {
        "# .env fehlt"
    }
) -join "`n")
```

## gateway.systemd.env (vollständig, ungefiltert)

```dotenv
$(@(
    if (Test-Path $ENV_SYSTEMD) {
        Get-Content $ENV_SYSTEMD
    } else {
        "# gateway.systemd.env fehlt"
    }
) -join "`n")
```
"@ | Set-Content -Path $ENV_FILE -Encoding UTF8

# Laufprotokoll
@"
# Laufprotokoll Gateway B / Node 7

- Zeit (lokal): $NOW_LOCAL
- Zeit (UTC): $NOW_UTC
- Script: $((Get-Item $MyInvocation.MyCommand.Path).FullName)

## Erzeugte Dateien

- $(Split-Path $IST_FILE -Leaf)
- $(Split-Path $INV_FILE -Leaf)
- $(Split-Path $CFG_FILE -Leaf)
- $(Split-Path $ENV_FILE -Leaf)
"@ | Set-Content -Path $RUN_FILE -Encoding UTF8

Write-Host "OK: IST-Zustand erfasst."
Write-Host "Ausgabeordner: $OUT_DIR"
Write-Host "Dateien:"
Get-ChildItem -Path $OUT_DIR -Name | ForEach-Object { Write-Host "- $_" }
