#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "f77a9ea7749f46c1213e2f909c3b356ddc30961b84fa127cc7b41119887b4688", "source_sha256": "4c4552ce0adb2754080969f00b761c1c118766771e0595b8c9b416ee0842fbae", "target_language": "ruby"}
# find-sessions.sh — portiert nach ruby
# Quelle: shell, workspace@local:skills/github-clones/openclaw/skills/tmux/scripts/find-sessions.sh
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

require 'optparse'
require 'fileutils'

def usage
  puts <<~USAGE
    Usage: find-sessions.rb [-L socket-name|-S socket-path|-A] [-q pattern]

    List tmux sessions on a socket (default tmux socket if none provided).

    Options:
      -L, --socket       tmux socket name (passed to tmux -L)
      -S, --socket-path  tmux socket path (passed to tmux -S)
      -A, --all          scan all sockets under OPENCLAW_TMUX_SOCKET_DIR
      -q, --query        case-insensitive substring to filter session names
      -h, --help         show this help
  USAGE
  exit 0
end

socket_name = ""
socket_path = ""
query = ""
scan_all = false
socket_dir = ENV['OPENCLAW_TMUX_SOCKET_DIR'] || "#{ENV['TMPDIR'] || '/tmp'}/openclaw-tmux-sockets"

OptionParser.new do |opts|
  opts.banner = "Usage: find-sessions.rb [options]"
  
  opts.on("-L", "--socket SOCKET", "tmux socket name (passed to tmux -L)") do |s|
    socket_name = s
  end
  
  opts.on("-S", "--socket-path PATH", "tmux socket path (passed to tmux -S)") do |s|
    socket_path = s
  end
  
  opts.on("-A", "--all", "scan all sockets under OPENCLAW_TMUX_SOCKET_DIR") do
    scan_all = true
  end
  
  opts.on("-q", "--query QUERY", "case-insensitive substring to filter session names") do |q|
    query = q
  end
  
  opts.on("-h", "--help", "show this help") do
    usage
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

def list_sessions(label, *tmux_args)
  tmux_cmd = ['tmux'] + tmux_args
  begin
    sessions = `#{tmux_cmd.join(' ')} list-sessions -F '\#{session_name}\t\#{session_attached}\t\#{session_created_string}' 2>/dev/null`
  rescue Errno::ENOENT
    STDERR.puts "tmux not found in PATH"
    exit 1
  end

  unless $?.success?
    STDERR.puts "No tmux server found on #{label}"
    return false
  end

  if !@query.empty?
    sessions = sessions.lines.grep(/#{@query}/i).join
  end

  if sessions.strip.empty?
    puts "No sessions found on #{label}"
    return true
  end

  puts "Sessions on #{label}:"
  sessions.each_line do |line|
    name, attached, created = line.chomp.split("\t")
    attached_label = (attached == "1") ? "attached" : "detached"
    puts "  - #{name} (#{attached_label}, started #{created})"
  end
  true
end

# Store query in instance variable so it's accessible in method
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

socket_label = "default socket"
tmux_args = []

if !socket_name.empty?
  tmux_args += ['-L', socket_name]
  socket_label = "socket name '#{socket_name}'"
elsif !socket_path.empty?
  tmux_args += ['-S', socket_path]
  socket_label = "socket path '#{socket_path}'"
end

list_sessions(socket_label, *tmux_args)
