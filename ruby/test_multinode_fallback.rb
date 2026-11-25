#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "36949805b9c2fca1ee4f4071bbe26a419ce056c38b022d820ab9e32da1f326e8", "source_sha256": "52b3516148b12072bbff77599a6faac284607fbc005a73f93c2b7f4f349cf6f1", "target_language": "ruby"}
# test_multinode_fallback.py — portiert nach ruby
# Quelle: python, OpenClaw@gateway1:scripts/test_multinode_fallback.py
# auch in: OpenClaw@gateway2:scripts/test_multinode_fallback.py
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

# frozen_string_literal: true

# Testet Multi-Node Fallback-Logik des db-maintainer
# Simuliert: Worker-Node nicht erreichbar → Fallback auf lokal

require 'open3'
require 'pathname'

WORKSPACE = Pathname.new('/home/openclaw/.openclaw/workspace')

def check_node_reachable(node_id)
  # Prüft ob Node erreichbar ist
  begin
    # Versuche Node-Status abzufragen
    stdout, = Open3.capture3('openclaw', 'nodes', 'status')
    return stdout.include?(node_id) && stdout.include?('connected')
  rescue StandardError
    false
  end
end

def spawn_on_node(node_id, task)
  # Versucht Task auf Node auszuführen
  puts "Versuche Task auf Node #{node_id} zu starten..."
  begin
    # Simuliert: openclaw agent spawn --node {node_id}
    stdout, = Open3.capture3('echo', "Spawned on #{node_id}: #{task}")
    puts "✅ Erfolgreich delegiert an #{node_id}"
    true
  rescue => e
    puts "❌ Node #{node_id} nicht erreichbar: #{e}"
    false
  end
end

def execute_locally(task)
  # Führt Task lokal aus (Fallback)
  puts '🔄 Fallback: Führe Task lokal aus...'
  begin
    if task == 'db_maintainer'
      script_path = WORKSPACE.join('skills', 'db-maintainer', 'scripts', 'db_maintainer.py')
      stdout, stderr, status = Open3.capture3('python3', script_path.to_s)
      
      if status.success?
        puts '✅ Lokale Ausführung erfolgreich'
        true
      else
        puts "❌ Fehler: #{stderr[0, 200]}"
        false
      end
    end
  rescue => e
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
  primary_node = 'v2202603104722445775'  # Node 2
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

exit(main) if __FILE__ == $0
