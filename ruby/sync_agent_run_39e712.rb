#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "f1d77aa3ad36541bf1c8f615761d3e7fefb0b5e4e97948f41b71d5489ef1373b", "source_sha256": "39e712425a2c8c6fe6bad486ac97ef9c9d7f8a52e1abc18d11018d93ddc9d170", "target_language": "ruby"}
# sync_agent_run.py — portiert nach ruby
# Quelle: python, workspace@local:scripts/sync_agent_run.py
# auch in: workspace@local:scripts/sync_agent.py
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

# Permanenter ClawHub ↔ Git Sync Agent
# Multi-Node fähig, stündliche Ausführung

require 'json'
require 'fileutils'
require 'pathname'
require 'digest'
require 'time'

# Import sync functions
$LOAD_PATH.unshift('/workspace/scripts')
require_relative 'sync_clawhub_git'

CLAWHUB_DIR = Pathname.new("/workspace/skills")
GIT_DIR = Pathname.new("/workspace/git/skills")
STATE_FILE = Pathname.new("/workspace/db/sync_state.json")

# Root directory for backups
BACKUP_ROOT = Pathname.new("/workspace/backups/sync_agent")

def load_state
  # Lädt den Sync-State
  if STATE_FILE.exist?
    JSON.parse(STATE_FILE.read)
  else
    {"sync_history" => [], "pending" => []}
  end
end

def save_state(state)
  # Speichert den Sync-State
  STATE_FILE.dirname.mkpath
  STATE_FILE.write(JSON.pretty_generate(state))
end

def get_all_skills
  # Findet nur valide Skill-Verzeichnisse in beiden Verzeichnissen.
  clawhub_skills = CLAWHUB_DIR.children.select do |d|
    d.directory? && !d.basename.to_s.start_with?('.', '_') && (d / "SKILL.md").exist?
  end.map(&:basename).map(&:to_s)

  git_skills = GIT_DIR.children.select do |d|
    d.directory? && !d.basename.to_s.start_with?('.', '_') && (d / "SKILL.md").exist?
  end.map(&:basename).map(&:to_s)

  (clawhub_skills + git_skills).uniq
end

def init_git_repo(skill_path, skill_name)
  # Initialisiert Git-Repo wenn nötig
  git_dir = skill_path / ".git"
  if !git_dir.exist?
    Dir.chdir(skill_path) do
      system("git", "init", out: File::NULL, err: File::NULL)
      system("git", "add", ".", out: File::NULL, err: File::NULL)
      system("git", "commit", "-m", "Initial commit: #{skill_name} skill", out: File::NULL, err: File::NULL)
    end
    log("Git initialized for #{skill_name}")
  end
end

def backup_skill_dir(skill_path, skill_name)
  # Creates a timestamped tar.gz backup of a skill directory.
  return unless skill_path.exist?

  timestamp = Time.now.strftime("%Y%m%d%H%M%S")
  backup_dir = BACKUP_ROOT / timestamp
  backup_dir.mkpath
  archive_name = "#{skill_name}_#{timestamp}.tar.gz"
  archive_path = backup_dir / archive_name
  
  system("tar", "-czf", archive_path.to_s, "-C", skill_path.to_s, ".", out: File::NULL, err: File::NULL)
  log("Backup created for #{skill_name} at #{archive_path}")
end

