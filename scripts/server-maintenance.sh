#!/bin/bash

# Server Maintenance Script
# RAM: 8GB, Uhr: Europe/Berlin

LOG_FILE="/var/log/server-maintenance.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')
HOST=$(hostname)

# Farben für Terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "[$DATE] === Server Maintenance Check ===" | tee -a "$LOG_FILE"

# 1. APT Update Check
echo "[$DATE] Checking for updates..." | tee -a "$LOG_FILE"
apt update -qq 2>&1 | tail -5 | tee -a "$LOG_FILE"
UPDATES=$(apt list --upgradable 2>/dev/null | wc -l)
if [ $UPDATES -gt 1 ]; then
    echo "[$DATE] ⚠️ $UPDATES packages can be upgraded" | tee -a "$LOG_FILE"
fi

# 2. RAM Check (8GB total)
echo "[$DATE] Checking RAM usage..." | tee -a "$LOG_FILE"
RAM_TOTAL=8192  # 8GB in MB
RAM_USED=$(free -m | awk '/^Mem:/{print $3}')
RAM_PERCENT=$((RAM_USED * 100 / RAM_TOTAL))
echo "[$DATE] RAM: ${RAM_USED}MB / ${RAM_TOTAL}MB (${RAM_PERCENT}%)" | tee -a "$LOG_FILE"
if [ $RAM_PERCENT -gt 90 ]; then
    echo "[$DATE] 🔴 WARNING: RAM usage > 90%!" | tee -a "$LOG_FILE"
elif [ $RAM_PERCENT -gt 80 ]; then
    echo "[$DATE] 🟡 WARNING: RAM usage > 80%" | tee -a "$LOG_FILE"
fi

# 3. Disk Space Check
echo "[$DATE] Checking disk space..." | tee -a "$LOG_FILE"
df -h / | tail -1 | awk '{print "Disk: " $3 " / " $2 " (" $5 " used)"}' | tee -a "$LOG_FILE"
DISK_PERCENT=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ $DISK_PERCENT -gt 90 ]; then
    echo "[$DATE] 🔴 WARNING: Disk > 90%!" | tee -a "$LOG_FILE"
elif [ $DISK_PERCENT -gt 80 ]; then
    echo "[$DATE] 🟡 WARNING: Disk > 80%" | tee -a "$LOG_FILE"
fi

# 4. NTP Check
echo "[$DATE] Checking NTP sync..." | tee -a "$LOG_FILE"
if timedatectl status | grep -q "NTP synchronized: yes"; then
    echo "[$DATE] ✅ NTP synchronized" | tee -a "$LOG_FILE"
else
    echo "[$DATE] ⚠️ NTP not synchronized" | tee -a "$LOG_FILE"
fi

# 5. OpenClaw Gateway Status
echo "[$DATE] Checking OpenClaw Gateway..." | tee -a "$LOG_FILE"
if systemctl is-active --quiet openclaw-gateway; then
    echo "[$DATE] ✅ OpenClaw Gateway running" | tee -a "$LOG_FILE"
else
    echo "[$DATE] 🔴 OpenClaw Gateway NOT running!" | tee -a "$LOG_FILE"
    systemctl restart openclaw-gateway
fi

# 6. Load Average
LOAD=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
echo "[$DATE] Load Average: $LOAD" | tee -a "$LOG_FILE"

echo "[$DATE] === Maintenance Complete ===" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
