#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "4440918dd8d24d120caca4127945625eae72646f7d1b7be04126e12837737eb5", "source_sha256": "fecaa7522aec9008996f5664c745893f7fb7a2a4a3134a9f2855acde7f79596c", "target_language": "ruby"}
# extract-tiktok-streamlink.sh — portiert nach ruby
# Quelle: shell, OpenClaw@gateway2:skills/tiktok-live-mon/scripts/extraction-methods/extract-tiktok-streamlink.sh
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

# Bounded fallback used by the enhanced extractor. Output is normalized again
# by tiktok-get-stream.js; standalone success must remain URL-only unless
# --json is requested. Exit 75 means preflight overload.
USERNAME = ARGV[0]&.gsub(/^@/, '') || ''
QUALITY = ARGV[1] || 'best'
JSON_FLAG = ARGV[2] || ''
TIMESTAMP = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')

def emit_json(success, method, username, url, quality, author, title, error, timestamp, status)
  require 'json'
  payload = {
    'success' => success,
    'method' => method,
    'username' => username,
    'url' => url,
    'quality' => quality,
    'author' => author,
    'title' => title,
    'error' => error,
    'timestamp' => timestamp,
    'status' => status
  }.reject { |_, v| v.nil? || v.empty? }
  
  payload['success'] = payload['success'].to_s.downcase == 'true' if payload.key?('success')
  puts JSON.generate(payload)
end

# Validate username
unless USERNAME.match?(/^[A-Za-z0-9._]{1,24}$/)
  $stderr.puts "Invalid TikTok username"
  exit 64
end

# Validate quality
valid_qualities = %w[best worst original 1080p60 720p60 720p 540p 360p auto]
unless valid_qualities.include?(QUALITY)
  $stderr.puts "Invalid stream quality"
  exit 64
end

# Check system load
load_per_cpu = `uptime`.match(/load average: ([\d.]+)/)[1].to_f / [1, `nproc`.to_i].max
max_load = ENV['TIKTOK_MAX_LOAD_PER_CPU']&.to_f || 1.5

if load_per_cpu > max_load
  emit_json('false', 'streamlink', USERNAME, '', QUALITY, '', '', 
            'host overloaded', TIMESTAMP, 'overloaded')
  $stderr.puts JSON.generate({
    'success' => false,
    'method' => 'streamlink',
    'username' => USERNAME,
    'url' => '',
    'quality' => QUALITY,
    'author' => '',
    'title' => '',
    'error' => 'host overloaded',
    'timestamp' => TIMESTAMP,
    'status' => 'overloaded'
  })
  exit 75
end

# Check if streamlink is installed
unless system('which streamlink > /dev/null 2>&1')
  emit_json('false', 'streamlink', USERNAME, '', QUALITY, '', '', 
            'streamlink not installed', TIMESTAMP, 'dependency_missing')
  $stderr.puts JSON.generate({
    'success' => false,
    'method' => 'streamlink',
    'username' => USERNAME,
    'url' => '',
    'quality' => QUALITY,
    'author' => '',
    'title' => '',
    'error' => 'streamlink not installed',
    'timestamp' => TIMESTAMP,
    'status' => 'dependency_missing'
  })
  exit 2
end

# Set up streamlink parameters
LIVE_URL = "https://www.tiktok.com/@#{USERNAME}/live"
selector_map = {
  'original' => 'origin,uhd_60,hd_60,hd,sd,ld,best,worst',
  'auto' => 'best,origin,uhd_60,hd_60,hd,sd,ld,worst',
  '1080p60' => 'uhd_60,hd_60,hd,sd,ld,worst',
  '720p60' => 'hd_60,hd,sd,ld,worst',
  '720p' => 'hd,sd,ld,worst',
  '540p' => 'sd,ld,worst',
  '360p' => 'ld,worst'
}
SELECTOR = selector_map[QUALITY] || QUALITY

# Try to get JSON output first
output = `streamlink --json "#{LIVE_URL}" "#{SELECTOR}" 2>/dev/null`
exit_code = $?.exitstatus

if exit_code != 0 || output.strip.empty?
  # Fallback to stream-url
  url = `streamlink --stream-url "#{LIVE_URL}" "#{SELECTOR}" 2>/dev/null`.strip
  if $?.exitstatus != 0 || url.empty?
    emit_json('false', 'streamlink', USERNAME, '', QUALITY, '', '', 
              'streamlink failed or no stream found', TIMESTAMP, 'offline')
    $stderr.puts JSON.generate({
      'success' => false,
      'method' => 'streamlink',
      'username' => USERNAME,
      'url' => '',
      'quality' => QUALITY,
      'author' => '',
      'title' => '',
      'error' => 'streamlink failed or no stream found',
      'timestamp' => TIMESTAMP,
      'status' => 'offline'
    })
    exit 1
  end
  
  if JSON_FLAG == '--json'
    emit_json('true', 'streamlink', USERNAME, url, QUALITY, '', '', '', TIMESTAMP, 'live')
  else
    puts url
  end
  exit 0
end

# Parse JSON output
begin
  data = JSON.parse(output)
  url = data['url'] || ''
  streams = data['streams'] || {}
  
  if url.empty? && streams.is_a?(Hash)
    %w[best worst].concat(streams.keys).each do |key|
      value = streams[key]
      if value.is_a?(Hash) && value['url']
        url = value['url']
        break
      end
    end
  end
  
  metadata = data['metadata'] || {}
  author = metadata['author'] || ''
  title = metadata['title'] || ''
  
rescue JSON::ParserError
  emit_json('false', 'streamlink', USERNAME, '', QUALITY, '', '', 
            'invalid streamlink JSON', TIMESTAMP, 'technical_error')
  $stderr.puts JSON.generate({
    'success' => false,
    'method' => 'streamlink',
    'username' => USERNAME,
    'url' => '',
    'quality' => QUALITY,
    'author' => '',
    'title' => '',
    'error' => 'invalid streamlink JSON',
    'timestamp' => TIMESTAMP,
    'status' => 'technical_error'
  })
  exit 2
end

if url.empty?
  emit_json('false', 'streamlink', USERNAME, '', QUALITY, author, title, 
            'could not extract stream URL', TIMESTAMP, 'offline')
  $stderr.puts JSON.generate({
    'success' => false,
    'method' => 'streamlink',
    'username' => USERNAME,
    'url' => '',
    'quality' => QUALITY,
    'author' => author,
    'title' => title,
    'error' => 'could not extract stream URL',
    'timestamp' => TIMESTAMP,
    'status' => 'offline'
  })
  exit 1
end

if JSON_FLAG == '--json'
  emit_json('true', 'streamlink', USERNAME, url, QUALITY, author, title, '', TIMESTAMP, 'live')
else
  puts url
end
