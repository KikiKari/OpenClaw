#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "fbd7cb46fec498f6a27a5d96a27b57765f90aeb9bc9d7e3c246dd98ecaebdbed", "source_sha256": "38390e5c16266050829f3193f79ca05d8ec898095dc834f407431d87ecfadeb8", "target_language": "powershell"}
# server-maintenance.sh — portiert nach powershell
# Quelle: shell, OpenClaw@gateway1:scripts/server-maintenance.sh
# auch in: OpenClaw@gateway2:scripts/server-maintenance.sh
# Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

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
    "$DATE $Message" | Tee-Object -FilePath $LOG_FILE -Append
}

Write-Log "=== Server Maintenance Check ==="

# 1. APT Update Check
Write-Log "Checking for updates..."
try {
    apt update -qq 2>&1 | Select-Object -Last 5 | Tee-Object -FilePath $LOG_FILE -Append
    $UPDATES = (apt list --upgradable 2>/dev/null | Measure-Object).Count
    if ($UPDATES -gt 1) {
        Write-Log "⚠️ $UPDATES packages can be upgraded"
    }
} catch {}

# 2. RAM Check (8GB total)
Write-Log "Checking RAM usage..."
$RAM_TOTAL = 8192  # 8GB in MB
$RAM_USED = (Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1024 -as [int]
$RAM_PERCENT = [Math]::Round(($RAM_USED * 100) / $RAM_TOTAL)
Write-Log "RAM: $RAM_USED MB / $RAM_TOTAL MB ($RAM_PERCENT%)"
if ($RAM_PERCENT -gt 90) {
    Write-Log "🔴 WARNING: RAM usage > 90%!"
} elseif ($RAM_PERCENT -gt 80) {
    Write-Log "🟡 WARNING: RAM usage > 80%"
}

# 3. Disk Space Check
Write-Log "Checking disk space..."
$disk = Get-PSDrive -Name "/"
$DISK_USED = $disk.Used / 1GB
$DISK_TOTAL = $disk.Total / 1GB
$DISK_PERCENT = [Math]::Round(($disk.Used / $disk.Total) * 100)
Write-Log "Disk: $DISK_USED GB / $DISK_TOTAL GB ($DISK_PERCENT% used)"
if ($DISK_PERCENT -gt 90) {
    Write-Log "🔴 WARNING: Disk > 90%!"
} elseif ($DISK_PERCENT -gt 80) {
    Write-Log "🟡 WARNING: Disk > 80%"
}

# 4. NTP Check
Write-Log "Checking NTP sync..."
$ntpStatus = timedatectl status
if ($ntpStatus -match "NTP synchronized: yes") {
    Write-Log "✅ NTP synchronized"
} else {
    Write-Log "⚠️ NTP not synchronized"
}

# 5. OpenClaw Gateway Status
Write-Log "Checking OpenClaw Gateway..."
try {
    $serviceStatus = systemctl is-active openclaw-gateway 2>$null
    if ($serviceStatus -eq "active") {
        Write-Log "✅ OpenClaw Gateway running"
    } else {
        Write-Log "🔴 OpenClaw Gateway NOT running!"
        systemctl restart openclaw-gateway
    }
} catch {
    Write-Log "🔴 OpenClaw Gateway NOT running!"
    try {
        systemctl restart openclaw-gateway
    } catch {}
}

# 6. Load Average
$LOAD = (uptime)[0].Split(":")[-1].Trim().Split(",")[0]
Write-Log "Load Average: $LOAD"

Write-Log "=== Maintenance Complete ==="
Write-Log ""
