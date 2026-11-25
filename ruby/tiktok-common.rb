#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "19868f11ea937c43f30b26a44b71e18b76adf43945f518e0275c1f35341f78ce", "source_sha256": "23879e22856f8bcfb0ddda7c9b1d7b0d7f3af474cea8620c1f7c10511ef03ed5", "target_language": "ruby"}
# tiktok-common.js — portiert nach ruby
# Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live/scripts/tiktok-common.js
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

# Shared TikTok LIVE safety contract: handle normalization, per-CPU load
# preflight, exact account LIVE selectors, strict HTTPS TikTok-CDN FLV
# validation, and normalized extractor statuses.

require 'json'
require 'uri'

DEFAULT_MAX_LOAD_PER_CPU = 1.5
USERNAME_PATTERN = /^[A-Za-z0-9._]{1,24}$/
FAILURE_STATUSES = Set.new([
  'offline',
  'restricted',
  'overloaded',
  'dependency_missing',
  'technical_error'
])

def normalize_username(raw)
  username = (raw || '').to_s.strip.gsub(/^@+/, '')
  unless USERNAME_PATTERN.match?(username)
    raise ArgumentError, 'Invalid TikTok username; expected 1-24 letters, digits, dots, or underscores'
  end
  username
end

def load_state(env = ENV)
  cpu_count = [1, ENV['TIKTOK_TEST_CPU_COUNT']&.to_i || Etc.nprocessors].max
  observed_raw = env['TIKTOK_TEST_LOAD_PER_CPU']
  observed = observed_raw.nil? ? (ENV['TIKTOK_TEST_LOADAVG']&.to_f || 0.0) / cpu_count : observed_raw.to_f
  maximum_raw = env['TIKTOK_MAX_LOAD_PER_CPU']
  maximum = maximum_raw.nil? ? DEFAULT_MAX_LOAD_PER_CPU : maximum_raw.to_f
  
  unless observed.finite? && maximum.finite? && maximum > 0
    raise ArgumentError, 'Invalid TikTok load configuration'
  end
  
  {
    overloaded: observed > maximum,
    load_per_cpu: observed,
    maximum: maximum
  }
end

def enforce_load_limit(method)
  state = load_state
  return state unless state[:overloaded]
  
  STDERR.puts JSON.generate({
    status: 'overloaded',
    method: method,
    load_per_cpu: state[:load_per_cpu].round(3),
    maximum: state[:maximum],
    message: 'Host is overloaded; retry on another node or later'
  })
  exit 75
end

def live_href_selectors(username)
  href = "/@#{username}/live"
  ["a[href=\"#{href}\"]", "a[href^=\"#{href}?\"]"]
end

def is_allowed_stream_url(value)
  begin
    uri = URI.parse(value)
    hostname = uri.hostname&.downcase
    return false unless uri.scheme == 'https'
    return false unless uri.path.downcase.include?('.flv')
    !!(hostname =~ /(^|\.)tiktokcdn(?:-[a-z0-9-]+)?\.com$/)
  rescue URI::InvalidURIError
    false
  end
end

def is_successful_stream_response(status, value)
  status.is_a?(Integer) &&
    status >= 200 &&
    status < 300 &&
    is_allowed_stream_url(value)
end

# Order matters: longer keys first so `_uhd_60` never matches as `hd_60`/`hd`.
QUALITY_URL_PATTERN = /_(uhd_60|hd_60|origin|hd|sd|ld|ao)\.(?:flv|m3u8)/

def quality_key_from_url(value)
  begin
    match = URI.parse(value).path.downcase.match(QUALITY_URL_PATTERN)
    match ? match[1] : nil
  rescue URI::InvalidURIError
    nil
  end
end

