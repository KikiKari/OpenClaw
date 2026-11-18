#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "7efda53cef6b946af53f5d3d754f9c1c7d853e6e37b6d1b0b3f59bb05b4a25c2", "source_sha256": "0ea45de4496e55f73aa9b10188cc6a04921d74e1cadbe0ac04a948d0f2772243", "target_language": "powershell"}
# node_health.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway2:skills/node-health-monitor/scripts/node_health.py
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

<#
Node Health Monitor - Multi-Node Gesundheitsüberwachung
#>

using namespace System.IO
using namespace System.Collections.Generic

# Konfiguration
$WORKSPACE = "/home/openclaw/.openclaw/workspace"
$HEALTH_DB = Join-Path $WORKSPACE "db/health.db"
$LOG_FILE = Join-Path $WORKSPACE "logs/node-health.log"

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
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $entry = "[$timestamp] [$Level] $Message"
    Write-Host $entry
    
    $logDir = Split-Path $LOG_FILE -Parent
    if (-not (Test-Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }
    
    Add-Content -Path $LOG_FILE -Value $entry
}

function Test-PingConnection {
    param(
        [string]$Host,
        [int]$Timeout = 10
    )
    
    try {
        $result = Test-Connection -ComputerName $Host -Count 1 -TimeoutSeconds $Timeout -Quiet
        return $result
    }
    catch {
        return $false
    }
}

function Test-SshConnection {
    param(
        [hashtable]$NodeConfig
    )
    
    $hostname = $NodeConfig["host"]
    $user = if ($NodeConfig.ContainsKey("user")) { $NodeConfig["user"] } else { "root" }
    $sshOpts = if ($NodeConfig.ContainsKey("ssh_opts")) { $NodeConfig["ssh_opts"] } else { "" }
    $port = if ($NodeConfig.ContainsKey("port")) { $NodeConfig["port"] } else { $null }
    
    $sshCommand = "ssh"
    if ($sshOpts) { $sshCommand += " $sshOpts" }
    if ($port) { $sshCommand += " -p $port" }
    $sshCommand += " -o ConnectTimeout=10 -o BatchMode=yes ${user}@${hostname} echo `"OK`""
    
    try {
        $result = Invoke-Expression $sshCommand 2>$null
        return ($LASTEXITCODE -eq 0) -and ($result -eq "OK")
    }
    catch {
        return $false
    }
}

function Get-NodeMetrics {
    param(
        [hashtable]$NodeConfig
    )
    
    $hostname = $NodeConfig["host"]
    $user = if ($NodeConfig.ContainsKey("user")) { $NodeConfig["user"] } else { "root" }
    
    $metrics = @{
        "timestamp" = (Get-Date -Format o)
        "available" = $false
        "cpu" = $null
        "ram" = $null
        "disk" = $null
        "load" = $null
    }
    
    $sshCommand = @"
ssh -o ConnectTimeout=10 ${user}@${hostname} '
    # CPU
    echo "CPU:\$(top -bn1 | grep "Cpu(s)" | awk "{print \\\$2}" | cut -d"%" -f1)"
    
    # RAM
    echo "RAM:\$(free | grep Mem | awk "{print (\\\$3/\\\$2) * 100.0}")"
    
    # Disk
    echo "DISK:\$(df -h / | tail -1 | awk "{print \\\$5}" | tr -d "%")"
    
    # Load
    echo "LOAD:\$(uptime | awk -F"load average:" "{print \\\$2}" | awk "{print \\\$1}" | tr -d ",")"
    
    # Gateway Status
    if command -v openclaw >/dev/null 2>&1; then
        systemctl is-active openclaw-gateway 2>/dev/null || echo "GATEWAY:inactive"
    fi
'
"@
    
    try {
        $result = Invoke-Expression $sshCommand -ErrorAction Stop
        $timeout = $false
    }
    catch {
        if ($_.Exception.Message -like "*timed out*") {
            Write-Log "SSH timeout for $($NodeConfig['name'])" "WARN"
            $timeout = $true
        }
        else {
            Write-Log "Error checking $($NodeConfig['name']): $($_.Exception.Message)" "ERROR"
            return $metrics
        }
    }
    
    if (-not $timeout -and $LASTEXITCODE -eq 0) {
        $metrics["available"] = $true
        
        $resultLines = $result -split "`n"
        foreach ($line in $resultLines) {
            if ($line -match ":") {
                $parts = $line -split ":", 2
                $key = $parts[0].Trim()
                $value = $parts[1].Trim()
                
                switch ($key) {
                    "CPU" { $metrics["cpu"] = [double]$value }
                    "RAM" { $metrics["ram"] = [double]$value }
                    "DISK" { $metrics["disk"] = [int]$value }
                    "LOAD" { $metrics["load"] = [double]$value }
                    "GATEWAY" { $metrics["gateway_status"] = $value }
                }
            }
        }
    }
    
    return $metrics
}

