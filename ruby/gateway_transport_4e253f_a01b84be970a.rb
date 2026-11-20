#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "a84609da08ebe535aa81528bbba8267a9688489264b2da00b4471cb877b9cf64", "source_sha256": "4e253f02b715d7d8ae256f0b72f993ca4646b5e466c1f39a9d5e2d3864a4fe77", "target_language": "ruby"}
# gateway_transport.py — portiert nach ruby
# Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/gateway_transport.py
# auch in: workspace@local:skills/script-abstractions-manager/scripts/gateway_transport.py
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

# frozen_string_literal: true

# Gateway-authenticated transport with manager-owned attempt records.
#
# An attempt is saved before submission. If its outcome is uncertain, subsequent
# calls only query the same node and attempt; they do not submit it again.

require 'json'
require 'net/http'
require 'securerandom'
require 'uri'
require 'time'

class TransportUnresolved < RuntimeError
end

def gateway_token
  # Use the local Gateway credential without changing its configuration.
  token = ENV['OPENCLAW_GATEWAY_TOKEN']&.strip
  return token unless token.nil? || token.empty?

  path_env = ENV['OPENCLAW_CONFIG_PATH']
  path = if path_env.nil?
           File.join(Dir.home, '.openclaw', 'openclaw.json')
         else
           path_env
         end

  begin
    config = JSON.parse(File.read(path, encoding: 'utf-8'))
    token = config.dig('gateway', 'auth', 'token')
  rescue StandardError
    return ''
  end

  return '' unless token.is_a?(String) && !token.start_with?('${')

  token.strip
end

class GatewayTransport
  def initialize(state, save, url, token, timeout: 3900, interval: 3, http_class: Net::HTTP, clock: -> { Time.now.to_f }, sleep_func: ->(seconds) { sleep(seconds) })
    uri = URI.parse(url)
    raise ArgumentError, 'invalid Gateway URL' unless %w[http https].include?(uri.scheme) && !uri.host.nil?
    raise ArgumentError, 'unencrypted Gateway must use loopback' if uri.scheme == 'http' && !%w[127.0.0.1 localhost ::1].include?(uri.host)
    raise ArgumentError, 'Gateway token and positive timeouts required' if token.strip.empty? || timeout <= 0 || interval <= 0

    @state = state
    @save = save
    @url = url
    @token = token.strip
    @timeout = timeout
    @interval = interval
    @http_class = http_class
    @clock = clock
    @sleep_func = sleep_func
  end

  def _request(node, request, device_id = nil)
    payload = {
      'node' => node,
      'device_id' => device_id,
      'request' => request
    }.to_json.force_encoding('UTF-8')

    uri = URI.parse(@url)
    http = @http_class.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    
    req = Net::HTTP::Post.new(uri.path.empty? ? '/' : uri.path)
    req['Authorization'] = "Bearer #{@token}"
    req['Content-Type'] = 'application/json'
    req.body = payload

    timeout = node == 'node4' ? 150 : 40
    
    begin
      response = http.request(req)
      raw = response.body
      
      raise ArgumentError, 'response too large' if raw.bytesize > 4_000_000
      
      data = JSON.parse(raw)
      
      raise ArgumentError, 'invalid gateway response' unless data.is_a?(Hash) && data.key?('result')
      raise ArgumentError, 'gateway device identity mismatch' if !device_id.nil? && data['device_id'] != device_id
      
      data['result']
    rescue StandardError => e
      raise TransportUnresolved, 'Gateway request failed' unless e.is_a?(TransportUnresolved)
      raise
    end
  end

  def available
    result = _request('node1', { 'operation' => 'availability' })
    raise TransportUnresolved, 'invalid node availability' unless result.is_a?(Hash)
    result
  end

  def _release(original, entry)
    return if entry['released']

    begin
      result = _request(
        original['selected_node'],
        {
          'operation' => 'release',
          'job_id' => original['job_id'],
          'attempt_id' => original['attempt_id']
        },
        original['selected_device_id']
      )
    rescue TransportUnresolved
      return # Retry cleanup later; the result is durable in manager state.
    end

    if result.is_a?(Hash) && result['status'] == 'released' &&
       %w[job_id attempt_id selected_node target_language].all? { |key| result[key] == original[key] }
      entry['released'] = true
      @save.call(@state)
    end
  end

  def release_pending
    (@state['auftraege'] || {}).each_value do |entry|
      if entry.is_a?(Hash) && %w[completed rejected failed].include?(entry['status']) && entry['job'].is_a?(Hash)
        _release(entry['job'], entry)
      end
    end
  end

  def reject(job, reason)
    # Record a completed response rejected by validation, before retrying it.
    key = "#{job['source_sha256']}:#{job['target_language']}"
    entry = @state.dig('auftraege', key)
    return unless entry.is_a?(Hash) && entry['status'] == 'completed'
    raise TransportUnresolved, 'rejected attempt identity mismatch' if entry.dig('job', 'attempt_id') != job['attempt_id']

    entry['status'] = 'rejected'
    entry['validation_error'] = reason.to_s[0, 500]
    @save.call(@state)
  end

  def call(job)
    raise ArgumentError, 'missing source identity' unless job['source_sha256'] && job['target_language'] && job['selected_device_id']

    key = "#{job['source_sha256']}:#{job['target_language']}"
    entries = @state['auftraege'] ||= {}
    entry = entries[key]

    if entry.is_a?(Hash) && entry['status'] == 'rejected'
      _release(entry['job'], entry)
      raise TransportUnresolved, 'rejected attempt release is unresolved' unless entry['released']

      previous = entry
      original = job.merge('attempt_id' => SecureRandom.uuid)
      entry = {
        'job' => original,
        'status' => 'submitted',
        'previous_attempts' => (previous['previous_attempts'] || []) + [{
          'job_id' => previous.dig('job', 'job_id'),
          'attempt_id' => previous.dig('job', 'attempt_id'),
          'selected_node' => previous.dig('job', 'selected_node'),
          'validation_error' => previous['validation_error']
        }]
      }
      entries[key] = entry
      @save.call(@state)
      fresh = true
    else
      fresh = entry.nil?
    end

    if entry.nil?
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

    raise TransportUnresolved, 'attempt requires reconciliation' if %w[failed unknown].include?(entry['status'])

    status = nil
    if fresh
      begin
        status = _request(
          original['selected_node'],
          { 'operation' => 'execute', 'job' => original },
          original['selected_device_id']
        )
      rescue TransportUnresolved
        # The request may have been accepted. Query, never resend.
      end
    end

    deadline = @clock.call + @timeout
    loop do
      if status.nil?
        status = _request(
          original['selected_node'],
          {
            'operation' => 'status',
            'job_id' => original['job_id'],
            'attempt_id' => original['attempt_id']
          },
          original['selected_device_id']
        )
      end

      raise TransportUnresolved, 'attempt is not known by the node' unless status.is_a?(Hash)
      raise TransportUnresolved, 'status identity mismatch' if %w[job_id attempt_id selected_node target_language].any? { |k| status[k] != original[k] }

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
        _release(original, entry) if state == 'failed'
        raise TransportUnresolved, 'attempt requires reconciliation'
      end

      raise TransportUnresolved, 'attempt is unresolved' if state != 'running' || @clock.call >= deadline

      @sleep_func.call(@interval)
      status = nil
    end
  end
end
