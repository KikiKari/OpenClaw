#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "cffd9a372b04d74800fb5f8bd72870bcbb387bc02d995f998b254bf45b6311e2", "source_sha256": "b339455e9e618c836ccf2e3732e4fec9897f079730d8814eadb716e2459df453", "target_language": "ruby"}
# frame.sh — portiert nach ruby
# Quelle: shell, OpenClaw@gateway1:skills/video-frames/scripts/frame.sh
# auch in: OpenClaw@gateway2:skills/video-frames/scripts/frame.sh
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

def usage
  $stderr.puts <<~EOF
  Usage:
    frame.sh <video-file> [--time HH:MM:SS] [--index N] --out /path/to/frame.jpg

  Examples:
    frame.sh video.mp4 --out /tmp/frame.jpg
    frame.sh video.mp4 --time 00:00:10 --out /tmp/frame-10s.jpg
    frame.sh video.mp4 --index 0 --out /tmp/frame0.png
  EOF
  exit 2
end

if ARGV.empty? || ARGV[0] == '-h' || ARGV[0] == '--help'
  usage
end

input = ARGV.shift

time = nil
index = nil
output = nil

while !ARGV.empty?
  case ARGV[0]
  when '--time'
    ARGV.shift
    time = ARGV.shift
  when '--index'
    ARGV.shift
    index = ARGV.shift
  when '--out'
    ARGV.shift
    output = ARGV.shift
  else
    $stderr.puts "Unknown arg: #{ARGV[0]}"
    usage
  end
end

if !File.exist?(input)
  $stderr.puts "File not found: #{input}"
  exit 1
end

if output.nil?
  $stderr.puts "Missing --out"
  usage
end

# Create directory for output file
outdir = File.dirname(output)
Dir.mkdir_p(outdir)

if !index.nil?
  system('ffmpeg', '-hide_banner', '-loglevel', 'error', '-y',
         '-i', input,
         '-vf', "select=eq(n\\,#{index})",
         '-vframes', '1',
         output)
elsif !time.nil?
  system('ffmpeg', '-hide_banner', '-loglevel', 'error', '-y',
         '-ss', time,
         '-i', input,
         '-frames:v', '1',
         output)
else
  system('ffmpeg', '-hide_banner', '-loglevel', 'error', '-y',
         '-i', input,
         '-vf', 'select=eq(n\\,0)',
         '-vframes', '1',
         output)
end

puts output