function Test-Alerts {
    param(
        [string]$NodeId,
        [hashtable]$NodeConfig,
        [hashtable]$Metrics
    )
    
    $alerts = [List[hashtable]]::new()
    
    # Verfügbarkeit
    if (-not $Metrics["available"]) {
        if (-not $NodeConfig.ContainsKey("optional") -or -not $NodeConfig["optional"]) {
            $alerts.Add(@{
                "level" = "CRITICAL"
                "message" = "Node $($NodeConfig['name']) nicht erreichbar!"
            })
        }
    }
    else {
        # CPU
        if ($Metrics["cpu"] -ne $null -and $Metrics["cpu"] -gt 90) {
            $alerts.Add(@{
                "level" = "WARNING"
                "message" = "Node $($NodeConfig['name']): CPU bei $($Metrics['cpu'].ToString('0.0'))%"
            })
        }
        
        # RAM
        if ($Metrics["ram"] -ne $null -and $Metrics["ram"] -gt 90) {
            $alerts.Add(@{
                "level" = "WARNING"
                "message" = "Node $($NodeConfig['name']): RAM bei $($Metrics['ram'].ToString('0.0'))%"
            })
        }
        
        # Disk
        $diskThreshold = if ($NodeConfig.ContainsKey("disk_warning")) { $NodeConfig["disk_warning"] } else { 85 }
        if ($Metrics["disk"] -ne $null -and $Metrics["disk"] -gt $diskThreshold) {
            $level = if ($Metrics["disk"] -gt 95) { "CRITICAL" } else { "WARNING" }
            $alerts.Add(@{
                "level" = $level
                "message" = "Node $($NodeConfig['name']): Disk bei $($Metrics['disk'])%"
            })
        }
        
        # Gateway
        if ($NodeConfig.ContainsKey("critical") -and $NodeConfig["critical"] -and 
            $Metrics.ContainsKey("gateway_status") -and $Metrics["gateway_status"] -eq "inactive") {
            $alerts.Add(@{
                "level" = "CRITICAL"
                "message" = "Node $($NodeConfig['name']): OpenClaw Gateway nicht aktiv!"
            })
        }
    }
    
    return $alerts
}

function Send-Alert {
    param(
        [hashtable]$Alert
    )
    
    try {
        $channelStatusScript = Join-Path $WORKSPACE "skills/channel-status-agent/scripts/channel_status.py"
        $arguments = @(
            "--type", "alert",
            "--message", "$($Alert['level']): $($Alert['message'])"
        )
        
        $process = Start-Process -FilePath "python3" -ArgumentList $arguments -WorkingDirectory (Split-Path $channelStatusScript) -Wait -PassThru -NoNewWindow
        if ($process.ExitCode -eq 0) {
            Write-Log "Alert sent: $($Alert['message'])"
        }
        else {
            Write-Log "Failed to send alert: Exit code $($process.ExitCode)" "ERROR"
        }
    }
    catch {
        Write-Log "Failed to send alert: $($_.Exception.Message)" "ERROR"
    }
}

