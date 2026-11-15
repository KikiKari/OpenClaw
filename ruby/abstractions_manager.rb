#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "62c451556aae8062c6c7282f430b64b6457b48271d705cefdbc51cbfdc564eb1", "source_sha256": "b4ecb634df9abcb3ea24bb1e77312cf63d5b68316b035fcee5ca400dc06e5200", "target_language": "ruby"}
# abstractions_manager.py — portiert nach ruby
# Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/abstractions_manager.py
# Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

require 'json'
require 'fileutils'
require 'date'

# Konfiguration
WORKSPACE = Pathname.new("/home/openclaw/.openclaw/workspace")
ABSTRACTIONS_REPO = WORKSPACE / "git" / "Abstraktionen"
LOG_DIR = WORKSPACE / "logs" / "abstractions-manager"
STATE_FILE = WORKSPACE / "db" / "abstractions_state.json"

# Node-Konfiguration mit Prioritäten
NODES = {
  "node1" => {"always_available" => true, "capacity" => "medium", "priority" => 2},  # Gateway-Master
  "node2" => {"always_available" => true, "capacity" => "medium", "priority" => 3},  # Stable Worker
  "node3" => {"always_available" => false, "capacity" => "medium", "priority" => 4}, # Bald verfügbar
  "node5" => {"always_available" => false, "capacity" => "low", "priority" => 5, "device" => "Redmi Note 11S", "condition" => "mobile_internet"},
  "node7" => {"always_available" => true, "capacity" => "high", "priority" => 1},    # Docker Hauptarbeitspferd
}

AVAILABLE_MODELS = [
  "openrouter/moonshotai/kimi-k2.5",
  "openrouter/openai/gpt-4o",
  "openrouter/anthropic/claude-3-5-sonnet-20241022",
  "openrouter/google/gemini-2.0-flash-001",
  "openrouter/nvidia/llama-3.3-nemotron-super-49b-v1",
  "openrouter/qwen/qwen-2.5-coder-32b-instruct",
]

TARGET_LANGUAGES = {
  "perl5" => {"ext" => ".pl", "shebang" => "#!/usr/bin/env perl", "header" => "use strict;\nuse warnings;\n"},
  "perl6" => {"ext" => ".raku", "shebang" => "#!/usr/bin/env raku", "header" => "use v6;\n"},
  "javascript" => {"ext" => ".js", "shebang" => "#!/usr/bin/env node", "header" => ""},
  "python" => {"ext" => ".py", "shebang" => "#!/usr/bin/env python3", "header" => ""},
  "shell" => {"ext" => ".sh", "shebang" => "#!/bin/bash", "header" => "set -euo pipefail\n"},
  "powershell" => {"ext" => ".ps1", "shebang" => "#!/usr/bin/env pwsh", "header" => "#Requires -Version 7\n"},
  "tcl" => {"ext" => ".tcl", "shebang" => "#!/usr/bin/env tclsh", "header" => "package require Tcl 8.6\n"},
  "ruby" => {"ext" => ".rb", "shebang" => "#!/usr/bin/env ruby", "header" => "require 'json'\nrequire 'fileutils'\n"},
  "lua" => {"ext" => ".lua", "shebang" => "#!/usr/bin/env lua", "header" => ""},
  "go" => {"ext" => ".go", "shebang" => "// +build ignore", "header" => "package main\n"},
}

def log(message, level = "INFO")
  LOG_DIR.mkpath unless LOG_DIR.exist?
  timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
  line = "[#{timestamp}] [#{level}] #{message}"
  puts line
  log_file = LOG_DIR / "#{Time.now.strftime('%Y-%m-%d')}.log"
  File.open(log_file, 'a') { |f| f.puts line }
end

def get_node_by_priority(job_weight = "medium")
  # Wählt Node basierend auf Job-Gewicht und Priorität
  
  # Prioritäts-Matrix
  if job_weight == "heavy"
    # Schwere Jobs → Node 7 (Docker mit vielen Ressourcen)
    preferred_order = ["node7", "node2", "node1"]
  elsif job_weight == "medium"
    # Mittlere Jobs → Stable Nodes
    preferred_order = ["node2", "node1", "node7"]
  else  # light
    # Leichte Jobs → Mobile/verfügbare Nodes
    preferred_order = ["node5", "node1", "node2"]
  end
  
  # Prüfe Verfügbarkeit
  preferred_order.each do |node_id|
    next unless NODES.key?(node_id)
    
    node = NODES[node_id]
    
    # Skip nicht immer verfügbare Nodes wenn nicht explizit requested
    if !node["always_available"] && job_weight != "light"
      next
    end
    
    # Prüfe ob Node online
    if check_node_status(node_id)
      return node_id
    end
  end
  
  # Fallback zu Node 1
  "node1"
end

def check_node_status(node_id)
  # Prüft ob ein Node erreichbar ist
  begin
    result = Open3.capture3("openclaw", "nodes", "status", node_id, timeout: 5)
    return result[2].success? && (result[0].downcase.include?("online") || result[0].downcase.include?("active"))
  rescue
    # Bei Timeout/Error: Prüfe letzten bekannten Status
    return NODES.dig(node_id, "always_available") || false
  end
