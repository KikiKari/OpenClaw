#!/usr/bin/env pwsh
# server-maintenance.sh — portiert nach powershell
# Quelle: shell, OpenClaw@gateway1:scripts/server-maintenance.sh
# auch in: OpenClaw@gateway2:scripts/server-maintenance.sh
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

# Server Maintenance Script
# RAM: 8GB, Uhr: Europe/Berlin

$LOG_FILE = "/var/log/server-maintenance.log"
$DATE = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$HOST = hostname

# Farben für Terminal
$RED = "`e[0;31m"
$GREEN = "`e[0;32m"
$YELLOW = "`e[1;33m"
$NC = "`e[0m"

function Write-Log {
    param([string]$Message)
    $logEntry = "[$DATE] $Message"
    Write-Output $logEntry
    Add-Content -Path $LOG_FILE -Value $logEntry
}

Write-Log "=== Server Maintenance Check ==="

# 1. APT Update Check
Write-Log "Checking for updates..."
try {
    apt update -qq 2>&1 | Select-Object -Last 5 | ForEach-Object { Write-Log $_ }
    $updatesOutput = apt list --upgradable 2>$null
    $UPDATES = if ($updatesOutput) { ($updatesOutput | Measure-Object).Count - 1 } else { 0 }
    if ($UPDATES -gt 1) {
        Write-Log "⚠️ $UPDATES packages can be upgraded"
    }
} catch {
    Write-Log "Error checking for updates: $_"
}

# 2. RAM Check (8GB total)
Write-Log "Checking RAM usage..."
$RAM_TOTAL = 8192  # 8GB in MB
try {
    $freeOutput = free -m | Where-Object { $_ -match "^Mem:" }
    if ($freeOutput) {
        $RAM_USED = [int]($freeOutput -split '\s+')[2]
        $RAM_PERCENT = [Math]::Floor(($RAM_USED * 100) / $RAM_TOTAL)
        Write-Log "RAM: ${RAM_USED}MB / ${RAM_TOTAL}MB (${RAM_PERCENT}%)"
        if ($RAM_PERCENT -gt 90) {
            Write-Log "🔴 WARNING: RAM usage > 90%!"
        } elseif ($RAM_PERCENT -gt 80) {
            Write-Log "🟡 WARNING: RAM usage > 80%"
        }
    } else {
        Write-Log "Could not determine RAM usage"
    }
} catch {
    Write-Log "Error checking RAM: $_"
}

# 3. Disk Space Check
Write-Log "Checking disk space..."
try {
    $diskInfo = df -h / | Select-Object -Last 1
    if ($diskInfo -match '(\d+\w+)\s+(\d+\w+)\s+(\d+%)\s+(\S+)') {
        $used = $matches[1]
        $total = $matches[2]
        $percent = $matches[3]
        Write-Log "Disk: $used / $total ($percent used)"
        
        $DISK_PERCENT = [int]($percent -replace '%', '')
        if ($DISK_PERCENT -gt 90) {
            Write-Log "🔴 WARNING: Disk > 90%!"
        } elseif ($DISK_PERCENT -gt 80) {
            Write-Log "🟡 WARNING: Disk > 80%"
        }
    }
} catch {
    Write-Log "Error checking disk space: $_"
}

# 4. NTP Check
Write-Log "Checking NTP sync..."
try {
    $ntpStatus = timedatectl status
    if ($ntpStatus -match "NTP synchronized: yes") {
        Write-Log "✅ NTP synchronized"
    } else {
        Write-Log "⚠️ NTP not synchronized"
    }
} catch {
    Write-Log "Error checking NTP: $_"
}

# 5. OpenClaw Gateway Status
Write-Log "Checking OpenClaw Gateway..."
try {
    $serviceStatus = systemctl is-active openclaw-gateway 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Log "✅ OpenClaw Gateway running"
    } else {
        Write-Log "🔴 OpenClaw Gateway NOT running!"
        systemctl restart openclaw-gateway
    }
} catch {
    Write-Log "Error checking OpenClaw Gateway: $_"
}

# 6. Load Average
try {
    $uptimeOutput = uptime
    if ($uptimeOutput -match "load average: ([\d\.]+)") {
        $LOAD = $matches[1]
        Write-Log "Load Average: $LOAD"
    }
} catch {
    Write-Log "Error getting load average: $_"
}

Write-Log "=== Maintenance Complete ==="
Write-Log ""