function main {
    param(
        [string]$Node = "all",
        [ValidateSet("ping", "ssh", "metrics", "all")]
        [string]$Check = "all",
        [switch]$Alert
    )
    
    # Nodes bestimmen
    if ($Node -eq 'all') {
        $nodesToCheck = $NODES.GetEnumerator()
    }
    else {
        if ($NODES.ContainsKey($Node)) {
            $nodesToCheck = @(@{Name = $Node; Value = $NODES[$Node]})
        }
        else {
            Write-Log "Unknown node: $Node" "ERROR"
            exit 1
        }
    }
    
    # Health-Checks durchführen
    $allAlerts = [List[hashtable]]::new()
    
    foreach ($nodeEntry in $nodesToCheck) {
        $nodeId = $nodeEntry.Name
        $nodeConfig = $nodeEntry.Value
        
        Write-Log "Checking $($nodeConfig['name']) ($nodeId)"
        
        # Ping
        if ($Check -in @('ping', 'all')) {
            if ($nodeConfig["host"] -ne "localhost") {
                $pingOk = Test-PingConnection -Host $nodeConfig["host"]
                Write-Log "  Ping: $(if ($pingOk) {'OK'} else {'FAILED'})"
            }
        }
        
        # SSH
        if ($Check -in @('ssh', 'all')) {
            $sshOk = Test-SshConnection -NodeConfig $nodeConfig
            Write-Log "  SSH: $(if ($sshOk) {'OK'} else {'FAILED'})"
        }
        
        # Metriken
        if ($Check -in @('metrics', 'all')) {
            $metrics = Get-NodeMetrics -NodeConfig $nodeConfig
            
            if ($metrics["available"]) {
                if ($metrics["cpu"] -ne $null) { Write-Log "  CPU: $($metrics['cpu'].ToString('0.0'))%" } else { Write-Log "  CPU: N/A" }
                if ($metrics["ram"] -ne $null) { Write-Log "  RAM: $($metrics['ram'].ToString('0.0'))%" } else { Write-Log "  RAM: N/A" }
                if ($metrics["disk"] -ne $null) { Write-Log "  Disk: $($metrics['disk'])%" } else { Write-Log "  Disk: N/A" }
                if ($metrics["load"] -ne $null) { Write-Log "  Load: $($metrics['load'])" } else { Write-Log "  Load: N/A" }
            }
            else {
                Write-Log "  Metrics: UNAVAILABLE"
            }
            
            # Alerts prüfen
            $alerts = Test-Alerts -NodeId $nodeId -NodeConfig $nodeConfig -Metrics $metrics
            $allAlerts.AddRange($alerts)
        }
    }
    
    # Alerts senden
    if ($Alert -and $allAlerts.Count -gt 0) {
        Write-Log "`nSending $($allAlerts.Count) alerts..."
        foreach ($alert in $allAlerts) {
            Send-Alert -Alert $alert
        }
    }
    elseif ($allAlerts.Count -gt 0) {
        Write-Log "`n$($allAlerts.Count) alerts found (use -Alert to send)"
    }
    else {
        Write-Log "`nAll nodes healthy!"
    }
}

# Parameter verarbeiten und Hauptfunktion aufrufen
$paramArgs = $args
if ($paramArgs.Count -eq 0) {
    main
}
else {
    $node = "all"
    $check = "all"
    $alert = $false
    
    for ($i = 0; $i -lt $paramArgs.Count; $i++) {
        switch ($paramArgs[$i]) {
            "--node" {
                if ($i + 1 -lt $paramArgs.Count) {
                    $node = $paramArgs[$i + 1]
                    $i++
                }
            }
            "--check" {
                if ($i + 1 -lt $paramArgs.Count) {
                    $check = $paramArgs[$i + 1]
                    $i++
                }
            }
            "--alert" {
                $alert = $true
            }
        }
    }
    
    main -Node $node -Check $check -Alert:$alert
}
