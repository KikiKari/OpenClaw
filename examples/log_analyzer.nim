import std/[re, tables]

# OpenClaw log analyzer (Nim) — parses gateway access logs from stdin
let pattern = re"^(\S+)\s+(INFO|WARN|ERROR)\s+(\S+)\s+(.+)$"
var counts = {"INFO": 0, "WARN": 0, "ERROR": 0}.toTable

for line in stdin.lines:
  var m: array[4, string]
  if line.match(pattern, m):
    let level = m[1]
    counts[level] += 1
    if level == "ERROR":
      echo "⚠ ", m[0], " [", m[2], "] ", m[3]

echo "\n--- Summary ---"
for level in ["ERROR", "INFO", "WARN"]:
  echo level, ": ", counts[level]
