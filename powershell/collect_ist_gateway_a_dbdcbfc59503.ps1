#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "b39cb03b2e122b6597ccc582208d2043f5f5275b8a724298d1cb763828cc1a69", "source_sha256": "47064dbc7b32c01d57d42222f8cc3ac7caf9c8d82b98029dc5fc6ecb0d32f2c9", "target_language": "powershell"}
# collect_ist_gateway_a.sh — portiert nach powershell
# Quelle: shell, OpenClaw@gateway1:scripts/collect_ist_gateway_a.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

$ErrorActionPreference = "Stop"

$BASE_DIR = "$env:USERPROFILE\.openclaw"
$OUT_DIR = "$BASE_DIR\workspace\vscode"
$NOW_UTC = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$NOW_LOCAL = Get-Date -Format "yyyy-MM-dd HH:mm:ss K"
$TS = Get-Date -Format "yyyyMMdd-HHmmss"

New-Item -ItemType Directory -Path $OUT_DIR -Force | Out-Null

$IST_FILE = "$OUT_DIR\IST-ZUSTAND_GATEWAY-A_NODE1.md"
$INV_FILE = "$OUT_DIR\ARTEFAKT-INVENTAR_GATEWAY-A_NODE1.md"
$CFG_FILE = "$OUT_DIR\OPENCLAW-CONFIG-SNAPSHOT_GATEWAY-A_NODE1.md"
$ENV_FILE = "$OUT_DIR\ENV-STATUS_GATEWAY-A_NODE1.md"
$RUN_FILE = "$OUT_DIR\RUN-$TS.md"

$OPENCLAW_JSON = "$BASE_DIR\openclaw.json"
$ENV_DOT = "$BASE_DIR\.env"
$ENV_SYSTEMD = "$BASE_DIR\gateway.systemd.env"
$VSCODE_DIR = "$BASE_DIR\.vscode"

try {
    $HOSTNAME_FQDN = [System.Net.Dns]::GetHostEntry($env:COMPUTERNAME).HostName
} catch {
    $HOSTNAME_FQDN = $env:COMPUTERNAME
}
$HOSTNAME_SHORT = $env:COMPUTERNAME
$ARCH = $env:PROCESSOR_ARCHITECTURE
$KERNEL = (Get-CimInstance Win32_OperatingSystem).Version
try {
    $OS_PRETTY = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").ProductName
} catch {
    $OS_PRETTY = ""
}
$IPV4_ALL = ((Get-NetIPAddress -AddressFamily IPv4).IPAddress -join " ").Trim()
try {
    $PUBLIC_IP = Invoke-RestMethod -Uri "http://ifconfig.me" -TimeoutSec 4 -ErrorAction Stop
} catch {
    $PUBLIC_IP = ""
}
try {
    $TAILSCALE_IP = (tailscale ip -4 2>$null | Select-Object -First 1)
} catch {
    $TAILSCALE_IP = ""
}
try {
    $OPENCLAW_VER = openclaw --version 2>$null
} catch {
    $OPENCLAW_VER = ""
}
try {
    $NODE_VER = node -v 2>$null
} catch {
    $NODE_VER = ""
}

if ([string]::IsNullOrWhiteSpace($PUBLIC_IP)) { $PUBLIC_IP = "(nicht ermittelt)" }
if ([string]::IsNullOrWhiteSpace($TAILSCALE_IP)) { $TAILSCALE_IP = "(nicht ermittelt)" }
if ([string]::IsNullOrWhiteSpace($OPENCLAW_VER)) { $OPENCLAW_VER = "(nicht ermittelt)" }
if ([string]::IsNullOrWhiteSpace($NODE_VER)) { $NODE_VER = "(nicht ermittelt)" }

@"
# IST-Zustand: Gateway A / Node 1

Stand (lokal): $NOW_LOCAL  
Stand (UTC): $NOW_UTC

## 1) Identitaet & System

- Gateway: **A**
- Node: **1**
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
"@ | Set-Content -Path $IST_FILE -Encoding UTF8

@"
# Artefakt-Inventar: Gateway A / Node 1

Stand: $NOW_LOCAL

## Top-Level in ~/.openclaw

