#!/usr/bin/env pwsh
# node_health.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway1:skills/node-health-monitor/scripts/node_health.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
Node Health Monitor - Multi-Node Gesundheitsüberwachung
#>

# Konfiguration
$WORKSPACE = "/home/openclaw/.openclaw/workspace"
$HEALTH_DB = "$WORKSPACE/db/health.db"
$LOG_FILE = "$WORKSPACE/logs/node-health.log"

# Node-Definitionen
$NODES = @{
    "node1" = @{
        "name" = "Gateway"
        "host" = "localhost"
        "user" = "openclaw"
        "critical" = $true
    }
    "node2" = @{
        "name" = "Worker"
        "host" = "100.92.155.34"
        "user" = "root"
        "ssh_key" = "~/.ssh/id_rsa"
    }
    "node3" = @{
        "name" = "Relay"
        "host" = "185.242.xxx.xxx"
        "user" = "root"
        "disk_warning" = 85
    }
    "node5" = @{
        "name" = "Redmi"
        "host" = "192.168.1.x"
        "user" = "openclaw"
        "optional" = $true
    }
}

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] [$Level] $Message"
    Write-Host $entry
    $logDir = Split-Path $LOG_FILE -Parent
    if (!(Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    Add-Content -Path $LOG_FILE -Value $entry
}

function Test-Ping {
    param([string]$Host, [int]$Timeout = 5)
    try {
        $result = Test-Connection -ComputerName $Host -Count 1 -TimeoutSeconds $Timeout -Quiet
        return $result
    } catch {
        return $false
    }
}

function Test-SSH {
    param($NodeConfig)
    $host = $NodeConfig["host"]
    $user = if ($NodeConfig.ContainsKey("user")) { $NodeConfig["user"] } else { "root" }
    
    $cmd = "ssh -o ConnectTimeout=10 -o BatchMode=yes ${user}@${host} echo 'OK'"
    try {
        $result = Invoke-Expression $cmd 2>$null
        return ($LASTEXITCODE -eq 0) -and ($result -match "OK")
    } catch {
        return $false
    }
}

function Get-NodeMetrics {
    param($NodeConfig)
    $host = $NodeConfig["host"]
    $user = if ($NodeConfig.ContainsKey("user")) { $NodeConfig["user"] } else { "root" }
    
    $metrics = @{
        "timestamp" = (Get-Date).ToString("o")
        "available" = $false
        "cpu" = $null
        "ram" = $null
        "disk" = $null
        "load" = $null
    }
    
    # SSH-Command für alle Metriken
    $cmd = @"
ssh -o ConnectTimeout=10 ${user}@${host} '
    # CPU
    echo "CPU:\$(top -bn1 | grep "Cpu(s)" | awk "{print \$2}" | cut -d"%" -f1)"
    
    # RAM
    echo "RAM:\$(free | grep Mem | awk "{print (\$3/\$2) * 100.0}")"
    
    # Disk
    echo "DISK:\$(df -h / | tail -1 | awk "{print \$5}" | tr -d "%")"
    
    # Load
    echo "LOAD:\$(uptime | awk -F"load average:" "{print \$2}" | awk "{print \$1}" | tr -d ",")"
    
    # Gateway Status
    if command -v openclaw >/dev/null 2>&1; then
        systemctl is-active openclaw-gateway 2>/dev/null || echo "GATEWAY:inactive"
    fi
'
"@
    
    try {
        $result = Invoke-Expression $cmd 2>$null
        $exitCode = $LASTEXITCODE
        
        if ($exitCode -eq 0) {
            $metrics["available"] = $true
            
            foreach ($line in $result) {
                if ($line -match ':') {
                    $parts = $line -split ':', 2
                    $key = $parts[0]
                    $value = $parts[1]
                    
                    switch ($key) {
                        "CPU" { 
                            if ([double]::TryParse($value, [ref]$null)) {
                                $metrics["cpu"] = [double]$value
                            }
                        }
                        "RAM" { 
                            if ([double]::TryParse($value, [ref]$null)) {
                                $metrics["ram"] = [double]$value
                            }
                        }
                        "DISK" { 
                            if ([int]::TryParse($value, [ref]$null)) {
                                $metrics["disk"] = [int]$value
                            }
                        }
                        "LOAD" { 
                            if ([double]::TryParse($value, [ref]$null)) {
                                $metrics["load"] = [double]$value
                            }
                        }
                        "GATEWAY" { 
                            $metrics["gateway_status"] = $value 
                        }
                    }
                }
            }
        }
    } catch {
        Write-Log "Error checking $($NodeConfig['name']): $_" "ERROR"
    }
    
    return $metrics
}

function Check-Alerts {
    param($NodeId, $NodeConfig, $Metrics)
    $alerts = @()
    
    # Verfügbarkeit
    if (-not $Metrics["available"]) {
        if (-not $NodeConfig.ContainsKey("optional") -or -not $NodeConfig["optional"]) {
            $alerts += @{
                "level" = "CRITICAL"
                "message" = "Node $($NodeConfig['name']) nicht erreichbar!"
            }
        }
    } else {
        # CPU
        if ($Metrics["cpu"] -and $Metrics["cpu"] -gt 90) {
            $alerts += @{
                "level" = "WARNING"
                "message" = "Node $($NodeConfig['name']): CPU bei $($Metrics['cpu'].ToString('F1'))%"
            }
        }
        
        # RAM
        if ($Metrics["ram"] -and $Metrics["ram"] -gt 90) {
            $alerts += @{
                "level" = "WARNING"
                "message" = "Node $($NodeConfig['name']): RAM bei $($Metrics['ram'].ToString('F1'))%"
            }
        }
        
        # Disk
        $disk_threshold = if ($NodeConfig.ContainsKey("disk_warning")) { $NodeConfig["disk_warning"] } else { 85 }
        if ($Metrics["disk"] -and $Metrics["disk"] -gt $disk_threshold) {
            $level = if ($Metrics["disk"] -gt 95) { "CRITICAL" } else { "WARNING" }
            $alerts += @{
                "level" = $level
                "message" = "Node $($NodeConfig['name']): Disk bei $($Metrics['disk'])%"
            }
        }
        
        # Gateway
        if ($NodeConfig.ContainsKey("critical") -and $NodeConfig["critical"] -and 
            $Metrics.ContainsKey("gateway_status") -and $Metrics["gateway_status"] -eq "inactive") {
            $alerts += @{
                "level" = "CRITICAL"
                "message" = "Node $($NodeConfig['name']): OpenClaw Gateway nicht aktiv!"
            }
        }
    }
    
    return $alerts
}

function Send-Alert {
    param($Alert)
    try {
        $scriptPath = "$WORKSPACE/skills/channel-status-agent/scripts/channel_status.py"
        $cmd = "python3 '$scriptPath' --type alert --message '$($Alert['level']): $($Alert['message'])'"
        Invoke-Expression $cmd 2>$null
        Write-Log "Alert sent: $($Alert['message'])"
    } catch {
        Write-Log "Failed to send alert: $_" "ERROR"
    }
}

function Main {
    param(
        [string]$Node = "all",
        [string]$Check = "all",
        [switch]$Alert
    )
    
    # Nodes bestimmen
    if ($Node -eq 'all') {
        $nodesToCheck = $NODES.GetEnumerator() | Sort-Object Name
    } else {
        if ($NODES.ContainsKey($Node)) {
            $nodesToCheck = @([System.Collections.DictionaryEntry]::new($Node, $NODES[$Node]))
        } else {
            Write-Log "Unknown node: $Node" "ERROR"
            exit 1
        }
    }
    
    # Health-Checks durchführen
    $allAlerts = @()
    
    foreach ($item in $nodesToCheck) {
        $nodeId = $item.Key
        $nodeConfig = $item.Value
        Write-Log "Checking $($nodeConfig['name']) ($nodeId)"
        
        # Ping
        if ($Check -in @('ping', 'all')) {
            if ($nodeConfig["host"] -ne "localhost") {
                $pingOk = Test-Ping $nodeConfig["host"]
                Write-Log "  Ping: $(if ($pingOk) { 'OK' } else { 'FAILED' })"
            }
        }
        
        # SSH
        if ($Check -in @('ssh', 'all')) {
            $sshOk = Test-SSH $nodeConfig
            Write-Log "  SSH: $(if ($sshOk) { 'OK' } else { 'FAILED' })"
        }
        
        # Metriken
        if ($Check -in @('metrics', 'all')) {
            $metrics = Get-NodeMetrics $nodeConfig
            
            if ($metrics["available"]) {
                Write-Log "  CPU: $(if ($metrics['cpu']) { '{0:F1}%' -f $metrics['cpu'] } else { 'N/A' })"
                Write-Log "  RAM: $(if ($metrics['ram']) { '{0:F1}%' -f $metrics['ram'] } else { 'N/A' })"
                Write-Log "  Disk: $(if ($metrics['disk']) { "$($metrics['disk'])%" } else { 'N/A' })"
                Write-Log "  Load: $(if ($metrics['load']) { $metrics['load'] } else { 'N/A' })"
            } else {
                Write-Log "  Metrics: UNAVAILABLE"
            }
            
            # Alerts prüfen
            $alerts = Check-Alerts $nodeId $nodeConfig $metrics
            $allAlerts += $alerts
        }
    }
    
    # Alerts senden
    if ($Alert -and $allAlerts.Count -gt 0) {
        Write-Log "`nSending $($allAlerts.Count) alerts..."
        foreach ($alert in $allAlerts) {
            Send-Alert $alert
        }
    } elseif ($allAlerts.Count -gt 0) {
        Write-Log "`n$($allAlerts.Count) alerts found (use --alert to send)"
    } else {
        Write-Log "`nAll nodes healthy!"
    }
}

# Parameter parsing
$node = "all"
$check = "all"
$alert = $false

for ($i = 0; $i -lt $args.Count; $i++) {
    switch ($args[$i]) {
        "--node" { 
            if ($i + 1 -lt $args.Count) { 
                $node = $args[$i + 1]
                $i++
            }
        }
        "--check" { 
            if ($i + 1 -lt $args.Count) { 
                $check = $args[$i + 1]
                $i++
            }
        }
        "--alert" { 
            $alert = $true
        }
    }
}

Main -Node $node -Check $check -Alert:$alert
