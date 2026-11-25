#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "4f09e0b86458e8c8ab8bd81cf4bb2530f14e1d9af0ba523bc4b0f231a0ad287c", "source_sha256": "9c8abc93c198b77f804a6837db7baf1e85c902dc35a853c8086222a89f83fc89", "target_language": "ruby"}
# transcribe.sh — portiert nach ruby
# Quelle: shell, workspace@local:skills/github-clones/openclaw/skills/openai-whisper-api/scripts/transcribe.sh
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

require 'optparse'
require 'net/http'
require 'uri'
require 'json'
require 'fileutils'

def usage
  STDERR.puts <<~EOF
    Usage:
      transcribe.rb <audio-file> [options]
  EOF
  exit 2
end

options = {
  model: 'whisper-1',
  out: nil,
  language: nil,
  prompt: nil,
  json: false
}

opt_parser = OptionParser.new do |opts|
  opts.banner = "Usage: transcribe.rb <audio-file> [options]"

  opts.on("--model MODEL", "Model to use (default: whisper-1)") do |m|
    options[:model] = m
  end

  opts.on("--out OUT", "Output file path") do |o|
    options[:out] = o
  end

  opts.on("--language LANGUAGE", "Language code") do |l|
    options[:language] = l
  end

  opts.on("--prompt PROMPT", "Prompt hint") do |p|
    options[:prompt] = p
  end

  opts.on("--json", "Output JSON format") do
    options[:json] = true
  end

  opts.on("-h", "--help", "Show this help message") do
    puts opts
    exit
  end
end

begin
  opt_parser.parse!
rescue OptionParser::InvalidOption => e
  STDERR.puts "Unknown arg: #{e.message}"
  usage
end

if ARGV.empty? || ARGV[0] == '-h' || ARGV[0] == '--help'
  usage
end

input_file = ARGV[0]

unless File.exist?(input_file)
  STDERR.puts "File not found: #{input_file}"
  exit 1
end

api_key = ENV['OPENAI_API_KEY']
unless api_key && !api_key.empty?
  STDERR.puts "Missing OPENAI_API_KEY"
  exit 1
end

response_format = options[:json] ? 'json' : 'text'

if options[:out].nil? || options[:out].empty?
  base = File.basename(input_file, '.*')
  ext = response_format == 'json' ? '.json' : '.txt'
  dir = File.dirname(input_file)
  options[:out] = File.join(dir, "#{base}#{ext}")
end

# Create output directory if needed
outdir = File.dirname(options[:out])
FileUtils.mkdir_p(outdir) unless Dir.exist?(outdir)

# Build API request
api_base = ENV['OPENAI_BASE_URL'] || 'https://api.openai.com/v1'
api_base = api_base.chomp('/')
uri = URI("#{api_base}/audio/transcriptions")

# Use multipart form data approach by building the request manually
boundary = "----RubyFormBoundary#{Time.now.to_i}#{rand(1000)}"

# Build form data
form_data = []
form_data << ["file", File.open(input_file, 'rb').read, "filename=\"#{File.basename(input_file)}\""]
form_data << ["model", options[:model]]
form_data << ["response_format", response_format]
form_data << ["language", options[:language]] if options[:language]
form_data << ["prompt", options[:prompt]] if options[:prompt]

# Create multipart body
body_parts = []
form_data.each do |field, value, extra|
  if field == 'file'
    body_parts << "--#{boundary}\r\nContent-Disposition: form-data; name=\"#{field}\"; #{extra}\r\nContent-Type: application/octet-stream\r\n\r\n#{value}\r\n"
  else
    next if value.nil? || value.empty?
    body_parts << "--#{boundary}\r\nContent-Disposition: form-data; name=\"#{field}\"\r\n\r\n#{value}\r\n"
  end
end
body_parts << "--#{boundary}--\r\n"
body = body_parts.join

# Make HTTP request
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true if uri.scheme == 'https'

request = Net::HTTP::Post.new(uri.request_uri)
request['Authorization'] = "Bearer #{api_key}"
request['Accept'] = 'application/json'
request['Content-Type'] = "multipart/form-data; boundary=#{boundary}"
request.body = body

response = http.request(request)

if response.code.to_i >= 400
  STDERR.puts "API Error: #{response.body}"
  exit 1
end

# Write response to output file
File.open(options[:out], 'wb') { |f| f.write(response.body) }

puts options[:out]