end

def get_job_weight(script_size, target_langs_count)
  # Bewertet Job-Gewicht basierend auf Script-Größe und Anzahl Zielsprachen
  total_work = script_size * target_langs_count
  
  if total_work > 50000  # Große Scripts, viele Sprachen
    return "heavy"
  elsif total_work > 10000  # Mittlere Last
    return "medium"
  else
    return "light"
  end
end

def load_state
  if STATE_FILE.exist?
    begin
      return JSON.parse(File.read(STATE_FILE))
    rescue
      # ignore errors
    end
  end
  
  {
    "processed" => {},
    "queue" => [],
    "current_priority" => "high",
    "stats" => {"total_scripts" => 0, "abstractions_created" => 0}
  }
end

def save_state(state)
  STATE_FILE.dirname.mkpath unless STATE_FILE.dirname.exist?
  File.write(STATE_FILE, JSON.pretty_generate(state))
end

def find_scripts_in_dir(directory, exclude_patterns = nil)
  exclude_patterns ||= ["node_modules", ".git", "__pycache__", "dist", "build"]
  scripts = []
  
  if directory.exist?
    ["*.py", "*.js", "*.sh", "*.pl", "*.rb"].each do |ext|
      Dir.glob(directory.join("**", ext)).each do |script_path|
        script = Pathname.new(script_path)
        unless exclude_patterns.any? { |pattern| script.to_s.include?(pattern) }
          scripts << script
        end
      end
    end
  end
  
  scripts
end

def create_abstraction(script_path, target_lang)
  begin
    original_content = File.read(script_path, encoding: 'utf-8', invalid: :replace, undef: :replace)
    
    ext = script_path.extname[1..-1]
    source_lang_map = {"py" => "Python", "js" => "JavaScript", "sh" => "Shell", "pl" => "Perl", "rb" => "Ruby"}
    source_lang = source_lang_map[ext] || ext
    
    target_dir = ABSTRACTIONS_REPO / target_lang
    target_dir.mkpath unless target_dir.exist?
    
    target_file = target_dir / "#{script_path.basename(script_path.extname)}#{TARGET_LANGUAGES[target_lang]['ext']}"
    
    return false if target_file.exist?
    
    template = TARGET_LANGUAGES[target_lang]
    lines = original_content.lines.first(15)
    
    content = <<~CONTENT
      #{template['shebang']}
      # #{script_path.basename(script_path.extname)} - #{target_lang.capitalize} Version
      # Portiert von #{source_lang}
      # Original: #{script_path}
      # Erstellt: #{Time.now.strftime('%Y-%m-%d')}
      #
      #{template['header'].strip}

      # Original-Code-Referenz:
      # #{lines.join('# ').chomp}

      def main
        # TODO: Implementiere #{source_lang} Funktionalität in #{target_lang.capitalize}
        pass
      end

      if __FILE__ == $0
        main
      end
    CONTENT
    
    File.write(target_file, content)
    log("Created: #{target_file}")
    return true
  rescue => e
    log("Failed: #{script_path} - #{e}", "ERROR")
    return false
  end
end

def process_on_node(node_id, scripts, target_langs)
  # Verarbeitet Scripts auf definiertem Node
  created = 0
  
  if node_id == "node1"
    # Lokale Verarbeitung
    scripts.each do |script|
      target_langs.each do |lang|
        if create_abstraction(script, lang)
          created += 1
        end
      end
    end
  else
    # Remote-Verarbeitung
    log("Dispatching #{scripts.length} jobs to #{node_id}")
    # TODO: Implementiere Remote-Dispatch wenn Node-Infrastruktur bereit
    # Für jetzt: Lokale Verarbeitung mit Node-Logging
    scripts.each do |script|
      target_langs.each do |lang|
        if create_abstraction(script, lang)
          created += 1
          log("Processed on #{node_id}: #{script.basename} -> #{lang}")
        end
      end
    end
  end
  
  created
end

def process_priority_high
  created = 0
  targets = [
    ["skill-creator", WORKSPACE / "skills" / "skill-creator" / "scripts"],
    ["json-utils", WORKSPACE / "skills" / "json-utils" / "scripts"],
    ["scripting-utils", WORKSPACE / "skills" / "scripting-utils" / "scripts"],
    ["model-usage", WORKSPACE / "skills" / "model-usage" / "scripts"],
    ["tiktok-live", WORKSPACE / "skills" / "tiktok-live" / "scripts"],
  ]
  
  targets.each do |skill_name, scripts_dir|
    scripts = find_scripts_in_dir(scripts_dir, ["node_modules", ".git", "test", "tests"])
    log("#{skill_name}: #{scripts.length} scripts found")
    
    scripts.first(10).each do |script|  # Limit für erste Durchläufe
      script_size = script.exist? ? script.size : 0
      target_langs = ["perl5", "javascript", "python", "shell", "tcl"]
      job_weight = get_job_weight(script_size, target_langs.length)
      
      # Wähle Node basierend auf Job-Gewicht
      selected_node = get_node_by_priority(job_weight)
      log("Processing #{script.basename} (#{job_weight}) on #{selected_node}")
      
      created += process_on_node(selected_node, [script], target_langs)
    end
  end
  
  created
