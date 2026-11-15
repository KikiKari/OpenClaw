#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "16616abf7094ace38a39096ee02a3e4536bf10826c338756c2505019778bbd83", "source_sha256": "0cfda5c5495fad1eb8cbf8562ac3b851f251f1a3645890dc28e6f870336a28b5", "target_language": "ruby"}
# gateway_transport.py — portiert nach ruby
# Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/gateway_transport.py
# Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

# Gateway-authenticated transport with manager-owned attempt records.
#
# An attempt is saved before submission. If its outcome is uncertain, subsequent
# calls only query the same node and attempt; they do not submit it again.

require 'json'
require 'net/http'
require 'uri'
require 'securerandom'
require 'pathname'
require 'time'

class TransportUnresolved < RuntimeError
end

def gateway_token
  # Use the local Gateway credential without changing its configuration.
  token = ENV['OPENCLAW_GATEWAY_TOKEN']&.strip
  return token if token && !token.empty?

  config_path = ENV['OPENCLAW_CONFIG_PATH']
  path = config_path ? Pathname.new(config_path) : (Pathname.home / '.openclaw/openclaw.json')
  
  begin
    config = JSON.parse(path.read(Encoding::UTF_8))
    token = config.dig('gateway', 'auth', 'token')
    return '' unless token.is_a?(String) && !token.start_with?('${')
    token.strip
  rescue StandardError
    ''
  end
end

class GatewayTransport
  def initialize(state, save, url, token, timeout: 3900, interval: 3, 
                 opener: method(:default_opener), clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }, 
                 sleep: ->(duration) { Kernel.sleep(duration) })
    
    uri = URI.parse(url)
    unless %w[http https].include?(uri.scheme) && uri.host
      raise ArgumentError, 'invalid Gateway URL'
    end
    
    if uri.scheme == 'http' && !%w[127.0.0.1 localhost ::1].include?(uri.host)
      raise ArgumentError, 'unencrypted Gateway must use loopback'
    end
    
    if token.strip.empty? || timeout <= 0 || interval <= 0
      raise ArgumentError, 'Gateway token and positive timeouts required'
    end
    
    @state = state
    @save = save
    @url = url
    @token = token.strip
    @timeout = timeout
    @interval = interval
    @opener = opener
    @clock = clock
    @sleep = sleep
  end

  def call(job)
    unless job['source_sha256'] && job['target_language'] && job['selected_device_id']
      raise ArgumentError, 'missing source identity'
    end
    
    key = "#{job['source_sha256']}:#{job['target_language']}"
    entries = @state['auftraege'] ||= {}
    entry = entries[key]
    fresh = entry.nil?
    
    if fresh
      original = job.merge('attempt_id' => SecureRandom.uuid)
      entry = { 'job' => original, 'status' => 'submitted' }
      entries[key] = entry
      # If this write fails there must be no remote submission.
      @save.call(@state)
    end
    
    original = entry['job']
    # The dispatcher verifies the job object after transport returns.
    job.merge!(original)
    
    return entry['response'] if entry['response']
    
    if %w[failed unknown].include?(entry['status'])
      raise TransportUnresolved, 'attempt requires reconciliation'
    end
    
    status = nil
    if fresh
      begin
        status = _request(original['selected_node'], 
                         { 'operation' => 'execute', 'job' => original },
                         original['selected_device_id'])
      rescue TransportUnresolved
        # The request may have been accepted. Query, never resend.
      end
    end
    
    deadline = @clock.call + @timeout
    loop do
      if status.nil?
        status = _request(original['selected_node'],
                        { 'operation' => 'status',
                          'job_id' => original['job_id'],
                          'attempt_id' => original['attempt_id'] },
                        original['selected_device_id'])
      end
      
      unless status.is_a?(Hash)
        raise TransportUnresolved, 'attempt is not known by the node'
      end
      
      %w[job_id attempt_id selected_node target_language].each do |k|
        if status[k] != original[k]
          raise TransportUnresolved, 'status identity mismatch'
        end
      end
      
      state = status['status']
      if state == 'completed'
        response = status['response']
        unless response.is_a?(Hash) && response['status'] == 'ok' &&
               %w[job_id selected_node target_language].all? { |k| response[k] == original[k] } &&
               response['code'].is_a?(String) && !response['code'].strip.empty?
          raise TransportUnresolved, 'invalid translation result'
        end
        
        entry['response'] = response
        entry['status'] = 'completed'
        @save.call(@state)
        _release(original, entry)
        return response
      end
      
      if %w[failed unknown].include?(state)
        entry['status'] = state
        @save.call(@state)
        _release(original, entry)
        raise TransportUnresolved, 'attempt requires reconciliation'
      end
      
      if state != 'running' || @clock.call >= deadline
        raise TransportUnresolved, 'attempt is unresolved'
      end
      
      @sleep.call(@interval)
      status = nil
    end
  end

  def available
    result = _request('node1', { 'operation' => 'availability' })
    unless result.is_a?(Hash)
      raise TransportUnresolved, 'invalid node availability'
    end
    result
  end

  def release_pending
    (@state['auftraege'] || {}).each_value do |entry|
      if entry.is_a?(Hash) && %w[completed failed unknown].include?(entry['status']) && entry['job'].is_a?(Hash)
        _release(entry['job'], entry)
      end
    end
  end

  private

  def default_opener(request, timeout:)
    uri = URI(request.uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.open_timeout = timeout
    http.read_timeout = timeout
    http.request(request)
  end

  def _request(node, request, device_id = nil)
    payload = {
      'node' => node,
      'device_id' => device_id,
      'request' => request
    }.to_json.force_encoding(Encoding::UTF_8)
    
    uri = URI(@url)
    http_request = Net::HTTP::Post.new(uri)
    http_request['Authorization'] = "Bearer #{@token}"
    http_request['Content-Type'] = 'application/json'
    http_request.body = payload
    
    timeout = (node == 'node4') ? 150 : 40
    response = @opener.call(http_request, timeout: timeout)
    
    raw = response.body
    if raw.bytesize > 4_000_000
      raise ArgumentError, 'response too large'
    end
    
    data = JSON.parse(raw)
    unless data.is_a?(Hash) && data.key?('result')
      raise ArgumentError, 'invalid gateway response'
    end
    
    if device_id && data['device_id'] != device_id
      raise ArgumentError, 'gateway device identity mismatch'
    end
    
    data['result']
  rescue StandardError => error
    raise TransportUnresolved, 'Gateway request failed'
  end

  def _release(original, entry)
    return if entry['released']
    
    begin
      result = _request(original['selected_node'],
                       { 'operation' => 'release',
                         'job_id' => original['job_id'],
                         'attempt_id' => original['attempt_id'] },
                       original['selected_device_id'])
    rescue TransportUnresolved
      return # Retry cleanup later; the result is durable in manager state.
    end
    
    if result.is_a?(Hash) && result['status'] == 'released' &&
       %w[job_id attempt_id selected_node target_language].all? { |key| result[key] == original[key] }
      entry['released'] = true
      @save.call(@state)
    end
  end
end
