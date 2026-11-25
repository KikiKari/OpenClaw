#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "63270070c48a6fe0af38c9cc55cd947485e2581148cbf2d76cbc5fb8fad90c27", "source_sha256": "427807a362e6e00a5a3186533edce544430f9f5097e6eda1d8dac1a6ffaf2107", "target_language": "ruby"}
# test_multinode_fallback.py — portiert nach ruby
# Quelle: python, workspace@local:scripts/test_multinode_fallback.py
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

# frozen_string_literal: true

# Testet Multi-Node Fallback-Logik des db-maintainer
# Simuliert: Worker-Node nicht erreichbar → Fallback auf lokal

require 'json'
require 'open3'

WORKSPACE = '/home/openclaw/.openclaw/workspace'

def check_node_reachable(node_id)
  # Prüft den Verbindungseintrag dieses Nodes, nicht die Gesamtausgabe.
  aliases = Set.new([node_id.downcase])
  node2_names = Set.new(['openclaw-node2', 'arm64-node', 'v2202604104722449961', 'v2202604104722449961.taild25fea.ts.net'])
  aliases.merge(node2_names) if node2_names.include?(node_id.downcase)

  begin
    stdout, stderr, status = Open3.capture3('openclaw', 'nodes', 'status', '--json')
    raise "Command failed with status #{status.exitstatus}" unless status.success?

    payload = JSON.parse(stdout)
    payload.fetch('nodes', []).any? do |node|
      node.is_a?(Hash) &&
        aliases.include?(node.dig('displayName').to_s.downcase) &&
        node['connected'] == true
    end
  rescue StandardError => e
    puts "Error checking node reachability: #{e}"
    false
  end
end

def spawn_on_node(node_id, task)
  # Versucht Task auf Node auszuführen
  puts "Versuche Task auf Node #{node_id} zu starten..."
  begin
    # Simuliert: openclaw agent spawn --node {node_id}
    stdout, stderr, status = Open3.capture3('echo', "Spawned on #{node_id}: #{task}")
    unless status.success?
      puts "❌ Node #{node_id} nicht erreichbar: #{stderr}"
      return false
    end

    puts "✅ Erfolgreich delegiert an #{node_id}"
    true
  rescue StandardError => e
    puts "❌ Node #{node_id} nicht erreichbar: #{e}"
    false
  end
end

def execute_locally(task)
  # Führt Task lokal aus (Fallback)
  puts '🔄 Fallback: Führe Task lokal aus...'
  begin
    if task == 'db_maintainer'
      script_path = File.join(WORKSPACE, 'skills', 'db-maintainer', 'scripts', 'db_maintainer.py')
      stdout, stderr, status = Open3.capture3('python3', script_path)
      if status.success?
        puts '✅ Lokale Ausführung erfolgreich'
        true
      else
        puts "❌ Fehler: #{stderr[0..199]}"
        false
      end
    end
  rescue StandardError => e
    puts "❌ Lokale Ausführung fehlgeschlagen: #{e}"
    false
  end
end

def main
  puts '=' * 60
  puts 'MULTI-NODE FALLBACK TEST'
  puts '=' * 60
  puts

  # Konfiguration
  primary_node = 'v2202604104722449961.taild25fea.ts.net' # Node 2
  task = 'db_maintainer'

  puts "Primärer Node: #{primary_node}"
  puts "Task: #{task}"
  puts

  # 1. Prüfe Node-Erreichbarkeit
  puts '--- 1. Prüfe Node-Erreichbarkeit ---'
  if check_node_reachable(primary_node)
    puts "✅ Node #{primary_node} ist erreichbar"

    # 2. Versuche Delegation
    puts "\n--- 2. Versuche Delegation ---"
    if spawn_on_node(primary_node, task)
      puts "\n✅ MULTI-NODE: Task erfolgreich delegiert"
      return 0
    else
      puts "\n⚠️ Delegation fehlgeschlagen, aktiviere Fallback..."
    end
  else
    puts "❌ Node #{primary_node} nicht erreichbar"
    puts '🔄 Fallback wird aktiviert...'
  end

  # 3. Lokale Ausführung (Fallback)
  puts "\n--- 3. Lokale Ausführung (Fallback) ---"
  if execute_locally(task)
    puts "\n✅ FALLBACK: Task lokal erfolgreich ausgeführt"
    return 0
  else
    puts "\n❌ FEHLER: Weder Delegation noch Fallback erfolgreich"
    return 1
  end
end

exit(main)
