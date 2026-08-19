#!/usr/bin/env pwsh
# node_health.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway2:skills/node-health-monitor/scripts/node_health.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

<#
Node Health Monitor - Multi-Node Gesundheitsüberwachung
#>

# Konfiguration
$WORKSPACE = "/home/openclaw/.openclaw/workspace"
$HEALTH_DB = "$WORKSPACE/db/health.db"
$LOG_FILE = "$WORKSPACE/logs/node-health.log"

# Node-Definitionen
$NODES = @{
    "node1" = @{
        "name" = "Node 1"
        "host" = "localhost"
        "user" = "openclaw"
        "critical" = $true
    }
    "node2" = @{
        "name" = "Node 2"
        "host" = "10.10.0.2"
        "user" = "root"
        "ssh_key" = "~/.ssh/id_rsa"
        "ssh_opts" = "-o ConnectTimeout=10 -o BatchMode=yes"
    }
    "node3" = @{
        "name" = "Node 3"
        "host" = "localhost"
        "user" = "root"
        "port" = 18794
        "ssh_opts" = "-p 18794 -o ConnectTimeout=10 -o BatchMode=yes"
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
    Write-Output $entry
    $logDir = Split-Path $LOG_FILE -Parent
    if (!(Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    Add-Content -Path $LOG_FILE -Value $entry
}

function Test-Ping {
    param(
        [string]$Host,
        [int]$Timeout = 10
    )
    try {
        if ($IsWindows) {
            $result = Test-Connection -ComputerName $Host -Count 1 -Quiet -TimeoutSeconds $Timeout
        } else {
            $result = Test-Connection -TargetName $Host -Count 1 -Quiet -TimeoutSeconds $Timeout
        }
        return $result
    } catch {
        return $false
    }
}

function Test-SSH {
    param(
        [hashtable]$NodeConfig
    )
    $host = $NodeConfig["host"]
    $user = if ($NodeConfig.ContainsKey("user")) { $NodeConfig["user"] } else { "root" }
    $sshOpts = if ($NodeConfig.ContainsKey("ssh_opts")) { $NodeConfig["ssh_opts"] } else { "" }
    $port = if ($NodeConfig.ContainsKey("port")) { $NodeConfig["port"] } else { $null }
    
    $cmd = @("ssh")
    if ($sshOpts) {
        $cmd += $sshOpts -split '\s+'
    }
    if ($port) {
        $cmd += @("-p", "$port")
    }
    $cmd += @("-o", "ConnectTimeout=10", "-o", "BatchMode=yes", "${user}@${host}", "echo", '"OK"')
    
    try {
        $result = & $cmd 2>$null
        return ($LASTEXITCODE -eq 0 -and ($result -join "" -match "OK"))
    } catch {
        return $false
    }
}

function Get-NodeMetrics {
    param(
        [hashtable]$NodeConfig
    )
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
        if ($LASTEXITCODE -eq 0) {
            $metrics["available"] = $true
            
            foreach ($line in $result) {
                if ($line -match ':') {
                    $parts = $line -split ':', 2
                    $key = $parts[0]
                    $value = $parts[1]
                    
                    switch ($key) {
                        "CPU" { 
                            if ($value -ne $null -and $value -ne "") { 
                                try { $metrics["cpu"] = [float]$value } catch {} 
                            } 
                        }
                        "RAM" { 
                            if ($value -ne $null -and $value -ne "") { 
                                try { $metrics["ram"] = [float]$value } catch {} 
                            } 
                        }
                        "DISK" { 
                            if ($value -ne $null -and $value -ne "") { 
                                try { $metrics["disk"] = [int]$value } catch {} 
                            } 
                        }
                        "LOAD" { 
                            if ($value -ne $null -and $value -ne "") { 
                                try { $metrics["load"] = [float]$value } catch {} 
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
    param(
        [string]$NodeId,
        [hashtable]$NodeConfig,
        [hashtable]$Metrics
    )
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
        if ($Metrics["cpu"] -ne $null -and $Metrics["cpu"] -gt 90) {
            $alerts += @{
                "level" = "WARNING"
                "message" = "Node $($NodeConfig['name']): CPU bei $($Metrics['cpu'].ToString('F1'))%"
            }
        }
        
        # RAM
        if ($Metrics["ram"] -ne $null -and $Metrics["ram"] -gt 90) {
            $alerts += @{
                "level" = "WARNING"
                "message" = "Node $($NodeConfig['name']): RAM bei $($Metrics['ram'].ToString('F1'))%"
            }
        }
        
        # Disk
        $diskThreshold = if ($NodeConfig.ContainsKey("disk_warning")) { $NodeConfig["disk_warning"] } else { 85 }
        if ($Metrics["disk"] -ne $null -and $Metrics["disk"] -gt $diskThreshold) {
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
    param(
        [hashtable]$Alert
    )
    try {
        $cmd = @(
            "python3"
            "$WORKSPACE/skills/channel-status-agent/scripts/channel_status.py"
            "--type"
            "alert"
            "--message"
            "$($Alert['level']): $($Alert['message'])"
        )
        & $cmd 2>$null | Out-Null
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
        $nodesToCheck = $NODES.GetEnumerator() | Sort-Object Key
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
        if ($Check -eq 'ping' -or $Check -eq 'all') {
            if ($nodeConfig["host"] -ne "localhost") {
                $pingOk = Test-Ping -Host $nodeConfig["host"]
                Write-Log "  Ping: $(if ($pingOk) { 'OK' } else { 'FAILED' })"
            }
        }
        
        # SSH
        if ($Check -eq 'ssh' -or $Check -eq 'all') {
            $sshOk = Test-SSH -NodeConfig $nodeConfig
            Write-Log "  SSH: $(if ($sshOk) { 'OK' } else { 'FAILED' })"
        }
        
        # Metriken
        if ($Check -eq 'metrics' -or $Check -eq 'all') {
            $metrics = Get-NodeMetrics -NodeConfig $nodeConfig
            
            if ($metrics["available"]) {
                Write-Log "  CPU: $(if ($metrics['cpu'] -ne $null) { $("{0:F1}%" -f $metrics['cpu']) } else { 'N/A' })"
                Write-Log "  RAM: $(if ($metrics['ram'] -ne $null) { $("{0:F1}%" -f $metrics['ram']) } else { 'N/A' })"
                Write-Log "  Disk: $(if ($metrics['disk'] -ne $null) { "$($metrics['disk'])%" } else { 'N/A' })"
                Write-Log "  Load: $(if ($metrics['load'] -ne $null) { $metrics['load'] } else { 'N/A' })"
            } else {
                Write-Log "  Metrics: UNAVAILABLE"
            }
            
            # Alerts prüfen
            $alerts = Check-Alerts -NodeId $nodeId -NodeConfig $nodeConfig -Metrics $metrics
            $allAlerts += $alerts
        }
    }
    
    # Alerts senden
    if ($Alert -and $allAlerts.Count -gt 0) {
        Write-Log "`nSending $($allAlerts.Count) alerts..."
        foreach ($alert in $allAlerts) {
            Send-Alert -Alert $alert
        }
    } elseif ($allAlerts.Count -gt 0) {
        Write-Log "`n$($allAlerts.Count) alerts found (use --alert to send)"
    } else {
        Write-Log "`nAll nodes healthy!"
    }
}

# Parameter parsing
$nodeParam = "all"
$checkParam = "all"
$alertSwitch = $false

for ($i = 0; $i -lt $args.Count; $i++) {
    switch ($args[$i]) {
        "--node" {
            if ($i + 1 -lt $args.Count) {
                $nodeParam = $args[$i + 1]
                $i++
            }
        }
        "--check" {
            if ($i + 1 -lt $args.Count) {
                $checkParam = $args[$i + 1]
                $i++
            }
        }
        "--alert" {
            $alertSwitch = $true
        }
    }
}

Main -Node $nodeParam -Check $checkParam -Alert:$alertSwitch
