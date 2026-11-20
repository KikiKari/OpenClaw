#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "fddffa4cf55557ebc451b88458b43e0d6dfe51178588a9de7d6957a210dff37a", "source_sha256": "38390e5c16266050829f3193f79ca05d8ec898095dc834f407431d87ecfadeb8", "target_language": "lua"}
-- server-maintenance.sh — portiert nach lua
-- Quelle: shell, OpenClaw@gateway1:scripts/server-maintenance.sh
-- auch in: OpenClaw@gateway2:scripts/server-maintenance.sh
-- Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

-- Server Maintenance Script
-- RAM: 8GB, Uhr: Europe/Berlin

local LOG_FILE = "/var/log/server-maintenance.log"
local DATE = os.date("%Y-%m-%d %H:%M:%S")
local HOST = io.popen("hostname"):read("*l")

-- Farben für Terminal
local RED = "\27[0;31m"
local GREEN = "\27[0;32m"
local YELLOW = "\27[1;33m"
local NC = "\27[0m"

local function log_message(message)
    local file = io.open(LOG_FILE, "a")
    if file then
        file:write("[" .. DATE .. "] " .. message .. "\n")
        file:close()
    end
    print("[" .. DATE .. "] " .. message)
end

log_message("=== Server Maintenance Check ===")

-- 1. APT Update Check
log_message("Checking for updates...")
local apt_update = io.popen("apt update -qq 2>&1 | tail -5")
local apt_output = apt_update:read("*a")
apt_update:close()
log_message(apt_output)

local apt_list = io.popen("apt list --upgradable 2>/dev/null | wc -l")
local updates = tonumber(apt_list:read("*l")) or 0
apt_list:close()

if updates > 1 then
    log_message("⚠️ " .. updates .. " packages can be upgraded")
end

-- 2. RAM Check (8GB total)
log_message("Checking RAM usage...")
local RAM_TOTAL = 8192  -- 8GB in MB
local free_cmd = io.popen("free -m")
local ram_lines = {}
for line in free_cmd:lines() do
    table.insert(ram_lines, line)
end
free_cmd:close()

local ram_used_line = ram_lines[2]
local ram_values = {}
for value in string.gmatch(ram_used_line, "%S+") do
    table.insert(ram_values, value)
end
local RAM_USED = tonumber(ram_values[3]) or 0
local RAM_PERCENT = math.floor((RAM_USED * 100) / RAM_TOTAL)

log_message("RAM: " .. RAM_USED .. "MB / " .. RAM_TOTAL .. "MB (" .. RAM_PERCENT .. "%)")
if RAM_PERCENT > 90 then
    log_message("🔴 WARNING: RAM usage > 90%!")
elseif RAM_PERCENT > 80 then
    log_message("🟡 WARNING: RAM usage > 80%")
end

-- 3. Disk Space Check
log_message("Checking disk space...")
local df_cmd = io.popen("df -h / | tail -1")
local df_line = df_cmd:read("*l")
df_cmd:close()

local df_values = {}
for value in string.gmatch(df_line, "%S+") do
    table.insert(df_values, value)
end

log_message("Disk: " .. df_values[3] .. " / " .. df_values[2] .. " (" .. df_values[5] .. " used)")

local disk_percent_str = string.gsub(df_values[5], "%%", "")
local DISK_PERCENT = tonumber(disk_percent_str) or 0

if DISK_PERCENT > 90 then
    log_message("🔴 WARNING: Disk > 90%!")
elseif DISK_PERCENT > 80 then
    log_message("🟡 WARNING: Disk > 80%")
end

-- 4. NTP Check
log_message("Checking NTP sync...")
local ntp_cmd = io.popen("timedatectl status")
local ntp_status = ntp_cmd:read("*a")
ntp_cmd:close()

if string.find(ntp_status, "NTP synchronized: yes") then
    log_message("✅ NTP synchronized")
else
    log_message("⚠️ NTP not synchronized")
end

-- 5. OpenClaw Gateway Status
log_message("Checking OpenClaw Gateway...")
local gateway_cmd = io.popen("systemctl is-active --quiet openclaw-gateway")
local gateway_result = gateway_cmd:close()

if gateway_result == true or gateway_result == 0 then
    log_message("✅ OpenClaw Gateway running")
else
    log_message("🔴 OpenClaw Gateway NOT running!")
    os.execute("systemctl restart openclaw-gateway")
end

-- 6. Load Average
local uptime_cmd = io.popen("uptime")
local uptime_line = uptime_cmd:read("*l")
uptime_cmd:close()

local load_avg = string.match(uptime_line, "load average: ([^,]+)")
if load_avg then
    load_avg = string.gsub(load_avg, ",", "")
    log_message("Load Average: " .. load_avg)
end

log_message("=== Maintenance Complete ===")
log_message("")
