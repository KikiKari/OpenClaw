#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "0afea13eeb38942c381dab4f2a5f2a92ba6987a9d00dcf9af0749a3a99b868d5", "source_sha256": "f911bfbdbdc66c53e970ead9851f23e8c415a17f83d92cea3a53539f83a49ad2", "target_language": "ruby"}
# spawn_agent.py — portiert nach ruby
# Quelle: python, OpenClaw@gateway2:skills/sub-agents-utils/scripts/spawn_agent.py
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

# Sub-Agent spawner - Einfache CLI für sessions_spawn

require 'json'
require 'optparse'
require 'pathname'

WORKSPACE = Pathname.new('/home/openclaw/.openclaw/workspace')
$LOAD_PATH.unshift(WORKSPACE.to_s) unless $LOAD_PATH.include?(WORKSPACE.to_s)

begin
  require 'openclaw_models'
  MODELS = configured_models()
rescue StandardError => e
  abort "Modellkonfiguration kann nicht geladen werden: #{e.message}"
end

class SubAgentSpawner
  # Hilft beim Spawnen von Sub-Agents
  
  def self.get_spawn_config(task:, label: nil, model: nil, thinking: nil, timeout: nil, thread: false, mode: 'run')
    # Erstellt Konfiguration für sessions_spawn
    
    config = {
      'task' => task
    }
    
    config['label'] = label if label
    if model && MODELS.include?(model)
      config['model'] = model
    end
    config['thinking'] = thinking if thinking
    config['runTimeoutSeconds'] = timeout if timeout
    if thread
      config['thread'] = true
      if mode == 'run'
        config['mode'] = 'session' # thread requires session mode
      else
        config['mode'] = mode
      end
    else
      config['mode'] = mode
    end
    
    config
  end
  
  def self.print_spawn_command(config)
    # Gibt das equivalente Tool-Kommando aus
    puts "\n🛠️  Tool-Aufruf:"
    puts "=" * 50
    puts "sessions_spawn("
    config.each do |key, value|
      if value.is_a?(String)
        puts "    #{key}=\"#{value}\""
      else
        puts "    #{key}=#{value}"
      end
    end
    puts ")"
    puts "=" * 50
  end
  
  def self.print_slash_command(config)
    # Gibt das equivalente Slash-Kommando aus
    task = config['task'] || ''
    label = config['label'] || 'agent'
    model = config['model'] || ''
    
    cmd = "/subagents spawn #{label} \"#{task}\""
    cmd += " --model #{model}" if model != ''
    cmd += " --thinking #{config['thinking']}" if config['thinking']
    
    puts "\n💬 Slash Command:"
    puts "=" * 50
    puts cmd
    puts "=" * 50
  end
end

def main
  options = {}
  
  opt_parser = OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [options]"
    opts.separator ""
    opts.separator "Sub-Agent Spawn Helper"
    opts.separator ""
    opts.separator "Options:"
    
    opts.on('-t', '--task TASK', 'Aufgabenbeschreibung') do |task|
      options[:task] = task
    end
    
    opts.on('-l', '--label LABEL', 'Optionaler Label') do |label|
      options[:label] = label
    end
    
    opts.on('-m', '--model MODEL', MODELS, 'KI-Modell') do |model|
      options[:model] = model
    end
    
    opts.on('--thinking LEVEL', ['low', 'medium', 'high'], 'Thinking Level') do |thinking|
      options[:thinking] = thinking
    end
    
    opts.on('--timeout SECONDS', Integer, 'Timeout in Sekunden (default: 900)') do |timeout|
      options[:timeout] = timeout
    end
    
    opts.on('--thread', 'Thread-Binding aktivieren') do
      options[:thread] = true
    end
    
    opts.on('--mode MODE', ['run', 'session'], 'Run mode') do |mode|
      options[:mode] = mode
    end
    
    opts.on('-o', '--output FORMAT', ['tool', 'slash', 'json'], 'Output format') do |output|
      options[:output] = output
    end
    
    opts.separator ""
    opts.separator "Examples:"
    opts.separator "  #{$0} -t 'Analyze logs'"
    opts.separator "  #{$0} -t 'Code review' -m openrouter/anthropic/claude-haiku-4.5 --timeout 1800"
    opts.separator "  #{$0} -t 'Batch process' -l 'batch-worker' --thread"
  end
  
  begin
    opt_parser.parse!
  rescue OptionParser::InvalidOption => e
    puts e.message
    puts opt_parser
    exit 1
  end
  
  if !options[:task]
    puts "Error: --task is required"
    puts opt_parser
    exit 1
  end
  
  # Set defaults
  options[:timeout] ||= 900
  options[:mode] ||= 'run'
  options[:output] ||= 'tool'
  
  spawner = SubAgentSpawner
  config = spawner.get_spawn_config(
    task: options[:task],
    label: options[:label],
    model: options[:model],
    thinking: options[:thinking],
    timeout: options[:timeout],
    thread: options[:thread] || false,
    mode: options[:mode]
  )
  
  puts "✅ Sub-Agent Konfiguration:"
  puts JSON.pretty_generate(config)
  
  case options[:output]
  when 'tool'
    spawner.print_spawn_command(config)
  when 'slash'
    spawner.print_slash_command(config)
  when 'json'
    puts "\n📄 JSON:"
    puts JSON.generate(config)
    
    # Speichere als Datei
    label = config['label'] || 'spawn'
    output_file = Pathname.new('/tmp').join("subagent_#{label}.json")
    File.write(output_file, JSON.pretty_generate(config))
    puts "💾 Gespeichert: #{output_file}"
  end
end

if __FILE__ == $0
  main
end
