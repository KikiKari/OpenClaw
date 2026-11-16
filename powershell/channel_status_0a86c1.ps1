#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "526c01e171cee43da136898ce0fbf95f3c770e2f3959f91ea8aba3e7d53a6663", "source_sha256": "0a86c190e36a7131252f54b73542b2e9f42f2b23547cdb5530f47c8477226123", "target_language": "powershell"}
# channel_status.py — portiert nach powershell
# Quelle: python, workspace@local:skills/channel-status-agent/scripts/channel_status.py
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

<#
Channel Status Agent - Automatische Status-Updates
#>

# Konfiguration
$WORKSPACE = "/home/openclaw/.openclaw/workspace"
$LOGS_DB = "$WORKSPACE/db/logs.db"
$CONFIG_FILE = "$WORKSPACE/config/channel-status.json"
$LOG_FILE = "$WORKSPACE/logs/channel-status.log"

function Log {
    param(
        [string]$message,
        [string]$level = "INFO"
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $entry = "[$timestamp] [$level] $message"
    Write-Host $entry
    Add-Content -Path $LOG_FILE -Value $entry
}

$NODE_NAMES = @{
    "node2" = @("openclaw-node2", "arm64-node", "v2202604104722449961", "v2202604104722449961.taild25fea.ts.net", "100.82.198.122")
    "node3" = @("openclaw-node3", "openclaw-node3.taild25fea.ts.net", "100.73.154.125")
    "node4" = @("openclaw-node4", "redmi-note-11s", "redmi-note-11s.taild25fea.ts.net", "100.94.134.39")
    "node5" = @("openclaw-node5")
    "node6" = @("openclaw-node6")
}

function Fetch-NodeStatus {
    try {
        $result = & openclaw nodes status --json 2>$null
        $payload = $result | ConvertFrom-Json
        if ($null -eq $payload -or $payload.nodes -isnot [array]) {
            return $null
        }
        $states = @{}
        foreach ($node in $NODE_NAMES.Keys) {
            $states[$node] = $false
        }
        foreach ($item in $payload.nodes) {
            if ($item -isnot [pscustomobject]) {
                continue
            }
            $names = @($item.displayName, $item.nodeId, $item.remoteIp).ForEach({ ($_ | Out-String).Trim().ToLower() })
            foreach ($node in $NODE_NAMES.Keys) {
                $aliases = $NODE_NAMES[$node]
                $found = $false
                foreach ($alias in $aliases) {
                    if ($names -contains $alias) {
                        $found = $true
                        break
                    }
                }
                if ($found -and $item.connected -eq $true) {
                    $states[$node] = $true
                }
            }
        }
        $states["node1"] = $true  # successful Gateway status request
        return $states
    } catch {
        return $null
    }
}

function Get-SystemStatus {
    $status = @{
        timestamp = (Get-Date).ToString("o")
        nodes = @{}
        agents = @{}
        system = @{}
    }
    
    # Verbindungslage aus der Gateway-Statusliste; keine statischen Online-Werte.
    $states = Fetch-NodeStatus
    $names = @{
        "node1" = "Gateway"
        "node2" = "Node2"
        "node3" = "Node3"
        "node4" = "Redmi"
        "node5" = "Lenovo"
        "node6" = "Lenovo (Docker)"
    }
    foreach ($node in $names.Keys) {
        $name = $names[$node]
        if ($null -eq $states) {
            $status.nodes[$node] = @{ name = $name; status = "unknown" }
        } else {
            $status.nodes[$node] = @{ name = $name; status = if ($states[$node]) { "online" } else { "offline" } }
        }
    }

    # Agent-Status aus Cron
    try {
        $cronOutput = & crontab -l 2>$null
        $cronLines = ($cronOutput -split "`n" | Where-Object { $_ -notmatch "^#" -and $_.Trim() -ne "" }).Count
        $status.agents.active_crons = $cronLines
    } catch {
        $status.agents.active_crons = "unknown"
    }
    
    # System-Metriken
    try {
        # Disk usage
        $dfOutput = & df -h /
        foreach ($line in $dfOutput) {
            if ($line -like "*%*") {
                $parts = $line -split '\s+'
                $status.system.disk_used = $parts[4]
                break
            }
        }
        
        # RAM usage
        $freeOutput = & free -h
        foreach ($line in $freeOutput) {
            if ($line -like "Mem:*") {
                $parts = $line -split '\s+'
                $status.system.ram_total = $parts[1]
                $status.system.ram_used = $parts[2]
                break
            }
        }
    } catch {
        # Ignore errors
    }
    
    return $status
}

function Format-DailyStatus {
    param([hashtable]$status)
    
    $nodes = $status.nodes
    $online = ($nodes.Values | Where-Object { $_.status -eq "online" }).Count
    
    $message = "📊 **Täglicher Status-Report**`n"
    $message += "🗓️ $(Get-Date -Format 'yyyy-MM-dd HH:mm')`n`n"
    $message += "**🖥️ Nodes ($online/$($nodes.Count) online):**`n"
    
    foreach ($node_id in $nodes.Keys) {
        $info = $nodes[$node_id]
        $emoji = switch ($info.status) {
            "online" { "🟢" }
            "offline" { "🔴" }
            default { "🟡" }
        }
        $message += "$emoji $($info.name): $($info.status)`n"
        if ($info.ContainsKey("reason")) {
            $message += " ($($info.reason))`n"
        }
    }
    
    $message += "`n**🤖 Agents:**`n"
    $message += "Aktive Cron-Jobs: $($status.agents.active_crons)`n"
    
    if ($status.system.ContainsKey("disk_used")) {
        $message += "`n**💾 System:**`n"
        $message += "Disk: $($status.system.disk_used) belegt`n"
        $message += "RAM: $($status.system.ram_used) / $($status.system.ram_total)`n"
    }
    
    return $message
}

function Format-WeeklyStatus {
    param([hashtable]$status)
    
    $lines = @(
        "📈 **Wöchentlicher Report**"
        "📅 Woche $((Get-Date).ToString('yyyy'))-W$((Get-Culture).Calendar.GetWeekOfYear((Get-Date), [System.Globalization.CalendarWeekRule]::FirstFourDayWeek, [DayOfWeek]::Monday))"
        ""
        "**Nodes:**"
    )
    
    foreach ($item in $status.nodes.Values) {
        $lines += "- $($item.name): $($item.status)"
    }
    
    return ($lines -join "`n") + "`n"
}

function Send-ToChannel {
    param(
        [string]$message,
        [string]$channel_type = "telegram",
        [string]$channel_id = "-1002381931352"
    )
    
    if ($channel_type -eq "telegram") {
        # Nutze OpenClaw message tool
        $cmd = "openclaw", "message", "send", "--target", $channel_id, "--message", $message
    } else {
        Log "Channel type $channel_type not implemented" "WARN"
        return $false
    }
    
    try {
        $result = & $cmd 2>&1
        if ($LASTEXITCODE -eq 0) {
            Log "Message sent to $channel_type $channel_id"
            return $true
        } else {
            Log "Failed to send: $result" "ERROR"
            return $false
        }
    } catch {
        Log "Send error: $_" "ERROR"
        return $false
    }
}

function Main {
    param(
        [Parameter(Mandatory=$true)][ValidateSet("daily", "weekly", "alert")][string]$Type,
        [string]$Message,
        [string]$Channel = "-1002381931352",
        [switch]$DryRun
    )
    
    Log "Starting $Type status update"
    
    # Status sammeln
    $status = Get-SystemStatus
    
    # Message formatieren
    switch ($Type) {
        "daily" {
            $message = Format-DailyStatus $status
        }
        "weekly" {
            $message = Format-WeeklyStatus $status
        }
        "alert" {
            $message = "🚨 **ALERT**`n$(if ($Message) { $Message } else { 'Manual alert' })"
        }
    }
    
    # Senden oder Dry-Run
    if ($DryRun) {
        Write-Host "`n--- DRY RUN ---"
        Write-Host $message
        Write-Host "--- END ---"
    } else {
        Send-ToChannel $message -channel_id $Channel
    }
    
    Log "Status update completed"
}

# Ensure log directory exists
$logfileDir = Split-Path $LOG_FILE -Parent
if (!(Test-Path $logfileDir)) {
    New-Item -ItemType Directory -Path $logfileDir -Force | Out-Null
}

# Parse command line arguments
$params = @{}
for ($i = 0; $i -lt $args.Count; $i++) {
    switch ($args[$i]) {
        "--type" { 
            $i++
            $params.Type = $args[$i]
        }
        "--message" { 
            $i++
            $params.Message = $args[$i]
        }
        "--channel" { 
            $i++
            $params.Channel = $args[$i]
        }
        "--dry-run" { 
            $params.DryRun = $true
        }
    }
}

if (-not $params.ContainsKey("Type")) {
    Write-Host "Usage: channel_status.ps1 --type <daily|weekly|alert> [--message <msg>] [--channel <id>] [--dry-run]"
    exit 1
}

Main @params