def sync_skill_bidirectional(skill_name, dry_run: false)
  # Bidirektionale Synchronisation eines Skills
  clawhub_path = CLAWHUB_DIR / skill_name
  git_path = GIT_DIR / skill_name

  # Fall 1: Nur in ClawHub → zu Git
  if clawhub_path.exist? && !git_path.exist?
    log("NEW in ClawHub: #{skill_name} → syncing to Git")
    backup_skill_dir(clawhub_path, "#{skill_name}_clawhub") unless dry_run
    if sync_to_git(skill_name, dry_run: dry_run)
      init_git_repo(git_path, skill_name) unless dry_run
      return "synced_to_git"
    end

  # Fall 2: Nur in Git → zu ClawHub
  elsif git_path.exist? && !clawhub_path.exist?
    log("NEW in Git: #{skill_name} → syncing to ClawHub")
    backup_skill_dir(git_path, "#{skill_name}_git") unless dry_run
    if sync_to_clawhub(skill_name, dry_run: dry_run)
      return "synced_to_clawhub"
    end

  # Fall 3: In beiden vorhanden → Vergleiche Timestamps
  elsif clawhub_path.exist? && git_path.exist?
    # --- MODIFIZIERTE LOGIK: Robusterer Datei-Hash-Vergleich ---

    # Stelle sicher, dass beide als gültige Skills validiert werden
    unless validate_skill(clawhub_path)
      log("Validation failed for ClawHub skill: #{skill_name}", "ERROR")
      return "error"
    end
    unless validate_skill(git_path)
      log("Validation failed for Git skill: #{skill_name}", "ERROR")
      return "error"
    end

    # Berechne Hashes für clawhub und git
    clawhub_hashes = get_hashes(clawhub_path)
    git_hashes = get_hashes(git_path)

    if clawhub_hashes != git_hashes
      log("Content difference detected for: #{skill_name}")

      # Einfache (aber oft ausreichende) Logik: Wenn clawhub neuer ist, lade hoch.
      # Eine detailliertere Strategie (z.B. welche Version von Git übernehmen)
      # könnte hier implementiert werden, falls nötig.
      # Für jetzt: Wenn sie sich unterscheiden, priorisieren wir ClawHub > Git
      # und aktualisieren Git.

      direction = if clawhub_path.mtime >= git_path.mtime
                   "to-git"
                 else
                   "to-clawhub"
                 end
      log("UPDATE: #{skill_name} → syncing #{direction}")
      unless dry_run
        backup_skill_dir(clawhub_path, "#{skill_name}_clawhub")
        backup_skill_dir(git_path, "#{skill_name}_git")
      end
      sync = direction == "to-git" ? method(:sync_to_git) : method(:sync_to_clawhub)
      if sync.call(skill_name, dry_run: dry_run)
        if !dry_run && direction == "to-git"
          Dir.chdir(git_path) do
            system("git", "add", ".", out: File::NULL, err: File::NULL)
            system("git", "commit", "-m", "Sync from ClawHub content diff: #{Time.now.strftime('%Y-%m-%d %H:%M')}", out: File::NULL, err: File::NULL)
          end
        end
        return direction == "to-git" ? "updated_git" : "updated_clawhub"
      else
        log("Failed to sync #{skill_name} to Git after content diff", "ERROR")
        return "error"
      end
    else
      log("Content is identical for: #{skill_name}")
      return "no_change"
    end
  end

  "no_change"
end

# --- Hinzufügen dieser Hilfsfunktion ---
def get_hashes(skill_dir)
  # Erzeugt ein Dictionary von Datei-Hashes für einen Skill-Ordner.
  hashes = {}
  skill_dir.find do |path|
    if path.file? && !path.to_s.include?('.git')
      relative_path = path.relative_path_from(skill_dir).to_s
      hashes[relative_path] = get_file_hash(path)
    end
  end
  hashes
end

def main
  # Hauptfunktion des Sync-Agents
  require 'optparse'
  
  options = {}
  OptionParser.new do |opts|
    opts.banner = "Usage: sync_agent_run.rb [options]"
    opts.on("--dry-run", "Perform a dry run without making changes.") do |v|
      options[:dry_run] = v
    end
  end.parse!

  dry_run = options[:dry_run]
  log("=== ClawHub ↔ Git Sync Agent gestartet ===")

  state = load_state
  all_skills = get_all_skills
  log("Gefundene Skills: #{all_skills.length}")

  results = {
    "synced_to_git" => [],
    "synced_to_clawhub" => [],
    "updated_git" => [],
    "updated_clawhub" => [],
    "no_change" => [],
    "errors" => []
  }

  all_skills.sort.each do |skill|
    begin
      result = sync_skill_bidirectional(skill, dry_run: dry_run)
      results[result] << skill
    rescue => e
      log("ERROR syncing #{skill}: #{e}", "ERROR")
      results["errors"] << skill
    end
  end

  # Zusammenfassung
  log("\n=== SYNC ZUSAMMENFASSUNG ===")
  log("Neu in Git: #{results['synced_to_git'].length} - #{results['synced_to_git']}")
  log("Neu in ClawHub: #{results['synced_to_clawhub'].length} - #{results['synced_to_clawhub']}")
  log("Git aktualisiert: #{results['updated_git'].length} - #{results['updated_git']}")
  log("ClawHub aktualisiert: #{results['updated_clawhub'].length} - #{results['updated_clawhub']}")
  log("Keine Änderung: #{results['no_change'].length}")
  log("Fehler: #{results['errors'].length} - #{results['errors']}")

  # Ein Dry-Run bleibt vollständig nicht-mutierend (abgesehen vom Audit-Log).
  unless dry_run
    state["sync_history"] ||= []
    state["sync_history"] << {
      "timestamp" => Time.now.iso8601,
      "results" => results
    }
    # Nur letzte 100 Einträge behalten
    state["sync_history"] = state["sync_history"][-100..-1]
    save_state(state)
  end

  log("=== Sync Agent beendet ===\n")
end

if __FILE__ == $0
  main
end
