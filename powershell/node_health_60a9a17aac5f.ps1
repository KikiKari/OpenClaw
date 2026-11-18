#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "8bf4ff198a505142b9d1363b8aa690856a88853ab50be0a71d2e178415b3bc7b", "source_sha256": "8cb73cb9ea3a2ccee09205fcea5d8d2e1f29c369b21a3dfcf948b8029436a339", "target_language": "powershell"}
# node_health.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway1:skills/node-health-monitor/scripts/node_health.py
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
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    
    Add-Content -Path $LOG_FILE -Value $entry
}

function Test-PingConnection {
    param(
        [string]$Host,
        [int]$Timeout = 5
    )
    
    try {
        $ping = Test-Connection -ComputerName $Host -Count 1 -TimeoutSeconds $Timeout -Quiet
        return $ping
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
    $user = $NodeConfig["user"]
    if (-not $user) { $user = "root" }
    
    try {
        $result = ssh -o ConnectTimeout=10 -o BatchMode=yes "${user}@${hostname}" 'echo "OK"' 2>$null
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
    $user = $NodeConfig["user"]
    if (-not $user) { $user = "root" }
    
    $metrics = @{
        "timestamp" = (Get-Date).ToString("o")
        "available" = $false
        "cpu" = $null
        "ram" = $null
        "disk" = $null
        "load" = $null
    }
    
    $sshCommand = @"
        # CPU
        echo "CPU:`$(top -bn1 | grep 'Cpu(s)' | awk '{print `$2}' | cut -d'%' -f1)"
        
        # RAM
        echo "RAM:`$(free | grep Mem | awk '{print (`$3/`$2) * 100.0}')"
        
        # Disk
        echo "DISK:`$(df -h / | tail -1 | awk '{print `$5}' | tr -d '%')"
        
        # Load
        echo "LOAD:`$(uptime | awk -F'load average:' '{print `$2}' | awk '{print `$1}' | tr -d ',')"
        
        # Gateway Status
        if command -v openclaw >/dev/null 2>&1; then
            systemctl is-active openclaw-gateway 2>/dev/null || echo "GATEWAY:inactive"
        fi
"@
    
    try {
        $result = ssh -o ConnectTimeout=10 "${user}@${hostname}" $sshCommand 2>$null
        
        if ($LASTEXITCODE -eq 0) {
            $metrics["available"] = $true
            
            $resultLines = $result -split "`n"
            foreach ($line in $resultLines) {
                if ($line -match ':') {
                    $key, $value = $line -split ':', 2
                    $key = $key.Trim()
                    $value = $value.Trim()
                    
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
    }
    catch {
        Write-Log "SSH timeout for $($NodeConfig['name'])" "WARN"
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
        if (-not $NodeConfig["optional"]) {
            $alerts.Add(@{
                "level" = "CRITICAL"
                "message" = "Node $($NodeConfig['name']) nicht erreichbar!"
            })
        }
    }
    else {
        # CPU
        if ($Metrics["cpu"] -and $Metrics["cpu"] -gt 90) {
            $alerts.Add(@{
                "level" = "WARNING"
                "message" = "Node $($NodeConfig['name']): CPU bei $($Metrics['cpu'].ToString('0.0'))%"
            })
        }
        
        # RAM
        if ($Metrics["ram"] -and $Metrics["ram"] -gt 90) {
            $alerts.Add(@{
                "level" = "WARNING"
                "message" = "Node $($NodeConfig['name']): RAM bei $($Metrics['ram'].ToString('0.0'))%"
            })
        }
        
        # Disk
        $diskThreshold = $NodeConfig["disk_warning"]
        if (-not $diskThreshold) { $diskThreshold = 85 }
        
        if ($Metrics["disk"] -and $Metrics["disk"] -gt $diskThreshold) {
            $level = if ($Metrics["disk"] -gt 95) { "CRITICAL" } else { "WARNING" }
            $alerts.Add(@{
                "level" = $level
                "message" = "Node $($NodeConfig['name']): Disk bei $($Metrics['disk'])%"
            })
        }
        
        # Gateway
        if ($NodeConfig["critical"] -and $Metrics["gateway_status"] -eq "inactive") {
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
        $channelScript = Join-Path $WORKSPACE "skills/channel-status-agent/scripts/channel_status.py"
        $message = "$($Alert['level']): $($Alert['message'])"
        
        python3 $channelScript --type alert --message $message 2>$null
        Write-Log "Alert sent: $($Alert['message'])"
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
    $nodesToCheck = @{}
    if ($Node -eq 'all') {
        $nodesToCheck = $NODES
    }
    else {
        if ($NODES.ContainsKey($Node)) {
            $nodesToCheck[$Node] = $NODES[$Node]
        }
        else {
            Write-Log "Unknown node: $Node" "ERROR"
            exit 1
        }
    }
    
    # Health-Checks durchführen
    $allAlerts = [List[hashtable]]::new()
    
    foreach ($nodeId in $nodesToCheck.Keys) {
        $nodeConfig = $nodesToCheck[$nodeId]
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
                if ($metrics["cpu"]) { Write-Log "  CPU: $($metrics['cpu'].ToString('0.0'))%" }
                else { Write-Log "  CPU: N/A" }
                
                if ($metrics["ram"]) { Write-Log "  RAM: $($metrics['ram'].ToString('0.0'))%" }
                else { Write-Log "  RAM: N/A" }
                
                if ($metrics["disk"]) { Write-Log "  Disk: $($metrics['disk'])%" }
                else { Write-Log "  Disk: N/A" }
                
                if ($metrics["load"]) { Write-Log "  Load: $($metrics['load'])" }
                else { Write-Log "  Load: N/A" }
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
        Write-Log "`n$($allAlerts.Count) alerts found (use --Alert to send)"
    }
    else {
        Write-Log "`nAll nodes healthy!"
    }
}

# Argument parsing
$paramArgs = @{}
if ($args.Count -gt 0) {
    for ($i = 0; $i -lt $args.Count; $i++) {
        switch ($args[$i]) {
            "--node" {
                $paramArgs.Node = $args[$i + 1]
                $i++
            }
            "--check" {
                $paramArgs.Check = $args[$i + 1]
                $i++
            }
            "--alert" {
                $paramArgs.Alert = $true
            }
        }
    }
}

main @paramArgs