def normalize_extractor_result(value, method, username)
  technical_error = {
    success: false,
    status: 'technical_error',
    method: method,
    username: username,
    message: 'invalid extractor result'
  }
  
  return technical_error unless value.is_a?(Hash)
  return technical_error if value.key?(:success) && value[:success] != true && value[:success] != false
  
  if value[:success] == true
    if value[:status] != 'live' || !is_allowed_stream_url(value[:url])
      return technical_error
    end
    return value.merge(success: true, status: 'live')
  end
  
  if value[:success] != false
    return technical_error
  end
  
  result = value.dup
  result[:success] = false
  result[:status] = FAILURE_STATUSES.include?(value[:status]) ? value[:status] : 'technical_error'
  result[:method] = value[:method].is_a?(String) ? value[:method] : method
  result[:username] = value[:username].is_a?(String) ? value[:username] : username
  
  result.delete(:url)
  result.delete(:streams)
  result.delete(:allUrls)
  
  result
end

def classify_final_failure(results)
  statuses = results.map { |result| result && result[:status] }.select { |status| FAILURE_STATUSES.include?(status) }.to_set
  
  return 'overloaded' if statuses.include?('overloaded')
  return 'restricted' if statuses.include?('restricted')
  return 'technical_error' if statuses.include?('technical_error')
  return 'offline' if statuses.include?('offline')
  return 'dependency_missing' if statuses.include?('dependency_missing')
  'technical_error'
end

def exit_code_for_result(result)
  return 0 if result && result[:success] == true && result[:status] == 'live'
  return 75 if result && result[:status] == 'overloaded'
  return 1 if result && ['offline', 'restricted'].include?(result[:status])
  2
end

def classify_direct_live_state(options)
  username = options[:username]
  current_path = options[:currentPath]
  title = options[:title]
  body_text = options[:bodyText]
  successful_stream_response = options[:successfulStreamResponse]
  
  expected_path = "/@#{username}/live"
  if current_path != expected_path
    return { status: 'offline', reason: 'target live page redirected' }
  end
  
  if successful_stream_response
    return { status: 'live', reason: 'successful TikTok CDN stream response' }
  end
  
  normalized_body = (body_text || '').gsub(/\s+/, ' ').downcase
  normalized_title = (title || '').downcase
  account_live_title = normalized_title.include?("@#{username.downcase}) is live")
  
  ended_markers = [
    'live has ended',
    'das live ist beendet',
    'live wurde beendet',
    'dieses live ist beendet',
    'stream has ended'
  ]
  
  if ended_markers.any? { |marker| normalized_body.include?(marker) }
    return { status: 'offline', reason: 'target live page reports ended stream' }
  end
  
  restriction_markers = [
    'dieses live enthält themen, die von einigen als unangenehm empfunden werden könnten',
    'melde dich an, um das beste aus deiner tiktok-erfahrung herauszuholen',
    'bei tiktok anmelden',
    'melde dich an für das volle live-erlebnis',
    'melde dich an für das vollständige erlebnis',
    'this live may contain content that could be uncomfortable',
    'log in to tiktok',
    'log in for the full live experience',
    'mature content',
    'age-restricted',
    'viewer discretion'
  ]
  
  if account_live_title && restriction_markers.any? { |marker| normalized_body.include?(marker) }
    return { status: 'restricted', reason: 'target live page requires authentication' }
  end
  
  if account_live_title
    return {
      status: 'restricted',
      reason: 'target is live but no accessible media response was available'
    }
  end
  
  { status: 'offline', reason: 'no account-specific live signal' }
end

def forced_offline(method, username)
  return false unless ENV['TIKTOK_TEST_OFFLINE'] == '1'
  
  STDERR.puts JSON.generate({
    success: false,
    status: 'offline',
    method: method,
    username: username,
    message: 'forced offline test mode'
  })
  true
end

module TikTokCommon
  module_function :classify_direct_live_state, :classify_final_failure, :enforce_load_limit, 
                  :exit_code_for_result, :forced_offline, :is_allowed_stream_url, 
                  :is_successful_stream_response, :live_href_selectors, :load_state, 
                  :normalize_extractor_result, :normalize_username, :quality_key_from_url
end