end

def process_priority_medium
  created = 0
  targets = [
    ["workspace-scripts", WORKSPACE / "scripts"],
    ["db-maintainer", WORKSPACE / "skills" / "db-maintainer" / "scripts"],
    ["log-collector", WORKSPACE / "skills" / "log-collector" / "scripts"],
  ]
  
  targets.each do |dir_name, scripts_dir|
    scripts = find_scripts_in_dir(scripts_dir, ["node_modules", ".git"])
    
    scripts.first(10).each do |script|
      script_size = script.exist? ? script.size : 0
      target_langs = ["perl5", "javascript", "powershell", "python"]
      job_weight = get_job_weight(script_size, target_langs.length)
      
      # Mittlere Priority → eher leichtere Jobs
      selected_node = get_node_by_priority(job_weight == "heavy" ? "medium" : job_weight)
      log("Processing #{script.basename} (#{job_weight}) on #{selected_node}")
      
      created += process_on_node(selected_node, [script], target_langs)
    end
  end
  
  created
end

def git_commit(message)
  begin
    Dir.chdir(ABSTRACTIONS_REPO) do
      system("git", "add", ".", out: File::NULL, err: File::NULL)
      system("git", "commit", "-m", message, out: File::NULL, err: File::NULL)
    end
    log("Git commit: #{message}")
  rescue
    # ignore errors
  end
end

def create_status_report(state)
  report_file = ABSTRACTIONS_REPO / "STATUS.md"
  lang_counts = {}
  
  if ABSTRACTIONS_REPO.exist?
    ABSTRACTIONS_REPO.children.select(&:directory?).each do |lang_dir|
      if TARGET_LANGUAGES.key?(lang_dir.basename.to_s)
        lang_counts[lang_dir.basename.to_s] = lang_dir.children.select(&:file?).length
      end
    end
  end
  
  File.open(report_file, 'w') do |f|
    f.write("# Script Abstractions - Status Report\n\n")
    f.write("**Letzte Aktualisierung:** #{Time.now.strftime('%Y-%m-%d %H:%M')}\n\n")
    f.write("- Aktuelle Priorität: #{state['current_priority'] || 'high'}\n")
    f.write("- Verarbeitete Scripts: #{state['processed'].length}\n")
    f.write("- Abstraktionen gesamt: #{state['stats']['abstractions_created']}\n\n")
    
    f.write("## Abstraktionen pro Sprache\n\n")
    lang_counts.sort.each do |lang, count|
      f.write("- #{lang}: #{count}\n")
    end
    
    f.write("\n## Verfügbare Modelle\n\n")
    AVAILABLE_MODELS.first(3).each do |model|
      f.write("- `#{model}`\n")
    end
    f.write("- ... und #{AVAILABLE_MODELS.length - 3} weitere\n")
    
    f.write("\n## Multi-Node Support\n\n")
    f.write("| Node | Verfügbarkeit | Kapazität | Priorität | Gerät |\n")
    f.write("|------|---------------|-----------|-----------|-------|\n")
    NODES.each do |node_id, config|
      avail = config["always_available"] ? "✅ Immer" : "📱 Bedingt"
      device = config["device"] || "Server"
      f.write("| #{node_id} | #{avail} | #{config['capacity'] || 'unknown'} | #{config['priority'] || '-'} | #{device} |\n")
    end
    
    f.write("\n### Job-Verteilung\n\n")
    f.write("- **Heavy Jobs** (>50KB × Sprachen) → Node 7 (Docker, hohe Ressourcen)\n")
    f.write("- **Medium Jobs** → Node 2 (Stable), Node 1 (Primary)\n")
    f.write("- **Light Jobs** → Node 5 (Redmi Note 11S, wenn verfügbar)\n")
  end
end

def main
  log("Script Abstractions Manager (Multi-Node) gestartet")
  
  state = load_state
  log("State loaded: #{state['processed'].length} processed")
  
  current_priority = state["current_priority"] || "high"
  created = 0
  
  if current_priority == "high"
    log("Processing HIGH priority: Top 5 Skills")
    created = process_priority_high
    if created > 0
      git_commit("High priority: #{created} abstractions")
    end
    state["current_priority"] = "medium"
  elsif current_priority == "medium"
    log("Processing MEDIUM priority: Workspace Scripts")
    created = process_priority_medium
    if created > 0
      git_commit("Medium priority: #{created} abstractions")
    end
    state["current_priority"] = "high"  # Zyklus
  end
  
  state["stats"]["last_run"] = Time.now.iso8601
  state["stats"]["abstractions_created"] = TARGET_LANGUAGES.keys.sum do |lang|
    dir = ABSTRACTIONS_REPO / lang
    dir.exist? ? dir.children.select(&:file?).length : 0
  end
  
  save_state(state)
  create_status_report(state)
  
  log("Abgeschlossen. #{created} neue Abstraktionen erstellt.")
end

main if __FILE__ == $0
