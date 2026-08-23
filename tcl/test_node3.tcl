#!/usr/bin/tclsh8.6
# test_node3.sh — portiert nach tcl
# Quelle: shell, OpenClaw@gateway1:scripts/test_node3.sh
# auch in: OpenClaw@gateway2:scripts/test_node3.sh
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

# Test Node 3 Connection
set env(OPENCLAW_ALLOW_INSECURE_PRIVATE_WS) 1
puts "Starting node connection test..."

# Start the openclaw process in background
set pid [exec /usr/local/bin/openclaw node run --host 152.53.145.65 --port 18789 >@stdout 2>@stderr &]

# Kill the process after 15 seconds
after 15000 "catch {exec kill $pid}"

# Wait for the process to complete and get exit code
if [catch {exec wait $pid} result] {
    set exit_code 1
} else {
    # Extract exit code from wait command output
    regexp {exit\s+(\d+)} $result -> exit_code
}

puts "Exit code: $exit_code"
