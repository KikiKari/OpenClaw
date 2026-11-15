#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "59cb7b5c3aa2137b4e52faad4a02ad97c07245c6eb67b50f219049c3b52d857a", "source_sha256": "748c0fc07a58caf07d4983d358cf0e1ce57c4e180b87ae617d598f53c61efcec", "target_language": "ruby"}
# dispatch_job.py — portiert nach ruby
# Quelle: python, OpenClaw@gateway1:skills/multi-nodes-utils/scripts/dispatch_job.py
# Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

# frozen_string_literal: true

# Job Dispatcher - Verteilt Jobs auf passende Nodes

require 'json'
require 'securerandom'
require 'pathname'
require 'open3'

def _job_weight_bytes(script_path, target_langs_count)
  # Arbeitsvolumen: Dateigröße × Anzahl der Zielsprachen.
  File.size(script_path) * target_langs_count
end

# Node-Konfiguration
NODES = {
  'node1' => { always_available: true, capacity: 'medium', priority: 3, description: 'Gateway' },
  'node2' => { always_available: false, capacity: 'high', priority: 1, description: 'ARM Server' },
  'node3' => { always_available: false, capacity: 'medium', priority: 4, description: 'AMD Server' },
  'node4' => { always_available: false, capacity: 'low', priority: 5, device: 'Redmi Note 11S' },
  'node5' => { always_available: false, capacity: 'high', priority: 2, device: 'Lenovo' },
  'node6' => { always_available: false, device: 'Lenovo (Docker)' }
}.freeze

NODE_NAMES = {
  'node2' => Set['openclaw-node2', 'arm64-node', 'v2202604104722449961', 'v2202604104722449961.taild25fea.ts.net', '100.82.198.122'],
  'node3' => Set['openclaw-node3', 'openclaw-node3.taild25fea.ts.net', '100.73.154.125'],
  'node4' => Set['openclaw-node4', 'redmi-note-11s', 'redmi-note-11s.taild25fea.ts.net', '100.94.134.39'],
  'node5' => Set['openclaw-node5', 'windows node (lenovo-7)'],
  'node6' => Set['openclaw-node6']
}.freeze

def fetch_node_status
  # Return mapped OpenClaw connection states; nil indicates lookup failure.
  begin
    stdout, stderr, status = Open3.capture3('openclaw', 'nodes', 'status', '--json')
    unless status.success?
      warn "OpenClaw command failed: #{stderr}"
      return nil
    end

    payload = JSON.parse(stdout)
    unless payload.is_a?(Hash) && payload['nodes'].is_a?(Array)
      return nil
    end

    states = {}
    NODE_NAMES.each_key { |node| states[node] = false }

    payload['nodes'].each do |item|
      next unless item.is_a?(Hash)

      names = Set.new(%w[displayName nodeId remoteIp].map { |key| item[key]&.to_s&.downcase }.compact)
      NODE_NAMES.each do |node, aliases|
        states[node] = true if (names & aliases) && item['connected'] == true
      end
    end

    states['node1'] = true # successful Gateway status request
    states
  rescue StandardError => e
    warn "Error fetching node status: #{e.message}"
    nil
  end
end

class JobDispatcher
  # Dispatches jobs to appropriate nodes based on weight

  def get_job_weight(script_path, target_langs_count = 1)
    # Bewertet Job-Gewicht
    return 'medium' unless File.exist?(script_path)

    total_work = _job_weight_bytes(script_path, target_langs_count)

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
                  %w[node1 node2 node5 node6]
                when 'medium'
                  %w[node1 node2 node3 node6]
                when 'light'
                  %w[node2 node1 node3 node4]
                else
                  raise ArgumentError, "Unknown job weight: #{job_weight}"
                end

    states = fetch_node_status
    preferred.each do |node_id|
      return node_id if states && states[node_id]
    end
    nil # no verified reachable node
  end

  def check_node_available(node_id)
    # Use the live connection state rather than static availability.
    states = fetch_node_status
    states && states[node_id]
  end

  def execute_translation(job, transport)
    self.class.execute_translation(job, transport)
  end

  def _check_mobile_online
    # Check Node4 (Redmi).
    check_node_available('node4')
  end

  def dispatch(job_script, target_langs = nil, source_text: nil, source_language: nil)
    # Dispatched Job und gibt Info zurück
    target_langs ||= ['perl5']

    weight = get_job_weight(job_script, target_langs.length)
    selected_node = select_node(weight)
    translation_jobs = []

    target_langs.each do |language|
      job = {
        'job_id' => SecureRandom.uuid,
        'source' => job_script.to_s,
        'target_language' => language,
        'selected_node' => selected_node
      }
      job['source_text'] = source_text if source_text
      job['source_language'] = source_language if source_language
      translation_jobs << job
    end

    {
      'job' => job_script.to_s,
      'weight' => weight,
      'selected_node' => selected_node,
      'target_langs' => target_langs,
      'translation_jobs' => translation_jobs,
      'status' => selected_node ? 'selected' : 'unavailable'
    }
  end

  def self.execute_translation(job, transport)
    # Execute via a supplied transport and verify its result belongs to the job.
    if !job['selected_node'] || transport.nil?
      raise RuntimeError, 'no verified node or authorized translation transport'
    end

    response = transport.call(job)
    unless response.is_a?(Hash)
      raise ArgumentError, 'invalid transport response'
    end

    %w[job_id selected_node target_language].each do |key|
      next if response[key] == job[key]

      raise ArgumentError, 'transport response does not match job'
    end

    code = response['code']
    if response['status'] != 'ok' || !code.is_a?(String) || code.strip.empty?
      raise ArgumentError, 'translation did not complete with code'
    end

    code
  end
end

def dispatch_abstraction_job(job_script, target_langs)
  # Erstellt eine Node-Auswahl und je (Skript, Sprache) einen Auftrag.
  dispatcher = JobDispatcher.new
  dispatcher.dispatch(job_script, target_langs)
end

def main
  require 'optparse'

  options = {}
  OptionParser.new do |opts|
    opts.banner = 'Usage: dispatch_job.rb [options]'
    opts.on('--job JOB', '-j', 'Path to job script') { |v| options[:job] = v }
    opts.on('--langs LANGS', '-l', 'Comma-separated target languages') { |v| options[:langs] = v }
    opts.on('--weight WEIGHT', '-w', %w[light medium heavy], 'Force job weight') { |v| options[:weight] = v }
    opts.on('--execute', '-x', 'Actually execute on selected node') { options[:execute] = true }
  end.parse!

  unless options[:job]
    puts '❌ Job argument is required'
    exit 1
  end

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
    puts "\nTranslation dispatch on #{selected_node} is not implemented.", $stderr
    exit 1
  else
    puts "\n💡 To execute: #{$PROGRAM_NAME} --job #{options[:job]} --execute"
  end
  0
end

exit(main) if $PROGRAM_NAME == __FILE__
