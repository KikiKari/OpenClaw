#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "a71902542e549f46cd59b88edee73c652079a5e09e90aaf09a5d6e0513cd5239", "source_sha256": "38390e5c16266050829f3193f79ca05d8ec898095dc834f407431d87ecfadeb8", "target_language": "ruby"}
# server-maintenance.sh — portiert nach ruby
# Quelle: shell, OpenClaw@gateway1:scripts/server-maintenance.sh
# auch in: OpenClaw@gateway2:scripts/server-maintenance.sh
# Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

# Server Maintenance Script
# RAM: 8GB, Uhr: Europe/Berlin

LOG_FILE = "/var/log/server-maintenance.log"
DATE = Time.now.strftime('%Y-%m-%d %H:%M:%S')
HOST = `hostname`.strip

# Farben für Terminal
RED = "\033[0;31m"
GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"
NC = "\033[0m"

def log_message(message)
  log_entry = "[#{DATE}] #{message}"
  puts log_entry
  File.open(LOG_FILE, 'a') { |f| f.puts log_entry }
end

log_message("=== Server Maintenance Check ===")

# 1. APT Update Check
log_message("Checking for updates...")
update_output = `apt update -qq 2>&1`
log_message(update_output.lines.last(5).join)
updates = `apt list --upgradable 2>/dev/null`.lines.count
if updates > 1
  log_message("⚠️ #{updates} packages can be upgraded")
end

# 2. RAM Check (8GB total)
log_message("Checking RAM usage...")
RAM_TOTAL = 8192  # 8GB in MB
ram_info = `free -m`.lines.grep(/^Mem:/).first.split
RAM_USED = ram_info[2].to_i
RAM_PERCENT = (RAM_USED * 100 / RAM_TOTAL).to_i
log_message("RAM: #{RAM_USED}MB / #{RAM_TOTAL}MB (#{RAM_PERCENT}%)")
if RAM_PERCENT > 90
  log_message("🔴 WARNING: RAM usage > 90%!")
elsif RAM_PERCENT > 80
  log_message("🟡 WARNING: RAM usage > 80%")
end

# 3. Disk Space Check
log_message("Checking disk space...")
disk_info = `df -h /`.lines.last.strip.split
log_message("Disk: #{disk_info[2]} / #{disk_info[1]} (#{disk_info[4]} used)")
DISK_PERCENT = disk_info[4].gsub('%', '').to_i
if DISK_PERCENT > 90
  log_message("🔴 WARNING: Disk > 90%!")
elsif DISK_PERCENT > 80
  log_message("🟡 WARNING: Disk > 80%")
end

# 4. NTP Check
log_message("Checking NTP sync...")
ntp_status = `timedatectl status`
if ntp_status.include?("NTP synchronized: yes")
  log_message("✅ NTP synchronized")
else
  log_message("⚠️ NTP not synchronized")
end

# 5. OpenClaw Gateway Status
log_message("Checking OpenClaw Gateway...")
gateway_status = `systemctl is-active --quiet openclaw-gateway; echo $?`.strip
if gateway_status == "0"
  log_message("✅ OpenClaw Gateway running")
else
  log_message("🔴 OpenClaw Gateway NOT running!")
  system("systemctl restart openclaw-gateway")
end

# 6. Load Average
LOAD = `uptime`.split('load average:').last.split(',').first.strip
log_message("Load Average: #{LOAD}")

log_message("=== Maintenance Complete ===")
log_message("")
