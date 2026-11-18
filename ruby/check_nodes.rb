#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "6b55ae77e94cb3135c3484072edaa6e03c8cb2797fd0cc47dabc3c25420cedb7", "source_sha256": "5a841c728d9c1585b5c3191e88fdd38cf887a0d51560ce803b8c0172412bef3d", "target_language": "ruby"}
# check_nodes.py — portiert nach ruby
# Quelle: python, OpenClaw@gateway1:skills/multi-nodes-utils/scripts/check_nodes.py
# auch in: OpenClaw@gateway2:skills/multi-nodes-utils/scripts/check_nodes.py
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

# frozen_string_literal: true

# Node-Status Checker - Prüft Verfügbarkeit aller Nodes

require 'json'
require 'time'
require 'open3'

# Node-Konfiguration (sollte aus config file geladen werden)
NODES = {
  "node1" => {
    "always_available" => true,
    "capacity" => "medium",
    "priority" => 2,
    "description" => "Gateway-Master"
  },
  "node2" => {
    "always_available" => true,
    "capacity" => "medium",
    "priority" => 3,
    "description" => "Stable Worker"
  },
  "node3" => {
    "always_available" => false,
    "capacity" => "medium",
    "priority" => 4,
    "description" => "Bald verfügbar (nach Reorganisation)"
  },
  "node5" => {
    "always_available" => false,
    "capacity" => "low",
    "priority" => 5,
    "device" => "Redmi Note 11S",
    "description" => "Mobile (bei Internet verfügbar)"
  },
  "node7" => {
    "always_available" => true,
    "capacity" => "high",
    "priority" => 1,
    "description" => "Docker Hauptarbeitspferd (bald verfügbar)"
  }
}.freeze

def check_node_status(node_id)
  # Prüft Status eines einzelnen Nodes
  begin
    stdout, stderr, status = Open3.capture3("openclaw", "nodes", "status", node_id, timeout: 5)
    
    is_online = status.success? && (
      stdout.downcase.include?("online") ||
      stdout.downcase.include?("active")
    )
    
    {
      "id" => node_id,
      "online" => is_online,
      "available" => NODES[node_id].fetch("always_available", false),
      "response" => stdout.strip[0..99] || "No response"
    }
  rescue Timeout::Error
    {
      "id" => node_id,
      "online" => false,
      "available" => NODES[node_id].fetch("always_available", false),
      "response" => "Timeout"
    }
  rescue => e
    {
      "id" => node_id,
      "online" => false,
      "available" => NODES[node_id].fetch("always_available", false),
      "response" => "Error: #{e}"
    }
  end
end

def print_table(nodes_status)
  # Gibt Node-Status als Tabelle aus
  puts "\n" + "=" * 90
  puts sprintf("%-8s %-12s %-12s %-10s %-10s %s", "Node", "Status", "Verfügbar", "Kapazität", "Priorität", "Gerät/Beschreibung")
  puts "=" * 90
  
  nodes_status.each do |status|
    node_id = status["id"]
    config = NODES[node_id]
    
    status_icon = status["online"] ? "🟢 Online" : "🔴 Offline"
    avail_icon = status["available"] ? "✅ Immer" : "📱 Bedingt"
    capacity = config.fetch("capacity", "unknown")
    priority = config.fetch("priority", "-")
    device = config.fetch("device", config.fetch("description", ""))
    
    puts sprintf("%-8s %-12s %-12s %-10s %-10s %s", node_id, status_icon, avail_icon, capacity, priority, device)
  end
  
  puts "=" * 90
  puts "\nGeprüft am: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
end

def print_json(nodes_status)
  # Gibt Node-Status als JSON aus
  output = {
    "timestamp" => Time.now.iso8601,
    "nodes" => {}
  }
  
  nodes_status.each do |status|
    node_id = status["id"]
    output["nodes"][node_id] = {
      "status" => status,
      "config" => NODES[node_id]
    }
  end
  
  puts JSON.pretty_generate(output)
end

def main
  format = "table"
  save_file = nil
  
  # Parse command line arguments
  ARGV.each_with_index do |arg, i|
    if arg == "--format" || arg == "-f"
      format = ARGV[i + 1] if ARGV[i + 1]
    elsif arg == "--save" || arg == "-s"
      save_file = ARGV[i + 1] if ARGV[i + 1]
    end
  end
  
  puts "🔍 Prüfe Node-Status..."
  
  # Prüfe alle Nodes
  nodes_status = []
  NODES.keys.sort.each do |node_id|
    print "  → #{node_id}... "
    STDOUT.flush
    status = check_node_status(node_id)
    nodes_status << status
    puts status["online"] ? "✓" : "✗"
  end
  
  # Ausgabe
  if format == "table"
    print_table(nodes_status)
  else
    print_json(nodes_status)
  end
  
  # Speichern
  if save_file
    output = {
      "timestamp" => Time.now.iso8601,
      "nodes" => nodes_status.each_with_object({}) { |s, h| h[s["id"]] = s }
    }
    File.write(save_file, JSON.pretty_generate(output))
    puts "\n💾 Gespeichert: #{save_file}"
  end
  
  # Zusammenfassung
  online_count = nodes_status.count { |s| s["online"] }
  puts "\n📊 Zusammenfassung: #{online_count}/#{nodes_status.size} Nodes online"
end

main if __FILE__ == $0
