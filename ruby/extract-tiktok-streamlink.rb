#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "bbc8aafae5c7e60ac9061edea9598a198c590809e1badfd1a82ac67595dfe76a", "source_sha256": "fecaa7522aec9008996f5664c745893f7fb7a2a4a3134a9f2855acde7f79596c", "target_language": "ruby"}
# extract-tiktok-streamlink.sh — portiert nach ruby
# Quelle: shell, OpenClaw@gateway2:skills/tiktok-live-mon/scripts/extraction-methods/extract-tiktok-streamlink.sh
# Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

require 'json'
require 'open3'
require 'time'

def emit_json(success, method, username, url, quality, author, title, error, timestamp, status)
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

def validate_username(username)
  unless username.match?(/^[A-Za-z0-9._]{1,24}$/)
    STDERR.puts "Invalid TikTok username"
    exit 64
  end
end

def validate_quality(quality)
  valid_qualities = %w[best worst original 1080p60 720p60 720p 540p 360p auto]
  unless valid_qualities.include?(quality)
    STDERR.puts "Invalid stream quality"
    exit 64
  end
end

def get_load_per_cpu
  load_avg = File.read('/proc/loadavg').split[0].to_f
  cpu_count = [1, (File.readlines('/proc/cpuinfo').grep(/^processor/).count rescue 1)].max
  load_avg / cpu_count
rescue
  0.0
end

def check_dependencies
  system('which streamlink > /dev/null 2>&1')
end

def run_streamlink_json(url, selector)
  stdout, stderr, status = Open3.capture3('streamlink', '--json', url, selector)
  return nil, stderr, status unless status.success?

  begin
    JSON.parse(stdout.strip)
  rescue JSON::ParserError
    nil
  end
end

def run_streamlink_url(url, selector)
  stdout, stderr, status = Open3.capture3('streamlink', '--stream-url', url, selector)
  return nil unless status.success?

  stdout.strip
end

def extract_stream_info(data)
  url = data['url'] || ''
  streams = data['streams'] || {}
  
  if url.empty? && streams.is_a?(Hash)
    search_keys = ['best', 'worst'] + streams.keys
    search_keys.each do |key|
      stream_data = streams[key]
      if stream_data.is_a?(Hash) && stream_data['url']
        url = stream_data['url']
        break
      end
    end
  end
  
  metadata = data['metadata'] || {}
  {
    'url' => url,
    'author' => metadata['author'] || '',
    'title' => metadata['title'] || ''
  }
end

username = ARGV[0]&.gsub(/^@/, '') || ''
quality = ARGV[1] || 'best'
json_flag = ARGV[2] || ''
timestamp = Time.now.utc.iso8601

validate_username(username)
validate_quality(quality)

load_per_cpu = get_load_per_cpu
max_load = ENV['TIKTOK_MAX_LOAD_PER_CPU']&.to_f || 1.5

if load_per_cpu > max_load
  emit_json(false, 'streamlink', username, '', quality, '', '', 'host overloaded', timestamp, 'overloaded')
  exit 75
end

unless check_dependencies
  emit_json(false, 'streamlink', username, '', quality, '', '', 'streamlink not installed', timestamp, 'dependency_missing')
  exit 2
end

live_url = "https://www.tiktok.com/@#{username}/live"
selector = case quality
           when 'original'
             'origin,uhd_60,hd_60,hd,sd,ld,best,worst'
           when 'auto'
             'best,origin,uhd_60,hd_60,hd,sd,ld,worst'
           when '1080p60'
             'uhd_60,hd_60,hd,sd,ld,worst'
           when '720p60'
             'hd_60,hd,sd,ld,worst'
           when '720p'
             'hd,sd,ld,worst'
           when '540p'
             'sd,ld,worst'
           when '360p'
             'ld,worst'
           else
             quality
           end

output = run_streamlink_json(live_url, selector)

if output.nil?
  url = run_streamlink_url(live_url, selector)
  if url.nil? || url.empty?
    emit_json(false, 'streamlink', username, '', quality, '', '', 'streamlink failed or no stream found', timestamp, 'offline')
    exit 1
  end

  if json_flag == '--json'
    emit_json(true, 'streamlink', username, url, quality, '', '', '', timestamp, 'live')
  else
    puts url
  end
  exit 0
end

begin
  stream_info = extract_stream_info(output)
rescue
  emit_json(false, 'streamlink', username, '', quality, '', '', 'invalid streamlink JSON', timestamp, 'technical_error')
  exit 2
end

url = stream_info['url']
author = stream_info['author']
title = stream_info['title']

if url.nil? || url.empty?
  emit_json(false, 'streamlink', username, '', quality, author, title, 'could not extract stream URL', timestamp, 'offline')
  exit 1
end

if json_flag == '--json'
  emit_json(true, 'streamlink', username, url, quality, author, title, '', timestamp, 'live')
else
  puts url
end
