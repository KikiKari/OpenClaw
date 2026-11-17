#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "2b51a0aa2d695bb2732b7d38655fdd48068348aaa7a52c51ed4aa561f2878891", "source_sha256": "b00f64d55d344bbcc351ae7ade12137f0d9293b556aa0881ede43bef5bcb778b", "target_language": "ruby"}
# extract-tiktok-yt-dlp.sh — portiert nach ruby
# Quelle: shell, OpenClaw@gateway2:skills/tiktok-live-mon/scripts/extraction-methods/extract-tiktok-yt-dlp.sh
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

# Bounded fallback used by the enhanced extractor. Temporary files are cleaned
# on every exit and output is normalized again by tiktok-get-stream.js.
# Standalone overload exits 75 before yt-dlp starts.

require 'json'
require 'tmpdir'
require 'securerandom'
require 'open3'

def emit_json(success, method, username, url, format, error, timestamp, status)
  payload = {
    'success' => success,
    'method' => method,
    'username' => username,
    'url' => url,
    'format' => format,
    'error' => error,
    'timestamp' => timestamp,
    'status' => status
  }.reject { |_, v| v.nil? || v.empty? }
  
  payload['success'] = payload['success'].to_s.downcase == 'true' if payload.key?('success')
  puts JSON.generate(payload)
end

def get_load_per_cpu
  return 1.0 unless File.exist?('/proc/loadavg')
  load_avg = File.read('/proc/loadavg').split[0].to_f
  cpu_count = File.exist?('/proc/cpuinfo') ? File.read('/proc/cpuinfo').scan(/^processor/).count : 1
  cpu_count = 1 if cpu_count < 1
  load_avg / cpu_count
end

USERNAME = ARGV[0]&.gsub('@', '') || ''
FORMAT = ARGV[1] || 'best'
JSON_FLAG = ARGV[2] || ''
TIMESTAMP = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')

Dir.mktmpdir('tiktok-yt-dlp-') do |tmp_dir|
  at_exit { FileUtils.rm_rf(tmp_dir) }

  unless USERNAME.match(/^[A-Za-z0-9._]{1,24}$/)
    STDERR.puts "Invalid TikTok username"
    exit 64
  end

  valid_formats = [
    'hls-origin/hls-pull/hls-uhd_60/hls-hd_60/hls-hd/hls-sd/hls-ld/flv-origin/flv-hd/flv-ld',
    'hls-uhd_60/hls-hd_60/hls-hd/hls-sd/hls-ld/flv-hd/flv-ld',
    'hls-hd_60/hls-hd/hls-sd/hls-ld/flv-hd/flv-ld',
    'hls-hd/hls-sd/hls-ld/flv-hd/flv-sd/flv-ld',
    'hls-sd/hls-ld/flv-sd/flv-ld',
    'hls-ld/flv-ld',
    'hls-origin/hls-hd/hls-sd/hls-ld/hls-pull/flv-origin/flv-hd/flv-ld'
  ]

  unless valid_formats.include?(FORMAT)
    STDERR.puts "Invalid yt-dlp format"
    exit 64
  end

  LOAD_PER_CPU = get_load_per_cpu
  MAX_LOAD = ENV['TIKTOK_MAX_LOAD_PER_CPU']&.to_f || 1.5

  if LOAD_PER_CPU > MAX_LOAD
    emit_json(false, 'yt-dlp', USERNAME, '', FORMAT, 'host overloaded', TIMESTAMP, 'overloaded')
    STDERR.puts JSON.generate({
      'success' => false,
      'method' => 'yt-dlp',
      'username' => USERNAME,
      'url' => '',
      'format' => FORMAT,
      'error' => 'host overloaded',
      'timestamp' => TIMESTAMP,
      'status' => 'overloaded'
    }.reject { |_, v| v.nil? || v.empty? })
    exit 75
  end

  unless system('which yt-dlp > /dev/null 2>&1')
    emit_json(false, 'yt-dlp', USERNAME, '', FORMAT, 'yt-dlp not installed', TIMESTAMP, 'dependency_missing')
    STDERR.puts JSON.generate({
      'success' => false,
      'method' => 'yt-dlp',
      'username' => USERNAME,
      'url' => '',
      'format' => FORMAT,
      'error' => 'yt-dlp not installed',
      'timestamp' => TIMESTAMP,
      'status' => 'dependency_missing'
    }.reject { |_, v| v.nil? || v.empty? })
    exit 2
  end

  LIVE_URL = "https://www.tiktok.com/@#{USERNAME}/live"
  stdout_file = File.join(tmp_dir, 'stdout.json')
  stderr_file = File.join(tmp_dir, 'stderr.log')

  cmd = ['yt-dlp', '--no-warnings', '--dump-single-json', '--skip-download', '--format', FORMAT, LIVE_URL]
  Open3.popen3(*cmd) do |stdin, stdout, stderr, wait_thr|
    stdin.close
    stdout_data = stdout.read
    stderr_data = stderr.read
    wait_thr.join
    exit_code = wait_thr.value.exitstatus
    
    File.write(stdout_file, stdout_data)
    File.write(stderr_file, stderr_data)
    
    if exit_code != 0
      if stderr_data.match?(/not currently live|No live cdn found|not available|private video/i)
        status = 'offline'
        code = 1
      else
        status = 'technical_error'
        code = 2
      end
      
      error_msg = stderr_data[0, 1000]
      emit_json(false, 'yt-dlp', USERNAME, '', FORMAT, error_msg, TIMESTAMP, status)
      STDERR.puts JSON.generate({
        'success' => false,
        'method' => 'yt-dlp',
        'username' => USERNAME,
        'url' => '',
        'format' => FORMAT,
        'error' => error_msg,
        'timestamp' => TIMESTAMP,
        'status' => status
      }.reject { |_, v| v.nil? || v.empty? })
      exit code
    end
  end

  json_data = JSON.parse(File.read(stdout_file))
  candidates = []
  
  candidates << json_data['url'] if json_data['url'].is_a?(String)
  
  if json_data['formats'].is_a?(Array)
    json_data['formats'].each do |item|
      candidates << item['url'] if item.is_a?(Hash) && item['url'].is_a?(String)
    end
  end
  
  URL = nil
  candidates.each do |value|
    low = value.downcase
    if value.start_with?('https://') && (low.include?('.m3u8') || low.include?('.flv')) && !low.include?('only_audio=1')
      URL = value
      break
    end
  end

  if URL.nil?
    emit_json(false, 'yt-dlp', USERNAME, '', FORMAT, 'could not extract HTTPS video URL', TIMESTAMP, 'offline')
    STDERR.puts JSON.generate({
      'success' => false,
      'method' => 'yt-dlp',
      'username' => USERNAME,
      'url' => '',
      'format' => FORMAT,
      'error' => 'could not extract HTTPS video URL',
      'timestamp' => TIMESTAMP,
      'status' => 'offline'
    }.reject { |_, v| v.nil? || v.empty? })
    exit 1
  end

  if JSON_FLAG == '--json'
    emit_json(true, 'yt-dlp', USERNAME, URL, FORMAT, '', TIMESTAMP, 'live')
  else
    puts URL
  end
end
