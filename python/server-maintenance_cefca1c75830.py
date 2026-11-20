#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "feecdd322d77797a731d88ecbee9e33179127bf0307e932b56fc6816bc3ccf5b", "source_sha256": "38390e5c16266050829f3193f79ca05d8ec898095dc834f407431d87ecfadeb8", "target_language": "python"}
# server-maintenance.sh — portiert nach python
# Quelle: shell, OpenClaw@gateway1:scripts/server-maintenance.sh
# auch in: OpenClaw@gateway2:scripts/server-maintenance.sh
# Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

import subprocess
import logging
import os
from datetime import datetime

# Server Maintenance Script
# RAM: 8GB, Uhr: Europe/Berlin

LOG_FILE = "/var/log/server-maintenance.log"
DATE = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
HOST = os.uname()[1]

# Setup logging
logging.basicConfig(filename=LOG_FILE, level=logging.INFO, format='%(message)s')

def log_message(message):
    print(message)
    logging.info(message)

log_message(f"[{DATE}] === Server Maintenance Check ===")

# 1. APT Update Check
log_message(f"[{DATE}] Checking for updates...")
try:
    result = subprocess.run(['apt', 'update', '-qq'], capture_output=True, text=True)
    last_lines = '\n'.join(result.stdout.split('\n')[-5:])
    log_message(last_lines)
    
    result = subprocess.run(['apt', 'list', '--upgradable'], capture_output=True, text=True)
    updates = len(result.stdout.strip().split('\n')) - 1  # Subtract header line
    
    if updates > 0:
        log_message(f"[{DATE}] ⚠️ {updates} packages can be upgraded")
except Exception as e:
    log_message(f"[{DATE}] Error checking updates: {str(e)}")

# 2. RAM Check (8GB total)
log_message(f"[{DATE}] Checking RAM usage...")
try:
    result = subprocess.run(['free', '-m'], capture_output=True, text=True)
    lines = result.stdout.strip().split('\n')
    mem_line = [line for line in lines if line.startswith('Mem:')][0]
    ram_used = int(mem_line.split()[2])
    ram_total = 8192  # 8GB in MB
    ram_percent = int((ram_used * 100) / ram_total)
    
    log_message(f"[{DATE}] RAM: {ram_used}MB / {ram_total}MB ({ram_percent}%)")
    
    if ram_percent > 90:
        log_message(f"[{DATE}] 🔴 WARNING: RAM usage > 90%!")
    elif ram_percent > 80:
        log_message(f"[{DATE}] 🟡 WARNING: RAM usage > 80%")
except Exception as e:
    log_message(f"[{DATE}] Error checking RAM: {str(e)}")

# 3. Disk Space Check
log_message(f"[{DATE}] Checking disk space...")
try:
    result = subprocess.run(['df', '-h', '/'], capture_output=True, text=True)
    disk_info = result.stdout.strip().split('\n')[1].split()
    disk_used = disk_info[2]
    disk_total = disk_info[1]
    disk_percent_str = disk_info[4]
    disk_percent = int(disk_percent_str.rstrip('%'))
    
    log_message(f"[{DATE}] Disk: {disk_used} / {disk_total} ({disk_percent_str} used)")
    
    if disk_percent > 90:
        log_message(f"[{DATE}] 🔴 WARNING: Disk > 90%!")
    elif disk_percent > 80:
        log_message(f"[{DATE}] 🟡 WARNING: Disk > 80%")
except Exception as e:
    log_message(f"[{DATE}] Error checking disk space: {str(e)}")

# 4. NTP Check
log_message(f"[{DATE}] Checking NTP sync...")
try:
    result = subprocess.run(['timedatectl', 'status'], capture_output=True, text=True)
    if 'NTP synchronized: yes' in result.stdout:
        log_message(f"[{DATE}] ✅ NTP synchronized")
    else:
        log_message(f"[{DATE}] ⚠️ NTP not synchronized")
except Exception as e:
    log_message(f"[{DATE}] Error checking NTP: {str(e)}")

# 5. OpenClaw Gateway Status
log_message(f"[{DATE}] Checking OpenClaw Gateway...")
try:
    result = subprocess.run(['systemctl', 'is-active', 'openclaw-gateway'], capture_output=True, text=True)
    if result.returncode == 0 and 'active' in result.stdout:
        log_message(f"[{DATE}] ✅ OpenClaw Gateway running")
    else:
        log_message(f"[{DATE}] 🔴 OpenClaw Gateway NOT running!")
        subprocess.run(['systemctl', 'restart', 'openclaw-gateway'])
except Exception as e:
    log_message(f"[{DATE}] Error checking OpenClaw Gateway: {str(e)}")

# 6. Load Average
log_message(f"[{DATE}] Checking load average...")
try:
    result = subprocess.run(['uptime'], capture_output=True, text=True)
    load_avg = result.stdout.split('load average:')[1].split(',')[0].strip()
    log_message(f"[{DATE}] Load Average: {load_avg}")
except Exception as e:
    log_message(f"[{DATE}] Error checking load average: {str(e)}")

log_message(f"[{DATE}] === Maintenance Complete ===")
log_message("")