```text
$(@(
    try {
        Get-ChildItem -Path $BASE_DIR -Name | ForEach-Object { $_ }
    } catch {
        ""
    }
) -join "`n")
```

## ~/.openclaw/.vscode

```text
$(@(
    if (Test-Path $VSCODE_DIR) {
        Get-ChildItem -Path $VSCODE_DIR | ForEach-Object { "{0,-10} {1,10} {2}" -f $_.Mode, $_.Length, $_.Name }
    } else {
        "(nicht vorhanden)"
    }
) -join "`n")
```

## plugin-skills/

```text
$(@(
    if (Test-Path "$BASE_DIR\plugin-skills") {
        try {
            Get-ChildItem -Path "$BASE_DIR\plugin-skills" -Name | ForEach-Object { $_ }
        } catch {
            ""
        }
    } else {
        "(nicht vorhanden)"
    }
) -join "`n")
```

## openclaw.json Backups

```text
$(@(
    try {
        Get-ChildItem -Path "$BASE_DIR\openclaw.json.bak*" -Name | ForEach-Object { $_ }
    } catch {
        "(keine gefunden)"
    }
) -join "`n")
```
"@ | Set-Content -Path $INV_FILE -Encoding UTF8

@"
# OpenClaw Config Snapshot: Gateway A / Node 1

Stand: $NOW_LOCAL

## Schluesselpositionen (grep)

```text
$(@(
    if (Test-Path $OPENCLAW_JSON) {
        try {
            $content = Get-Content -Path $OPENCLAW_JSON -Raw
            $lines = $content -split "`r?`n"
            for ($i = 0; $i -lt $lines.Count; $i++) {
                if ($lines[$i] -match '"gateway"|\"session\"|\"dmScope\"|\"auth\"|\"secrets\"|\"tools\"|\"plugins\"|\"profile\"|\"alsoAllow\"|\"denyCommands\"') {
                    "$($i + 1): $($lines[$i])"
                }
            }
        } catch {
            ""
        }
    } else {
        "openclaw.json fehlt"
    }
) -join "`n")
```

## Ausschnitt gateway/session/auth

```json
$(@(
    if (Test-Path $OPENCLAW_JSON) {
        try {
            $lines = Get-Content -Path $OPENCLAW_JSON
            $start = [Math]::Max(0, 579)
            $end = [Math]::Min($lines.Count - 1, 779)
            if ($start -le $end) {
                $lines[$start..$end] | ForEach-Object { $_ }
            }
        } catch {
            '{ "error": "Fehler beim Lesen" }'
        }
    } else {
        '{ "error": "openclaw.json fehlt" }'
    }
) -join "`n")
```
"@ | Set-Content -Path $CFG_FILE -Encoding UTF8

@"
# ENV-Status: Gateway A / Node 1

Stand: $NOW_LOCAL

## Dateien

```text
$(@(
    try {
        if (Test-Path $ENV_DOT) {
            $item = Get-Item $ENV_DOT
            "{0,-10} {1,10} {2}" -f $item.Mode, $item.Length, $item.Name
        }
        if (Test-Path $ENV_SYSTEMD) {
            $item = Get-Item $ENV_SYSTEMD
            "{0,-10} {1,10} {2}" -f $item.Mode, $item.Length, $item.Name
        }
    } catch {
        ""
    }
) -join "`n")
```

## .env (vollstaendig)

```dotenv
$(@(
    if (Test-Path $ENV_DOT) {
        Get-Content -Path $ENV_DOT
    } else {
        "# .env fehlt"
    }
) -join "`n")
```

## gateway.systemd.env (vollstaendig)

```dotenv
$(@(
    if (Test-Path $ENV_SYSTEMD) {
        Get-Content -Path $ENV_SYSTEMD
    } else {
        "# gateway.systemd.env fehlt"
    }
) -join "`n")
```
"@ | Set-Content -Path $ENV_FILE -Encoding UTF8

@"
# Laufprotokoll Gateway A / Node 1

- Zeit (lokal): $NOW_LOCAL
- Zeit (UTC): $NOW_UTC
- Script: $MyInvocation.MyCommand.Path

## Erzeugte Dateien

- $(Split-Path -Leaf $IST_FILE)
- $(Split-Path -Leaf $INV_FILE)
- $(Split-Path -Leaf $CFG_FILE)
- $(Split-Path -Leaf $ENV_FILE)
"@ | Set-Content -Path $RUN_FILE -Encoding UTF8

Write-Output "OK: IST-Zustand erfasst."
Get-ChildItem -Path $OUT_DIR -Name | ForEach-Object { "- $_" }
