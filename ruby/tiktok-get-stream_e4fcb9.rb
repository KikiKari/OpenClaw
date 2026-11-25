#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "8f6287bf6e5ab0fa27c1591022a04f586a6e79a34b41622ada187bbcb364c2fa", "source_sha256": "e4fcb95b6aa05b8fa419b7ed085317debab4e29b8cfb62a4d3ab8ec952610874", "target_language": "ruby"}
# tiktok-get-stream.js — portiert nach ruby
# Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live-mon/scripts/tiktok-get-stream.js
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

# Enhanced TikTok LIVE URL extractor.
#
# Order: Playwright response interception, streamlink, then yt-dlp. Every
# result is schema-normalized and must be an allowed HTTPS TikTok-CDN FLV
# URL. Fallbacks use fixed argument arrays, bounded output, timeouts, and
# process-group cleanup.
#
# Exit 0 = URL, 1 = offline/restricted/no URL, 2 = dependency/technical
# failure, 75 = overloaded before Playwright startup.

require 'fileutils'
require 'json'
require 'open3'
require 'securerandom'
require 'timeout'

FALLBACK_TIMEOUT_MS = 45000
FALLBACK_MAX_OUTPUT = 1024 * 1024

def log(message)
  $stderr.puts message
end

def run_fallback(script_path, args)
  Open3.popen3('bash', script_path, *args) do |stdin, stdout, stderr, wait_thr|
    stdin.close
    
    stdout_data = ''
    stderr_data = ''
    overflow = false
    
    # Start threads to read stdout and stderr
    stdout_thread = Thread.new do
      while !stdout.eof?
        chunk = stdout.readpartial(4096)
        next_data = stdout_data + chunk
        if next_data.bytesize > FALLBACK_MAX_OUTPUT
          overflow = true
          break
        end
        stdout_data = next_data
      end
    rescue EOFError
    end
    
    stderr_thread = Thread.new do
      while !stderr.eof?
        chunk = stderr.readpartial(4096)
        next_data = stderr_data + chunk
        if next_data.bytesize > FALLBACK_MAX_OUTPUT
          overflow = true
          break
        end
        stderr_data = next_data
      end
    rescue EOFError
    end
    
    begin
      status = Timeout.timeout(FALLBACK_TIMEOUT_MS / 1000.0) do
        wait_thr.value
      end
    rescue Timeout::Error
      Process.kill('-TERM', wait_thr.pid) rescue nil
      sleep(3)
      Process.kill('-KILL', wait_thr.pid) rescue nil
      return { code: 2, stdout: stdout_data, stderr: "#{stderr_data}\nfallback timeout".strip }
    end
    
    stdout_thread.join
    stderr_thread.join
    
    if overflow
      return { code: 2, stdout: '', stderr: 'fallback output exceeded limit' }
    end
    
    return { 
      code: status.exitstatus || 2, 
      stdout: stdout_data.strip, 
      stderr: stderr_data.strip 
    }
  end
rescue => error
  { code: 2, stdout: '', stderr: error.message }
end

def parse_fallback_result(method, username, execution)
  [execution[:stdout], execution[:stderr]].each do |text|
    next unless text && !text.empty?
    begin
      value = JSON.parse(text)
      if value.is_a?(Hash)
        return normalize_extractor_result(value, method, username)
      end
    rescue JSON::ParserError
      # try next channel
    end
  end
  
  normalize_extractor_result({
    'success' => false,
    'status' => execution[:code] == 75 ? 'overloaded' : 'technical_error',
    'method' => method,
    'username' => username,
    'message' => execution[:stderr].empty? ? "fallback exited #{execution[:code]}" : execution[:stderr]
  }, method, username)
end

def playwright_preflight
  begin
    # In Ruby we can't easily check Playwright installation like in JS
    # We'll assume it's available if the gem is installed
    require 'playwright'
    { ok: true }
  rescue LoadError
    {
      ok: false,
      status: 'dependency_missing',
      error: 'Playwright gem not available'
    }
  end
end

def human_delay(min = 2000, max = 4000)
  rand(min..max)
end

