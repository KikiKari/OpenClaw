#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "b791f045679dde7600e137ce68ca2c38a36f4f5c98e95dc8c71f2832f276f4c7", "source_sha256": "00c9566941995c9087b6e678da6c1d9714313ba570c7e02eeada841de0f8ddde", "target_language": "ruby"}
# check-composite-action-input-interpolation.py — portiert nach ruby
# Quelle: python, workspace@local:skills/github-clones/openclaw/scripts/check-composite-action-input-interpolation.py
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

require 'pathname'
require 'yaml'

INPUT_INTERPOLATION_RE = /$\{\{\s*inputs\./
RUN_LINE_RE = /^(\s*)run:\s*(.*)$/
USING_COMPOSITE_RE = /^\s*using:\s*composite\s*$/

def indentation(line)
  line.length - line.lstrip.length
end

def scan_file(path)
  text = File.read(path, encoding: 'utf-8')
  return [] unless USING_COMPOSITE_RE.match?(text)

  lines = text.split("\n")
  violations = []
  line_count = lines.length
  index = 0

  while index < line_count
    line = lines[index]
    match = RUN_LINE_RE.match(line)
    unless match
      index += 1
      next
    end

    run_indent = match[1].length
    run_value = match[2].strip
    line_no = index + 1

    if !run_value.empty? && !['|', '>'].include?(run_value[0])
      if INPUT_INTERPOLATION_RE.match?(run_value)
        violations.push([line_no, line.strip])
      end
      index += 1
      next
    end

    index += 1
    while index < line_count
      script_line = lines[index]
      if script_line.strip.empty?
        index += 1
        next
      end
      if indentation(script_line) <= run_indent
        break
      end
      if INPUT_INTERPOLATION_RE.match?(script_line)
        violations.push([index + 1, script_line.strip])
      end
      index += 1
    end
  end

  violations
end

def main
  root = Pathname.new('.github/actions')
  files = root.glob('action.y*ml').sort
  all_violations = []

  files.each do |file_path|
    scan_file(file_path).each do |line_no, line|
      all_violations.push([file_path, line_no, line])
    end
  end

  if !all_violations.empty?
    puts 'Disallowed direct inputs interpolation in composite run blocks:'
    all_violations.each do |file_path, line_no, line|
      puts "- #{file_path}:#{line_no}: #{line}"
    end
    puts 'Use env: and reference shell variables instead.'
    return 1
  end

  puts 'No direct inputs interpolation found in composite run blocks.'
  return 0
end

exit(main)
