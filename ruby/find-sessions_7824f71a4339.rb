#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "a0d3e74e439b9065900774d0c11f15406d209940bd18094ac25ab77e266d4e57", "source_sha256": "a137d03b3b37332439a1592831d60479ff86315c7e6d6ed7da0fb799db0f13f7", "target_language": "ruby"}
# find-sessions.sh — portiert nach ruby
# Quelle: shell, OpenClaw@gateway1:skills/tmux/scripts/find-sessions.sh
# auch in: OpenClaw@gateway2:skills/tmux/scripts/find-sessions.sh
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

require 'optparse'
require 'open3'

def usage
  puts <<~USAGE
    Usage: find-sessions.sh [-L socket-name|-S socket-path|-A] [-q pattern]

    List tmux sessions on a socket (default tmux socket if none provided).

    Options:
      -L, --socket       tmux socket name (passed to tmux -L)
      -S, --socket-path  tmux socket path (passed to tmux -S)
      -A, --all          scan all sockets under CLAWDBOT_TMUX_SOCKET_DIR
      -q, --query        case-insensitive substring to filter session names
      -h, --help         show this help
  USAGE
end

socket_name = ""
socket_path = ""
query = ""
scan_all = false
socket_dir = ENV['CLAWDBOT_TMUX_SOCKET_DIR'] || "#{ENV['TMPDIR'] || '/tmp'}/clawdbot-tmux-sockets"

OptionParser.new do |opts|
  opts.banner = "Usage: find-sessions.sh [options]"

  opts.on("-L", "--socket SOCKET_NAME", "tmux socket name (passed to tmux -L)") do |name|
    socket_name = name
  end

  opts.on("-S", "--socket-path SOCKET_PATH", "tmux socket path (passed to tmux -S)") do |path|
    socket_path = path
  end

  opts.on("-A", "--all", "scan all sockets under CLAWDBOT_TMUX_SOCKET_DIR") do
    scan_all = true
  end

  opts.on("-q", "--query QUERY", "case-insensitive substring to filter session names") do |q|
    query = q
  end

  opts.on("-h", "--help", "show this help") do
    usage
    exit 0
  end
end.parse!

if scan_all && (!socket_name.empty? || !socket_path.empty?)
  STDERR.puts "Cannot combine --all with -L or -S"
  exit 1
end

if !socket_name.empty? && !socket_path.empty?
  STDERR.puts "Use either -L or -S, not both"
  exit 1
end

unless system("which tmux > /dev/null 2>&1")
  STDERR.puts "tmux not found in PATH"
  exit 1
end

def list_sessions(label, *tmux_args)
  tmux_cmd = ["tmux"] + tmux_args
  
  output, error, status = Open3.capture3(*tmux_cmd, "list-sessions", "-F", '#{session_name}\t#{session_attached}\t#{session_created_string}')
  
  unless status.success?
    STDERR.puts "No tmux server found on #{label}"
    return false
  end
  
  sessions = output.strip
  if !@query.empty?
    sessions = sessions.lines.grep(/#{@query}/i).join
  end
  
  if sessions.empty?
    puts "No sessions found on #{label}"
    return true
  end
  
  puts "Sessions on #{label}:"
  sessions.lines.each do |line|
    name, attached, created = line.chomp.split("\t")
    attached_label = (attached == "1") ? "attached" : "detached"
    puts "  - #{name} (#{attached_label}, started #{created})"
  end
  
  true
end

@query = query

if scan_all
  unless Dir.exist?(socket_dir)
    STDERR.puts "Socket directory not found: #{socket_dir}"
    exit 1
  end
  
  sockets = Dir.glob("#{socket_dir}/*").select { |f| File.socket?(f) }
  
  if sockets.empty?
    STDERR.puts "No sockets found under #{socket_dir}"
    exit 1
  end
  
  exit_code = 0
  sockets.each do |sock|
    success = list_sessions("socket path '#{sock}'", "-S", sock)
    exit_code = 1 unless success
  end
  exit exit_code
end

tmux_cmd = ["tmux"]
socket_label = "default socket"

if !socket_name.empty?
  tmux_cmd += ["-L", socket_name]
  socket_label = "socket name '#{socket_name}'"
elsif !socket_path.empty?
  tmux_cmd += ["-S", socket_path]
  socket_label = "socket path '#{socket_path}'"
end

list_sessions(socket_label, *tmux_cmd[1..-1])
