#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "fb845c9a460ff409fe2aa585c755e0db8ecb16c4d3864615e1677e8bb30ab1ef", "source_sha256": "bb3a3622a1b49888ef51f2b6fac687955ed97e97b6ee7a16d4e47117a764be29", "target_language": "ruby"}
# agent_runner.py — portiert nach ruby
# Quelle: python, workspace@local:skills/sub-agents-utils/scripts/agent_runner.py
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

# Run a gateway-only OpenClaw agent turn for a porting task.

require 'json'
require 'securerandom'
require 'open3'
require 'pathname'

def allowed_models(config_path)
  config = JSON.parse(File.read(config_path, encoding: 'utf-8'))
  defaults = config.dig('agents', 'defaults') || {}
  models = Set.new(defaults.dig('models') || [])
  selected = defaults.dig('model')
  if selected.is_a?(String)
    models.add(selected)
  elsif selected.is_a?(Hash)
    primary = selected['primary']
    fallbacks = selected['fallbacks'] || []
    models.merge([primary, *fallbacks].compact.select { |x| x.is_a?(String) })
  end
  models
end

def run(task, model, timeout)
  raise ArgumentError, 'task must contain 1–500 characters' unless task.strip.length.between?(1, 500)
  raise ArgumentError, 'timeout must be between 1 and 7200 seconds' unless timeout.between?(1, 7200)

  config_path = ENV['OPENCLAW_CONFIG'] || File.join(Dir.home, '.openclaw', 'openclaw.json')
  config_path = Pathname.new(config_path)
  unless allowed_models(config_path).include?(model)
    raise ArgumentError, 'model is not in the configured OpenClaw model allowlist'
  end

  provider, model_id = model.split('/', 2)
  raise ArgumentError, 'model must have provider/model form' unless provider && model_id

  run_id = SecureRandom.uuid
  params = {
    'message' => task.strip,
    'provider' => provider,
    'model' => model_id,
    'sessionKey' => "agent:main:abstraction-runner:#{run_id}",
    'idempotencyKey' => run_id,
    'timeout' => timeout,
    'deliver' => false
  }

  command = [
    'openclaw', 'gateway', 'call', 'agent', '--params', JSON.generate(params),
    '--expect-final', '--json', '--timeout', ((timeout + 10) * 1000).to_s
  ]

  stdout, stderr, status = Open3.capture3(*command, timeout: timeout + 20)

  unless status.success?
    $stderr.puts stderr.empty? ? stdout : stderr
    return status.exitstatus
  end

  begin
    response = JSON.parse(stdout)
  rescue JSON::ParserError => e
    raise ArgumentError, 'OpenClaw returned invalid JSON', e.backtrace
  end

  unless response.is_a?(Hash) && response['status'] == 'ok'
    raise ArgumentError, 'OpenClaw did not return a completed agent result'
  end

  agent_result = response['result']
  unless agent_result.is_a?(Hash)
    raise ArgumentError, 'OpenClaw returned no agent result'
  end

  meta = agent_result['meta'] || {}
  unless meta.is_a?(Hash) && !meta['aborted'] && !meta['error']
    raise ArgumentError, 'OpenClaw agent execution did not complete successfully'
  end

  payloads = agent_result['payloads'] || []
  unless payloads.is_a?(Array) && !payloads.any? { |item| !item.is_a?(Hash) || item['isError'] }
    raise ArgumentError, 'OpenClaw agent returned an error'
  end

  unless payloads.any? { |item| item['text'].is_a?(String) && !item['text'].strip.empty? }
    raise ArgumentError, 'OpenClaw agent returned no text'
  end

  puts JSON.generate(response, ascii_only: false)
  0
end

def main
  require 'optparse'
  options = {}
  parser = OptionParser.new do |opts|
    opts.banner = 'Usage: agent_runner.rb [options]'
    opts.on('--task TASK', 'Task to run') { |v| options[:task] = v }
    opts.on('--model MODEL', 'Model to use') { |v| options[:model] = v }
    opts.on('--timeout TIMEOUT', Integer, 'Timeout in seconds (default: 1800)') { |v| options[:timeout] = v }
    opts.on('--gateway-only', 'Gateway-only mode') { options[:gateway_only] = true }
  end

  parser.parse!

  unless options[:gateway_only]
    $stderr.puts 'agent_runner: no worker/relay transport configured; gateway-only requires --gateway-only'
    return 1
  end

  run(options[:task], options[:model], options[:timeout] || 1800)
rescue StandardError => e
  $stderr.puts "agent_runner: #{e.message}"
  1
end

exit(main) if __FILE__ == $0
