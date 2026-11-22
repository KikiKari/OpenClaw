#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "07f32bb740e43ae91f45966f0645531feb9d9bebc503cda1c2c2f755b8c257be", "source_sha256": "a26da3d1befb1a302d385e0a3c85117de3ec06543d5017cf1d706e7f0602be0f", "target_language": "ruby"}
# spawn_agent.py — portiert nach ruby
# Quelle: python, OpenClaw@gateway1:skills/sub-agents-utils/scripts/spawn_agent.py
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

# frozen_string_literal: true

# Sub-Agent spawner - Einfache CLI für sessions_spawn

require 'optparse'
require 'json'
require 'pathname'

def load_models
  config_path = Pathname.new(ENV.fetch('OPENCLAW_CONFIG', '/home/openclaw/.openclaw/openclaw.json'))
  begin
    config = JSON.parse(config_path.read(encoding: 'utf-8'))
    model_config = config.dig('agents', 'defaults', 'model')
    candidates = [model_config['primary'], *model_config['fallbacks']]
  rescue StandardError => e
    raise "Modellkonfiguration kann nicht geladen werden: #{config_path}: #{e.message}"
  end

  models = candidates.uniq.select do |model|
    model.is_a?(String) && !model.empty? && !model.start_with?('anthropic/')
  end

  raise "Keine allgemein verfügbaren Modelle in #{config_path}" if models.empty?

  models
end

MODELS = load_models

class SubAgentSpawner
  # Hilft beim Spawnen von Sub-Agents

  def self.get_spawn_config(task:, label: nil, model: nil, thinking: nil, timeout: nil, thread: false, mode: 'run')
    # Erstellt Konfiguration für sessions_spawn

    config = { 'task' => task }

    config['label'] = label if label
    config['model'] = model if model && MODELS.include?(model)
    config['thinking'] = thinking if thinking
    config['runTimeoutSeconds'] = timeout if timeout

    if thread
      config['thread'] = true
      config['mode'] = 'session' if mode == 'run' # thread requires session mode
    else
      config['mode'] = mode
    end

    config
  end

  def self.print_spawn_command(config)
    # Gibt das equivalente Tool-Kommando aus
    puts "\n🛠️  Tool-Aufruf:"
    puts '=' * 50
    puts 'sessions_spawn('
    config.each do |key, value|
      if value.is_a?(String)
        puts "    #{key}=\"#{value}\""
      else
        puts "    #{key}=#{value}"
      end
    end
    puts ')'
    puts '=' * 50
  end

  def self.print_slash_command(config)
    # Gibt das equivalente Slash-Kommando aus
    task = config['task'] || ''
    label = config['label'] || 'agent'
    model = config['model'] || ''

    cmd = "/subagents spawn #{label} \"#{task}\""
    cmd += " --model #{model}" unless model.empty?
    cmd += " --thinking #{config['thinking']}" if config['thinking']

    puts "\n💬 Slash Command:"
    puts '=' * 50
    puts cmd
    puts '=' * 50
  end
end

def main
  options = {
    timeout: 900,
    mode: 'run',
    output: 'tool'
  }

  parser = OptionParser.new do |opts|
    opts.banner = 'Sub-Agent Spawn Helper'
    opts.separator ''
    opts.on('-t', '--task TASK', 'Aufgabenbeschreibung') { |v| options[:task] = v }
    opts.on('-l', '--label LABEL', 'Optionaler Label') { |v| options[:label] = v }
    opts.on('-m', '--model MODEL', MODELS, 'KI-Modell') { |v| options[:model] = v }
    opts.on('--thinking LEVEL', %w[low medium high], 'Thinking Level') { |v| options[:thinking] = v }
    opts.on('--timeout TIMEOUT', Integer, 'Timeout in Sekunden (default: 900)') { |v| options[:timeout] = v }
    opts.on('--thread', 'Thread-Binding aktivieren') { options[:thread] = true }
    opts.on('--mode MODE', %w[run session], 'Run mode') { |v| options[:mode] = v }
    opts.on('-o', '--output FORMAT', %w[tool slash json], 'Output format') { |v| options[:output] = v }
    opts.separator ''
    opts.separator 'Beispiele:'
    opts.separator '  spawn_agent.rb -t "Analyze logs"'
    opts.separator '  spawn_agent.rb -t "Code review" -m openai/gpt-5.6-sol --timeout 1800'
    opts.separator '  spawn_agent.rb -t "Batch process" -l "batch-worker" --thread'
  end

  parser.parse!

  unless options[:task]
    puts parser.help
    exit 1
  end

  config = SubAgentSpawner.get_spawn_config(
    task: options[:task],
    label: options[:label],
    model: options[:model],
    thinking: options[:thinking],
    timeout: options[:timeout],
    thread: options[:thread] || false,
    mode: options[:mode]
  )

  puts '✅ Sub-Agent Konfiguration:'
  puts JSON.pretty_generate(config)

  case options[:output]
  when 'tool'
    SubAgentSpawner.print_spawn_command(config)
  when 'slash'
    SubAgentSpawner.print_slash_command(config)
  when 'json'
    puts "\n📄 JSON:"
    puts JSON.generate(config)

    # Speichere als Datei
    output_file = Pathname.new('/tmp').join("subagent_#{config['label'] || 'spawn'}.json")
    File.write(output_file, JSON.pretty_generate(config))
    puts "💾 Gespeichert: #{output_file}"
  end
end

main if __FILE__ == $PROGRAM_NAME
