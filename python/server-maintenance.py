#!/usr/bin/env python3
# server-maintenance.sh — portiert nach python
# Quelle: shell, OpenClaw@gateway1:scripts/server-maintenance.sh
# auch in: OpenClaw@gateway2:scripts/server-maintenance.sh
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

import subprocess
import datetime
import os
import sys

# Server Maintenance Script
# RAM: 8GB, Uhr: Europe/Berlin

LOG_FILE = "/var/log/server-maintenance.log"
DATE = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
HOST = os.uname()[1]

# Farben für Terminal
RED = '\033[0;31m'
GREEN = '\033[0;32m'
YELLOW = '\033[1;33m'
NC = '\033[0m'

def log_message(message):
    """Log message to file and print to console"""
    formatted_message = f"[{DATE}] {message}"
    print(formatted_message)
    with open(LOG_FILE, 'a') as f:
        f.write(formatted_message + '\n')

log_message("=== Server Maintenance Check ===")

# 1. APT Update Check
log_message("Checking for updates...")
try:
    result = subprocess.run(['apt', 'update', '-qq'], capture_output=True, text=True)
    lines = result.stdout.split('\n')[-6:-1]
    for line in lines:
        if line.strip():
            log_message(line.strip())
    
    result = subprocess.run(['apt', 'list', '--upgradable'], capture_output=True, text=True)
    updates = len(result.stdout.split('\n')) - 1
    if updates > 1:
        log_message(f"⚠️ {updates} packages can be upgraded")
except Exception as e:
    log_message(f"Error checking updates: {e}")

# 2. RAM Check (8GB total)
log_message("Checking RAM usage...")
RAM_TOTAL = 8192  # 8GB in MB
try:
    result = subprocess.run(['free', '-m'], capture_output=True, text=True)
    lines = result.stdout.split('\n')
    mem_line = [line for line in lines if line.startswith('Mem:')][0]
    parts = mem_line.split()
    RAM_USED = int(parts[2])
    RAM_PERCENT = (RAM_USED * 100) // RAM_TOTAL
    log_message(f"RAM: {RAM_USED}MB / {RAM_TOTAL}MB ({RAM_PERCENT}%)")
    if RAM_PERCENT > 90:
        log_message("🔴 WARNING: RAM usage > 90%!")
    elif RAM_PERCENT > 80:
        log_message("🟡 WARNING: RAM usage > 80%")
except Exception as e:
    log_message(f"Error checking RAM: {e}")

# 3. Disk Space Check
log_message("Checking disk space...")
try:
    result = subprocess.run(['df', '-h', '/'], capture_output=True, text=True)
    df_line = result.stdout.split('\n')[1]
    parts = df_line.split()
    disk_info = f"Disk: {parts[2]} / {parts[1]} ({parts[4]} used)"
    log_message(disk_info)
    
    result = subprocess.run(['df', '/'], capture_output=True, text=True)
    df_line = result.stdout.split('\n')[1]
    parts = df_line.split()
    DISK_PERCENT = int(parts[4].rstrip('%'))
    if DISK_PERCENT > 90:
        log_message("🔴 WARNING: Disk > 90%!")
    elif DISK_PERCENT > 80:
        log_message("🟡 WARNING: Disk > 80%")
except Exception as e:
    log_message(f"Error checking disk space: {e}")

# 4. NTP Check
log_message("Checking NTP sync...")
try:
    result = subprocess.run(['timedatectl', 'status'], capture_output=True, text=True)
    if "NTP synchronized: yes" in result.stdout:
        log_message("✅ NTP synchronized")
    else:
        log_message("⚠️ NTP not synchronized")
except Exception as e:
    log_message(f"Error checking NTP: {e}")

# 5. OpenClaw Gateway Status
log_message("Checking OpenClaw Gateway...")
try:
    result = subprocess.run(['systemctl', 'is-active', 'openclaw-gateway'], 
                          capture_output=True, text=True)
    if result.returncode == 0 and result.stdout.strip() == 'active':
        log_message("✅ OpenClaw Gateway running")
    else:
        log_message("🔴 OpenClaw Gateway NOT running!")
        subprocess.run(['systemctl', 'restart', 'openclaw-gateway'])
except Exception as e:
    log_message(f"Error checking OpenClaw Gateway: {e}")

# 6. Load Average
try:
    result = subprocess.run(['uptime'], capture_output=True, text=True)
    load_part = result.stdout.split('load average:')[1].strip()
    LOAD = load_part.split(',')[0].strip()
    log_message(f"Load Average: {LOAD}")
except Exception as e:
    log_message(f"Error checking load average: {e}")

log_message("=== Maintenance Complete ===")
log_message("")
