#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "45806de9dc75fbf12df48872ed0b4f3919a83654ad5d27a770863bd1a40fab93", "source_sha256": "c76d61da97f14736857987d3dd8234160c73b0a1b52ade5aac72de04cc61e7e6", "target_language": "ruby"}
# check-no-conflict-markers.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-no-conflict-markers.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

require 'open3'
require 'pathname'

def is_binary_buffer(buffer)
  buffer.include?("\x00")
end

def find_conflict_marker_lines(content)
  lines = content.split(/\r?\n/)
  matches = []
  lines.each_with_index do |line, index|
    if line.start_with?("<<<<<<< ") ||
       line.start_with?("||||||| ") ||
       line == "=======" ||
       line.start_with?(">>>>>>> ")
      matches.push(index + 1)
    end
  end
  matches
end

def list_tracked_files(cwd = Dir.pwd)
  stdout, stderr, status = Open3.capture3("git", "ls-files", "-z", chdir: cwd)
  unless status.success?
    raise "git ls-files failed: #{stderr}"
  end
  stdout.split("\x00").reject(&:empty?).map { |relative_path| File.join(cwd, relative_path) }
end

def find_conflict_markers_in_files(file_paths, read_file: nil)
  read_file ||= lambda { |file_path| File.read(file_path, mode: 'rb') }
  violations = []
  file_paths.each do |file_path|
    content = nil
    begin
      content = read_file.call(file_path)
    rescue
      next
    end
    unless content.is_a?(String)
      content = content.to_s
    end
    if is_binary_buffer(content)
      next
    end
    lines = find_conflict_marker_lines(content.force_encoding('UTF-8'))
    if lines.length > 0
      violations.push({
        filePath: file_path,
        lines: lines,
      })
    end
  end
  violations
end

def main
  cwd = Dir.pwd
  violations = find_conflict_markers_in_files(list_tracked_files(cwd))
  if violations.length == 0
    return
  end

  $stderr.puts "Found unresolved merge conflict markers:"
  violations.each do |violation|
    relative_path = Pathname.new(violation[:filePath]).relative_path_from(Pathname.new(cwd)).to_s
    relative_path = violation[:filePath] if relative_path.empty?
    $stderr.puts "- #{relative_path}:#{violation[:lines].join(',')}"
  end
  exit 1
end

if __FILE__ == $0
  begin
    main()
  rescue => error
    $stderr.puts error
    exit 1
  end
end
