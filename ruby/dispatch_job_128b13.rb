#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "e6975321e025f0f6c2117a9823c0477ec34210fb99ababfc5fefc05382b02091", "source_sha256": "128b137e5c7d86f81ea7fdb61718540c70e4ed38de4430ae6a23a5739962c024", "target_language": "ruby"}
# dispatch_job.py — portiert nach ruby
# Quelle: python, OpenClaw@gateway2:skills/multi-nodes-utils/scripts/dispatch_job.py
# Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

# frozen_string_literal: true

# Job Dispatcher - Verteilt Jobs auf passende Nodes

require 'optparse'
require 'pathname'
require 'open3'

# Node-Konfiguration
NODES = {
  'node1' => { always_available: true, capacity: 'medium', priority: 2 },
  'node2' => { always_available: true, capacity: 'medium', priority: 3 },
  'node3' => { always_available: false, capacity: 'medium', priority: 4 },
  'node5' => { always_available: false, capacity: 'low', priority: 5, device: 'Redmi Note 11S' },
  'node7' => { always_available: true, capacity: 'high', priority: 1 }
}.freeze

class JobDispatcher
  # Dispatches jobs to appropriate nodes based on weight

  def get_job_weight(script_path, target_langs_count = 1)
    # Bewertet Job-Gewicht
    return 'medium' unless File.exist?(script_path)

    script_size = File.size(script_path)
    total_work = script_size * target_langs_count

    if total_work > 50_000 # > 50KB
      'heavy'
    elsif total_work > 10_000 # > 10KB
      'medium'
    else
      'light'
    end
  end

  def select_node(job_weight)
    # Wählt besten Node basierend auf Job-Gewicht

    preferred = case job_weight
                when 'heavy'
                  # Schwere Jobs → Node 7 (Docker), dann Node 2, dann Node 1
                  %w[node7 node2 node1]
                when 'medium'
                  # Mittlere Jobs → Stable Nodes
                  %w[node2 node1 node7]
                else # light
                  # Leichte Jobs → Mobile/verfügbare Nodes
                  %w[node5 node1 node2]
                end

    # Prüfe Verfügbarkeit
    preferred.each do |node_id|
      return node_id if check_node_available(node_id)
    end

    # Fallback
    'node1'
  end

  def check_node_available(node_id)
    # Prüft ob Node erreichbar ist
    return false unless NODES.key?(node_id)

    node = NODES[node_id]

    # Nicht immer-verfügbare Nodes nur wenn explizit requested
    unless node[:always_available]
      # Für light-jobs prüfen wir ob online
      return _check_mobile_online if node_id == 'node5' # Redmi
      return false
    end

    # Für immer-verfügbare Nodes: prüfe ob wirklich online
    begin
      stdout, stderr, status = Open3.capture3('openclaw', 'nodes', 'status', node_id, timeout: 3)
      status.success?
    rescue StandardError
      node[:always_available]
    end
  end

  def _check_mobile_online
    # Prüft ob Redmi (Node 5) Internet hat
    begin
      stdout, stderr, status = Open3.capture3('openclaw', 'nodes', 'status', 'node5', timeout: 5)
      status.success? && stdout.downcase.include?('online')
    rescue StandardError
      false
    end
  end

  def dispatch(job_script, target_langs = nil)
    # Dispatched Job und gibt Info zurück
    target_langs ||= ['perl5']

    weight = get_job_weight(job_script, target_langs.length)
    selected_node = select_node(weight)

    {
      job: job_script.to_s,
      weight: weight,
      selected_node: selected_node,
      target_langs: target_langs,
      status: 'dispatched'
    }
  end
end

def main
  options = {}
  OptionParser.new do |opts|
    opts.banner = 'Usage: dispatch_job.rb [options]'
    opts.on('-j', '--job JOB', 'Path to job script') { |v| options[:job] = v }
    opts.on('-l', '--langs LANGS', 'Comma-separated target languages') { |v| options[:langs] = v }
    opts.on('-w', '--weight WEIGHT', %w[light medium heavy], 'Force job weight') { |v| options[:weight] = v }
    opts.on('-x', '--execute', 'Actually execute on selected node') { |v| options[:execute] = v }
  end.parse!

  job_path = Pathname.new(options[:job])
  unless job_path.exist?
    puts "❌ Job not found: #{job_path}"
    exit 1
  end

  dispatcher = JobDispatcher.new
  target_langs = options[:langs] ? options[:langs].split(',') : ['perl5']

  # Determine weight
  weight = options[:weight] || dispatcher.get_job_weight(job_path, target_langs.length)

  # Select node
  selected_node = dispatcher.select_node(weight)

  # Output
  puts '📦 Job Dispatch Information'
  puts '=' * 50
  puts "Job: #{job_path}"
  puts "Size: #{job_path.size} bytes"
  puts "Target langs: #{target_langs.join(', ')}"
  puts "Job weight: #{weight}"
  puts "Selected node: #{selected_node}"
  puts '=' * 50

  if options[:execute]
    puts "\n🚀 Executing on #{selected_node}..."
    # TODO: Implement remote execution
    puts '(Remote execution not yet implemented)'
  else
    puts "\n💡 To execute: #{$PROGRAM_NAME} --job #{options[:job]} --execute"
  end
end

main if $PROGRAM_NAME == __FILE__