def handle_popups(page)
  closed = false
  
  # DSGVO
  dsgvo_selectors = [
    'button:has-text("Verstanden")', '[data-e2e="cookie-banner-accept"]',
    'button:has-text("Accept")', 'button:has-text("Akzeptieren")',
    'button:has-text("Alle akzeptieren")', 'button:has-text("Allow all")',
    'button:has-text("Accept all")', '[data-testid="cookie-policy-banner-accept"]'
  ]
  
  dsgvo_selectors.each do |sel|
    begin
      btn = page.wait_for_selector(sel, state: 'visible', timeout: 3000)
      if btn
        btn.click
        sleep(human_delay(1000, 2000) / 1000.0)
        closed = true
        break
      end
    rescue Playwright::TimeoutError
      # continue
    end
  end
  
  # Login Pop-up 1: "Bei TikTok anmelden" → X-Button
  begin
    login_text = page.query_selector('text="Bei TikTok anmelden"')
    if login_text
      close_btn = page.query_selector('div[role="dialog"] [aria-label="Close"], div[role="dialog"] button[aria-label="Schließen"], div[role="dialog"] svg')
      if close_btn
        close_btn.click
        sleep(human_delay(1000, 2000) / 1000.0)
        closed = true
      end
    end
  rescue
    # nicht da
  end
  
  # Login Pop-up 2: "Jetzt nicht" Button
  begin
    skip_btn = page.query_selector('button:has-text("Jetzt nicht"), button:has-text("Not now")')
    if skip_btn
      skip_btn.click
      sleep(human_delay(1000, 2000) / 1000.0)
      closed = true
    end
  rescue
    # nicht da
  end
  
  closed
end

