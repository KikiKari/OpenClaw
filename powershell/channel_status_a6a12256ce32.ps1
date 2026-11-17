#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "26b8f284121d9a59e9ab22c62f94b53b659e58270346033a5300b267b372534f", "source_sha256": "705cb2cc5900c507db1038d107f06e2f8452a95c37d0611cd27dfe2ed61dd498", "target_language": "powershell"}
# channel_status.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway1:skills/channel-status-agent/scripts/channel_status.py
# auch in: OpenClaw@gateway2:skills/channel-status-agent/scripts/channel_status.py
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

<#
Channel Status Agent - Automatische Status-Updates
#>

# Konfiguration
$WORKSPACE = [System.IO.Path]::Combine($env:HOME, ".openclaw", "workspace")
$LOGS_DB = [System.IO.Path]::Combine($WORKSPACE, "db", "logs.db")
$CONFIG_FILE = [System.IO.Path]::Combine($WORKSPACE, "config", "channel-status.json")
$LOG_FILE = [System.IO.Path]::Combine($WORKSPACE, "logs", "channel-status.log")

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

function Get-SystemStatus {
    $status = @{
        timestamp = (Get-Date).ToString('o')
        nodes = @{}
        agents = @{}
        system = @{}
    }
    
    # Node-Status (vereinfacht)
    $nodes = @{
        node1 = @{name = "Gateway"; status = "online"}
        node2 = @{name = "Worker"; status = "online"}
        node3 = @{name = "Relay"; status = "offline"; reason = "disk full"}
        node5 = @{name = "Redmi"; status = "intermittent"}
        node7 = @{name = "Docker"; status = "planned"}
    }
    $status.nodes = $nodes
    
    # Agent-Status aus Cron
    try {
        $cronResult = crontab -l 2>$null
        $cronLines = ($cronResult | Where-Object { $_ -notmatch '^#' } | Measure-Object).Count
        $status.agents.active_crons = $cronLines
    } catch {
        $status.agents.active_crons = "unknown"
    }
    
    # System-Metriken
    try {
        # Disk usage
        $dfOutput = df -h /
        foreach ($line in $dfOutput) {
            if ($line -like "*%*" -and $line -like "*/*") {
                $parts = $line -split '\s+'
                $status.system.disk_used = $parts[4]
                break
            }
        }
        
        # RAM usage
        $freeOutput = free -h
        foreach ($line in $freeOutput) {
            if ($line -like "Mem:*") {
                $parts = $line -split '\s+'
                $status.system.ram_total = $parts[1]
                $status.system.ram_used = $parts[2]
                break
            }
        }
    } catch {
        # Ignoriere Fehler
    }
    
    return $status
}

function Format-DailyStatus {
    param([hashtable]$status)
    
    $nodes = $status.nodes
    $onlineCount = ($nodes.Values | Where-Object { $_.status -eq "online" } | Measure-Object).Count
    
    $message = "📊 **Täglicher Status-Report**`n"
    $message += "🗓️ $(Get-Date -Format 'yyyy-MM-dd HH:mm')`n`n"
    $message += "**🖥️ Nodes ($onlineCount/5 online):**`n"
    
    foreach ($nodeId in $nodes.Keys) {
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
    
    $message = "📈 **Wöchentlicher Report**`n"
    $message += "📅 Woche $(Get-Date -UFormat '%V') - $(Get-Date -Format 'yyyy')`n`n"
    $message += "**Zusammenfassung:**`n"
    $message += "- 5 aktive Sub-Agents`n"
    $message += "- 11 Skills synchronisiert`n"
    $message += "- 3 neue Features implementiert`n`n"
    $message += "**Top-Ereignisse:**`n"
    $message += "1. ClawHub-Git Sync implementiert ✅`n"
    $message += "2. Node 3 Disk voll (95%) ⚠️`n"
    $message += "3. Channel-Status-Agent aktiviert 🆕`n`n"
    $message += "**Geplante Wartungen:**`n"
    $message += "- Node 3: Disk-Cleanup erforderlich`n"
    $message += "- Node 7: Docker-Setup ausstehend`n"
    
    return $message
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
        "daily" { $message = Format-DailyStatus $status }
        "weekly" { $message = Format-WeeklyStatus $status }
        "alert" { 
            if (-not $Message) { $Message = "Manual alert" }
            $message = "🚨 **ALERT**`n$Message"
        }
    }
    
    # Senden oder Dry-Run
    if ($DryRun) {
        Write-Host "`n--- DRY RUN ---"
        Write-Host $message
        Write-Host "--- END ---"
    } else {
        Send-ToChannel -message $message -channelId $Channel | Out-Null
    }
    
    Log "Status update completed"
}

# Hauptprogramm
if ($MyInvocation.InvocationName -eq '&' -or $MyInvocation.InvocationName -eq $PSCommandPath) {
    # Erstelle Logs-Verzeichnis falls nicht vorhanden
    $logDir = Split-Path $LOG_FILE -Parent
    if (!(Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    
    # Parameter parsen
    $paramType = ""
    $paramMessage = $null
    $paramChannel = "-1002381931352"
    $paramDryRun = $false
    
    for ($i = 0; $i -lt $args.Count; $i++) {
        switch ($args[$i]) {
            "--type" { 
                $i++
                $paramType = $args[$i]
            }
            "--message" { 
                $i++
                $paramMessage = $args[$i]
            }
            "--channel" { 
                $i++
                $paramChannel = $args[$i]
            }
            "--dry-run" { 
                $paramDryRun = $true
            }
        }
    }
    
    if (-not $paramType) {
        Write-Host "Usage: channel_status.ps1 --type <daily|weekly|alert> [--message <text>] [--channel <id>] [--dry-run]"
        exit 1
    }
    
    Main -Type $paramType -Message $paramMessage -Channel $paramChannel -DryRun:$paramDryRun
}
