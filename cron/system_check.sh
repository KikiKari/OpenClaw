#!/usr/bin/env bash
# System check: Disk usage >80% or load average >5.0 triggers alert.

disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
load_avg=$(awk '{print $1}' /proc/loadavg)

if [ "$disk_usage" -gt 80 ] || (( $(echo "$load_avg > 5.0" | bc -l) )); then
  openclaw message send --channel current --message "⚠️ System Check: Disk usage ${disk_usage}% or load ${load_avg} is critical."
else
  openclaw message send --channel current --message "✅ System Check: OK. Disk ${disk_usage}% load ${load_avg}."
fi