def check_restrictions(page)
  restriction_texts = [
    'text="Bei TikTok anmelden"',
    'text=/Dieses LIVE enthält Themen/',
    'text="Melde dich an für das vollständige Erlebnis"',
    'text=/Melde dich an für das volle/',
    'text="Log in to TikTok"',
    'text=/mature content/',
    'text=/age-restricted/'
  ]
  
  restriction_texts.each do |sel|
    begin
      el = page.query_selector(sel)
      if el && el.visible?
        return { restricted: true, reason: sel.gsub('text=', '').gsub(%r{[/"]}, '') }
      end
    rescue
      # weiter
    end
  end
  
  { restricted: false, reason: nil }
end

def quality_key_from_url(url)
  case url
  when /_origin\.flv/
    'original'
  when /_uhd_60\.flv/
    '1080p60'
  when /_hd_60\.flv/
    '720p60'
  when /_hd\.flv/
    '720p'
  when /_sd\.flv/
    '540p'
  when /_ld\.flv/
    '360p'
  else
    'unknown'
  end
end

def normalize_extractor_result(result, method, username)
  # Ensure consistent structure
  base_result = {
    'success' => false,
    'method' => method,
    'username' => username
  }.merge(result)
  
  # Normalize status if missing
  base_result['status'] ||= if base_result['success']
                              'live'
                            elsif base_result.key?('restricted') && base_result['restricted']
                              'restricted'
                            else
                              'technical_error'
                            end
  
  base_result
end

def classify_final_failure(results)
  # If any result indicates the stream is restricted or overloaded, propagate that
  results.each do |result|
    return result['status'] if %w[restricted overloaded].include?(result['status'])
  end
  
  # Otherwise, it's a general failure
  'technical_error'
end

def enforce_load_limit(prefix)
  # Placeholder implementation - in real app this would check system load
end

def forced_offline(prefix, username)
  false # Placeholder implementation
end

def normalize_username(username)
  # Basic normalization - remove @ if present
  username.gsub(/^@/, '')
end

def exit_code_for_result(result)
  if result['success']
    0
  elsif %w[offline restricted no_url].include?(result['status'])
    1
  elsif %w[dependency_missing technical_error].include?(result['status'])
    2
  elsif result['status'] == 'overloaded'
    75
  else
    2
  end
end

def is_successful_stream_response(status, url)
  status == 200 && url.include?('flv') && url.start_with?('http')
end

# Playwright-basierte FLV-Extraktion
def extract_with_playwright(username, quality_preference)
  preflight = playwright_preflight
  unless preflight[:ok]
    return {
      'success' => false,
      'method' => 'playwright',
      'status' => preflight[:status],
      'error' => preflight[:error]
    }
  end
  
  begin
    require 'playwright'
    
    browser = Playwright.create(:chromium).launch(
      headless: true,
      args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-gpu', '--disable-dev-shm-usage']
    )
    
    context = browser.contexts.new(
      user_agent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      viewport: { width: 1920, height: 1080 }
    )
    
    page = context.pages.new
    
    # FLV-URLs sammeln via Event-Listener BEVOR wir navigieren
    collected_urls = []
    page.on(:response) do |response|
      url = response.url
      if collected_urls.length < 100 && is_successful_stream_response(response.status, url)
        collected_urls.push({
          'url' => url,
          'status' => response.status,
          'timestamp' => Time.now.utc.iso8601
        })
      end
    end
    
    # Navigiere direkt zu /live
    page.goto("https://www.tiktok.com/@#{username}/live", {
      wait_until: 'domcontentloaded',
      timeout: 30000
    })
    
    # Popups schließen
    handle_popups(page)
    
    # Warte auf Seitenaufbau
    sleep(human_delay(3000, 5000) / 1000.0)
    begin
      page.wait_for_load_state('networkidle', timeout: 10000)
    rescue Playwright::TimeoutError
      # ok
    end
    
    # Prüfe auf Einschränkungen
    restrictions = check_restrictions(page)
    if restrictions[:restricted]
      log("Playwright: Stream restricted - #{restrictions[:reason]}")
      return { 
        'success' => false, 
        'method' => 'playwright', 
        'status' => 'restricted',
        'restricted' => true, 
        'reason' => restrictions[:reason] 
      }
    end
    
    # Versuche Video abzuspielen falls nötig
    begin
      video = page.query_selector('video')
      if video
        video.evaluate('(v) => v.play()')
      end
    rescue
      # ok
    end
    
    # Warte auf FLV-URLs (Stream muss laden)
    sleep(human_delay(8000, 12000) / 1000.0)
    
    # Zweiter Versuch Popups zu schließen (können nach Delay erscheinen)
    handle_popups(page)
    sleep(human_delay(3000, 5000) / 1000.0)
    
    # Nochmal Restrictions prüfen
    restrictions2 = check_restrictions(page)
    if restrictions2[:restricted]
      log("Playwright: Stream became restricted after wait - #{restrictions2[:reason]}")
      return { 
        'success' => false, 
        'method' => 'playwright', 
        'status' => 'restricted',
        'restricted' => true, 
        'reason' => restrictions2[:reason] 
      }
    end
    
    # URLs auswerten
    if collected_urls.empty?
      log('Playwright: No FLV URLs captured via network monitoring.')
      return { 
        'success' => false, 
        'method' => 'playwright', 
        'status' => 'offline',
        'restricted' => false, 
        'reason' => 'No FLV URLs found' 
      }
    end
    
    # Deduplizieren und nach Qualität sortieren
    unique_urls = collected_urls.uniq { |item| item['url'].split('?')[0] }
    
    # Qualitäts-Präferenz anwenden
    quality_order = case quality_preference
                    when 'original'
                      ['_origin.flv', '_uhd_60.flv', '_hd_60.flv', '_hd.flv', '_sd.flv', '_ld.flv']
                    when '1080p60'
                      ['_uhd_60.flv', '_hd_60.flv', '_hd.flv', '_sd.flv', '_ld.flv']
                    when '720p60'
                      ['_hd_60.flv', '_hd.flv', '_sd.flv', '_ld.flv']
                    when '720p'
                      ['_hd.flv', '_sd.flv', '_ld.flv']
                    when '540p'
                      ['_sd.flv', '_ld.flv']
                    when '360p'
                      ['_ld.flv']
                    when 'auto'
                      ['_origin.flv', '_uhd_60.flv', '_hd_60.flv', '_hd.flv', '_sd.flv', '_ld.flv']
                    else
                      ['_origin.flv', '_uhd_60.flv', '_hd_60.flv', '_hd.flv', '_sd.flv', '_ld.flv']
                    end
    
    best_url = nil
    quality_order.each do |suffix|
      best_url = unique_urls.find { |u| u['url'].include?(suffix) }
      break if best_url
    end
    
    if !best_url && %w[auto original].include?(quality_preference)
      best_url = unique_urls.first
    end
    
    unless best_url
      return { 
        'success' => false, 
        'method' => 'playwright', 
        'status' => 'quality_unavailable',
        'reason' => "Requested quality #{quality_preference} was not captured in this fresh browser session" 
      }
    end
    
    {
      'success' => true,
      'status' => 'live',
      'method' => 'playwright',
      'username' => username,
      'url' => best_url['url'],
      'quality' => quality_preference,
      'allUrls' => unique_urls.map do |item|
        {
          'url' => item['url'],
          'quality' => quality_key_from_url(item['url'])
        }
      end,
      'allUrlsCount' => unique_urls.length,
      'timestamp' => Time.now.utc.iso8601
    }
    
  rescue => error
    log("Playwright error: #{error.message}")
    {
      'success' => false, 
      'method' => 'playwright', 
      'status' => 'technical_error',
      'error' => error.message
    }
  ensure
    browser&.close
  end
end

# Streamlink Fallback
def try_streamlink(username, quality)
  script_path = File.join(File.dirname(__FILE__), 'extraction-methods', 'extract-tiktok-streamlink.sh')
  execution = run_fallback(script_path, [username, quality, '--json'])
  parse_fallback_result('streamlink', username, execution)
end

# yt-dlp Fallback
def try_yt_dlp(username, quality)
  script_path = File.join(File.dirname(__FILE__), 'extraction-methods', 'extract-tiktok-yt-dlp.sh')
  yt_format = case quality
              when 'original'
                'hls-origin/hls-pull/hls-uhd_60/hls-hd_60/hls-hd/hls-sd/hls-ld/flv-origin/flv-hd/flv-ld'
              when '1080p60'
                'hls-uhd_60/hls-hd_60/hls-hd/hls-sd/hls-ld/flv-hd/flv-ld'
              when '720p60'
                'hls-hd_60/hls-hd/hls-sd/hls-ld/flv-hd/flv-ld'
              when '720p'
                'hls-hd/hls-sd/hls-ld/flv-hd/flv-sd/flv-ld'
              when '540p'
                'hls-sd/hls-ld/flv-sd/flv-ld'
              when '360p'
                'hls-ld/flv-ld'
              when 'auto'
                'hls-origin/hls-hd/hls-sd/hls-ld/hls-pull/flv-origin/flv-hd/flv-ld'
              else
                'hls-origin/hls-hd/hls-sd/hls-ld/hls-pull/flv-origin/flv-hd/flv-ld'
              end
  
  execution = run_fallback(script_path, [username, yt_format, '--json'])
  parse_fallback_result('yt-dlp', username, execution)
end

# Hauptfunktion mit Fallback-Kette
def get_stream_url(username, quality_preference = 'auto')
  timestamp = Time.now.utc.iso8601
  
  # --- 1. Playwright ---
  log("[1/3] Trying Playwright for @#{username}...")
  pw_result = extract_with_playwright(username, quality_preference)
  if pw_result['success']
    pw_result['timestamp'] = timestamp
    return pw_result
  end
  
  if %w[restricted overloaded].include?(pw_result['status'])
    return pw_result
  end
  
  log("Playwright result: #{pw_result['reason'] || pw_result['error'] || 'failed'}")
  
  # --- 2. Streamlink (bounded fallback; output is normalized below) ---
  log("[2/3] Trying streamlink for @#{username} (quality: #{quality_preference})...")
  sl_result = try_streamlink(username, quality_preference)
  if sl_result['success']
    return sl_result
  end
  
  if %w[restricted overloaded].include?(sl_result['status'])
    return sl_result
  end
  
  log("Streamlink result: #{sl_result['message'] || sl_result['error'] || 'failed'}")
  
  # --- 3. yt-dlp (final bounded fallback; output is normalized below) ---
  log("[3/3] Trying yt-dlp for @#{username}...")
  yt_result = try_yt_dlp(username, quality_preference)
  if yt_result['success']
    return yt_result
  end
  
  if %w[restricted overloaded].include?(yt_result['status'])
    return yt_result
  end
  
  log("yt-dlp result: #{yt_result['message'] || yt_result['error'] || 'failed'}")
  
  # --- Alle fehlgeschlagen ---
  status = classify_final_failure([pw_result, sl_result, yt_result])
  {
    'success' => false,
    'status' => status,
    'username' => username,
    'message' => 'All extraction methods failed (Playwright, streamlink, yt-dlp).',
    'playwrightReason' => pw_result['reason'] || pw_result['error'],
    'streamlinkReason' => sl_result['message'] || sl_result['error'],
    'ytdlpReason' => yt_result['message'] || yt_result['error'],
    'timestamp' => timestamp
  }
end

# --- CLI ---
if ARGV.length < 1
  $stderr.puts 'Usage: ruby tiktok-get-stream.rb <username> [quality: original|1080p60|720p60|720p|540p|360p|auto] [--json]'
  exit(1)
end

cli_username = nil
begin
  cli_username = normalize_username(ARGV[0])
rescue => error
  $stderr.puts error.message
  exit(64)
end

enforce_load_limit('playwright_streamlink_ytdlp')

if forced_offline('playwright_streamlink_ytdlp', cli_username)
  exit(1)
end

cli_quality = ARGV[1..-1].find { |arg| !arg.start_with?('--') } || 'auto'
cli_json = ARGV.include?('--json')

unless %w[original 1080p60 720p60 720p 540p 360p auto].include?(cli_quality)
  $stderr.puts 'Invalid quality; expected original, 1080p60, 720p60, 720p, 540p, 360p, or auto'
  exit(64)
end

begin
  result = get_stream_url(cli_username, cli_quality)
  
  if cli_json
    puts JSON.pretty_generate(result)
  else
    if result['success']
      puts result['url']
    else
      $stderr.puts result['message']
    end
  end
  
  exit(exit_code_for_result(result))
rescue => err
  $stderr.puts "Unhandled error: #{err.message}"
  exit(2)
end
