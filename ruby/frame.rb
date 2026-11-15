#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "1ef84a9fdfdf5e58e544ceeda30f97e680929f43ae31ffb44b8ed5b62f3b8dd8", "source_sha256": "b339455e9e618c836ccf2e3732e4fec9897f079730d8814eadb716e2459df453", "target_language": "ruby"}
# frame.sh — portiert nach ruby
# Quelle: shell, OpenClaw@gateway1:skills/video-frames/scripts/frame.sh
# auch in: OpenClaw@gateway2:skills/video-frames/scripts/frame.sh
# Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

require 'optparse'
require 'fileutils'

def usage
  STDERR.puts <<~EOF
    Usage:
      frame.rb <video-file> [--time HH:MM:SS] [--index N] --out /path/to/frame.jpg

    Examples:
      frame.rb video.mp4 --out /tmp/frame.jpg
      frame.rb video.mp4 --time 00:00:10 --out /tmp/frame-10s.jpg
      frame.rb video.mp4 --index 0 --out /tmp/frame0.png
  EOF
  exit 2
end

options = {}
parser = OptionParser.new do |opts|
  opts.banner = "Usage: frame.rb [options]"

  opts.on("--time TIME", "Time in HH:MM:SS format") do |time|
    options[:time] = time
  end

  opts.on("--index INDEX", Integer, "Frame index") do |index|
    options[:index] = index
  end

  opts.on("--out OUT", "Output file path") do |out|
    options[:out] = out
  end

  opts.on("-h", "--help", "Show this help") do
    usage
  end
end

begin
  parser.parse!
rescue OptionParser::InvalidOption => e
  STDERR.puts "Unknown arg: #{e.message}"
  usage
end

if ARGV.empty?
  usage
end

input_file = ARGV[0]

if !File.exist?(input_file)
  STDERR.puts "File not found: #{input_file}"
  exit 1
end

if options[:out].nil? || options[:out].empty?
  STDERR.puts "Missing --out"
  usage
end

# Create output directory if it doesn't exist
output_dir = File.dirname(options[:out])
FileUtils.mkdir_p(output_dir)

# Build ffmpeg command based on provided options
cmd = ['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y']

if options[:index]
  cmd += ['-i', input_file, '-vf', "select=eq(n\\,#{options[:index]})", '-vframes', '1', options[:out]]
elsif options[:time]
  cmd += ['-ss', options[:time], '-i', input_file, '-frames:v', '1', options[:out]]
else
  cmd += ['-i', input_file, '-vf', 'select=eq(n\\,0)', '-vframes', '1', options[:out]]
end

# Execute the command
system(*cmd.flatten) or exit($?.exitstatus)

puts options[:out]
