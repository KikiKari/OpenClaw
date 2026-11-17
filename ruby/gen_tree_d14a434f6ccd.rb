#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "61be42ec21e8afd149ce6a8ad0c6f1eead4e3affe2ed269b62679a606cb54a74", "source_sha256": "0a55a33f11db266892b50c887fd8d01783f387e3072c8c5b9ed86ca6788a8c52", "target_language": "ruby"}
# gen_tree.py — portiert nach ruby
# Quelle: python, OpenClaw@gateway2:scripts/gen_tree.py
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

# Replicates `tree -a -L 6` output for /workspace into important/openclaw-tree.txt
# (used because the `tree` binary is unavailable in this sandbox).

require 'fileutils'
require 'time'

ROOT = "/workspace"
OUT = "/workspace/important/openclaw-tree.txt"
MAX_DEPTH = 6

def collect(path, prefix = "", depth = 1)
  lines = []
  begin
    entries = Dir.entries(path).sort
  rescue Errno::EACCES, Errno::ENOENT
    return lines
  end
  
  total = entries.length
  entries.each_with_index do |name, i|
    next if name == '.' || name == '..'
    
    is_last = (i == total - 1)
    connector = is_last ? "\u2514\u2500\u2500 " : "\u251c\u2500\u2500 "
    lines << prefix + connector + name
    full = File.join(path, name)
    
    if depth < MAX_DEPTH && File.directory?(full) && !File.symlink?(full)
      next_prefix = prefix + (is_last ? "    " : "\u2502   ")
      lines.concat(collect(full, next_prefix, depth + 1))
    end
  end
  lines
end

body = collect(ROOT)
header = (
  "# OpenClaw Workspace Tree\n" +
  "# Generiert: #{Time.now.iso8601}\n" +
  "# Befehl: tree -a -L 6 #{ROOT} (emuliert via gen_tree.rb)\n" +
  "# Diese Datei wird automatisch von db-maintainer aktualisiert\n\n"
)
content = header + ".\n" + body.join("\n") + "\n"

File.open(OUT, "w:utf-8") do |f|
  f.write(content)
end

puts "written #{OUT}: #{body.length + 1} lines, #{content.bytesize} bytes"
