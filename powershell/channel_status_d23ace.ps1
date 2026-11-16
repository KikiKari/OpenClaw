#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "1c25656f92515712e4383e37309aeaf11aef8331da2f1ab8cad8337c400ec1b9", "source_sha256": "d23aced948e2cbccfa5bfa57ad3b48adfc5d5f7a42c2fbdf665f8c185b8545eb", "target_language": "powershell"}
# channel_status.py — portiert nach powershell
# Quelle: python, workspace@local:git/skills/channel-status-agent/scripts/channel_status.py
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
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] [$level] $message"
    Write-Host $entry
    Add-Content -Path $LOG_FILE -Value $entry
}

$NODE_NAMES = @{
    "node2" = @("openclaw-node2", "arm64-node", "v2202604104722449961", "v2202604104722449961.taild25fea.ts.net", "100.82.198.122")
    "node3" = @("openclaw-node3", "openclaw-node3.taild25fea.ts.net", "100.73.154.125")
    "node4" = @("openclaw-node4", "redmi-note-11s", "redmi-note-11s.taild25fea.ts.net", "100.94.134.39")
    "node5" = @("openclaw-node5", "lenovo-node7", "lenovo-node7.taild25fea.ts.net", "100.103.140.35")
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
            if ($null -eq $item) { continue }
            $names = @($item.displayName, $item.nodeId, $item.remoteIp) | ForEach-Object { if ($_ -is [string]) { $_.ToLower() } else { "" } }
            $namesSet = $names | Where-Object { $_ -ne "" } | Sort-Object -Unique
            foreach ($node in $NODE_NAMES.Keys) {
                $aliases = $NODE_NAMES[$node]
                $found = $false
                foreach ($name in $namesSet) {
                    if ($aliases -contains $name) {
                        $found = $true
                        break
                    }
                }
                if ($found -and $item.connected -eq $true) {
                    $states[$node] = $true
                }
            }
        }
        $states["node1"] = $true
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

    $states = Fetch-NodeStatus
    $names = @{
        "node1" = "Gateway"
        "node2" = "Node2"
        "node3" = "Node3"
        "node4" = "Redmi"
        "node5" = "Lenovo"
    }

    foreach ($node in $names.Keys) {
        $nodeName = $names[$node]
        $nodeStatus = "unknown"
        if ($null -ne $states) {
            if ($states.ContainsKey($node) -and $states[$node]) {
                $nodeStatus = "online"
            } else {
                $nodeStatus = "offline"
            }
        }
        $status.nodes[$node] = @{
            name = $nodeName
            status = $nodeStatus
        }
    }

    try {
        $cronResult = & crontab -l 2>$null
        if ($LASTEXITCODE -eq 0) {
            $cronLines = ($cronResult -split "`n" | Where-Object { $_ -notmatch "^#" -and $_.Trim() -ne "" }).Count
            $status.agents.active_crons = $cronLines
        } else {
            $status.agents.active_crons = "unknown"
        }
    } catch {
        $status.agents.active_crons = "unknown"
    }

    try {
        $dfOutput = & df -h /
        foreach ($line in $dfOutput) {
            if ($line -match "/\s+.*%") {
                $parts = $line -split '\s+'
                $status.system.disk_used = $parts[4]
                break
            }
        }

        $freeOutput = & free -h
        foreach ($line in $freeOutput) {
            if ($line -match "Mem:") {
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
    $onlineCount = ($nodes.Values | Where-Object { $_.status -eq "online" }).Count
    
    $dateStr = Get-Date -Format "yyyy-MM-dd HH:mm"
    $message = "📊 **Täglicher Status-Report**`n🗓️ $dateStr`n`n**🖥️ Nodes ($onlineCount/$($nodes.Count) online):**`n"
    
    foreach ($nodeId in $nodes.Keys | Sort-Object) {
        $info = $nodes[$nodeId]
        switch ($info.status) {
            "online" { $emoji = "🟢" }
            "offline" { $emoji = "🔴" }
            default { $emoji = "🟡" }
        }
        $message += "$emoji $($info.name): $($info.status)"
        if ($info.ContainsKey("reason")) {
            $message += " ($($info.reason))"
        }
        $message += "`n"
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
    
    $weekNumber = Get-Date -UFormat "%V"
    $year = Get-Date -Format "yyyy"
    $lines = @(
        "📈 **Wöchentlicher Report**",
        "📅 Woche $weekNumber - $year",
        "",
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
        [string]$channelType = "telegram",
        [string]$channelId = "-1002381931352"
    )
    
    if ($channelType -eq "telegram") {
        $cmd = @("openclaw", "message", "send", "--target", $channelId, "--message", $message)
    } else {
        Log "Channel type $channelType not implemented" "WARN"
        return $false
    }
    
    try {
        $result = & $cmd[0] $cmd[1..($cmd.Length-1)] 2>&1
        if ($LASTEXITCODE -eq 0) {
            Log "Message sent to $channelType $channelId"
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
        [string]$type,
        [string]$message,
        [string]$channel = "-1002381931352",
        [switch]$dryRun
    )
    
    Log "Starting $type status update"
    
    $status = Get-SystemStatus
    
    switch ($type) {
        "daily" { $formattedMessage = Format-DailyStatus $status }
        "weekly" { $formattedMessage = Format-WeeklyStatus $status }
        "alert" { $formattedMessage = "🚨 **ALERT**`n$(if ($message) { $message } else { 'Manual alert' })" }
        default { throw "Invalid type: $type" }
    }
    
    if ($dryRun) {
        Write-Host "`n--- DRY RUN ---"
        Write-Host $formattedMessage
        Write-Host "--- END ---"
    } else {
        Send-ToChannel $formattedMessage -channelId $channel | Out-Null
    }
    
    Log "Status update completed"
}

# Parse command line arguments
$params = @{}
for ($i = 0; $i -lt $args.Count; $i++) {
    $arg = $args[$i]
    switch ($arg) {
        "--type" { 
            $i++
            $params.type = $args[$i]
        }
        "--message" {
            $i++
            $params.message = $args[$i]
        }
        "--channel" {
            $i++
            $params.channel = $args[$i]
        }
        "--dry-run" {
            $params.dryRun = $true
        }
    }
}

# Validate required parameter
if (-not $params.ContainsKey("type")) {
    Write-Error "Missing required parameter --type"
    exit 1
}

# Ensure log directory exists
$logfileDir = Split-Path $LOG_FILE -Parent
if (-not (Test-Path $logfileDir)) {
    New-Item -ItemType Directory -Path $logfileDir | Out-Null
}

# Run main function
Main @params
