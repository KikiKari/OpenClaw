#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "54ffe11d41b0b10deefb54390ef8c508cfbfb57205286a6decdddef3ad53e1b5", "source_sha256": "1bde9ce66616d24f21a9092c84abb4b447779e6077ec9035f2df678b92bb76f4", "target_language": "ruby"}
# sync_clawhub_git_local.py — portiert nach ruby
# Quelle: python, workspace@local:scripts/sync_clawhub_git_local.py
# auch in: workspace@local:scripts/sync_clawhub_git.py
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

# Bidirektionale ClawHub ↔ Git Synchronisation

require 'fileutils'
require 'digest'
require 'json'
require 'optparse'

# Konfiguration
WORKSPACE_DIR = File.expand_path(File.join(File.dirname(__FILE__), '..'))
CLAWHUB_DIR = File.join(WORKSPACE_DIR, 'skills')
GIT_DIR = File.join(WORKSPACE_DIR, 'git/skills')
BACKUP_DIR = File.join(WORKSPACE_DIR, 'backups/sync')
LOG_FILE = File.join(WORKSPACE_DIR, 'logs/sync-agent.log')

# Erstelle Verzeichnisse
FileUtils.mkdir_p(GIT_DIR)
FileUtils.mkdir_p(BACKUP_DIR)
FileUtils.mkdir_p(File.dirname(LOG_FILE))

# Logging
def log(message, level = "INFO")
  timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
  entry = "[#{timestamp}] [#{level}] #{message}"
  puts entry
  File.open(LOG_FILE, 'a') { |f| f.puts entry }
end

# Validierung
def validate_skill(skill_dir)
  # Prüft Skill-Struktur - SKILL.md required, scripts/ optional
  unless File.exist?(File.join(skill_dir, "SKILL.md"))
    log("Validation failed: #{File.basename(skill_dir)} missing SKILL.md", "ERROR")
    return false
  end
  true
end

# Backup
def create_backup(source, skill_name)
  # Erstellt Backup eines Skills
  timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
  backup_path = File.join(BACKUP_DIR, "#{skill_name}_#{timestamp}")
  
  # Backup verzeichnis löschen falls es existiert
  if Dir.exist?(backup_path)
    begin
      FileUtils.rm_rf(backup_path)
      log("Removed existing backup: #{backup_path}")
    rescue => e
      log("Failed to remove existing backup #{backup_path}: #{e}", "ERROR")
      return false
    end
  end
  
  begin
    FileUtils.cp_r(source, backup_path)
    log("Backup created: #{backup_path}")
    true
  rescue => e
    log("Backup failed: #{e}", "ERROR")
    false
  end
end

# Hash-Vergleich
def get_file_hash(file_path)
  # SHA256-Hash einer Datei
  Digest::SHA256.file(file_path).hexdigest
end

# Sync Richtung ClawHub → Git
def sync_to_git(skill_name, dry_run = true)
  # Synchronisiert ClawHub Skill zu Git
  source = File.join(CLAWHUB_DIR, skill_name)
  target = File.join(GIT_DIR, skill_name)
  
  unless validate_skill(source)
    return false
  end
  
  # Backup vor Änderungen (nur wenn target existiert)
  unless dry_run
    if Dir.exist?(target)
      create_backup(target, skill_name)
    end
  end
  
  # Änderungen erkennen
  changes = []
  Find.find(source) do |path|
    if File.file?(path)
      rel_path = Pathname.new(path).relative_path_from(Pathname.new(source)).to_s
      tgt_file = File.join(target, rel_path)
      
      # Vergleich
      if !File.exist?(tgt_file)
        changes.push("ADD #{rel_path}")
      elsif get_file_hash(path) != get_file_hash(tgt_file)
        changes.push("UPDATE #{rel_path}")
      end
    end
  end
  
  # Dry-Run Report
  if dry_run
    log("DRY-RUN: #{skill_name} - #{changes.length} changes")
    changes.each { |change| log("  #{change}") }
    return true
  end
  
  # Echte Synchronisation
  log("SYNC: #{skill_name} - Applying #{changes.length} changes")
  if Dir.exist?(target)
    FileUtils.rm_rf(target)
  end
  FileUtils.cp_r(source, target)
  log("SYNC: #{skill_name} - Complete")
  true
end

# Sync Richtung Git → ClawHub
def sync_to_clawhub(skill_name, dry_run = true)
  # Synchronisiert Git Skill zu ClawHub
  source = File.join(GIT_DIR, skill_name)
  target = File.join(CLAWHUB_DIR, skill_name)
  
  unless validate_skill(source)
    return false
  end
  
  # Backup vor Änderungen (nur wenn target existiert)
  unless dry_run
    if Dir.exist?(target)
      create_backup(target, skill_name)
    end
  end

  # Änderungen erkennen (gleiche Logik wie oben)
  changes = []
  Find.find(source) do |path|
    if File.file?(path)
      rel_path = Pathname.new(path).relative_path_from(Pathname.new(source)).to_s
      tgt_file = File.join(target, rel_path)

      if !File.exist?(tgt_file)
        changes.push("ADD #{rel_path}")
      elsif get_file_hash(path) != get_file_hash(tgt_file)
        changes.push("UPDATE #{rel_path}")
      end
    end
  end

  # Dry-Run Report
  if dry_run
    log("DRY-RUN: #{skill_name} - #{changes.length} changes")
    changes.each { |change| log("  #{change}") }
    return true
  end

  # Echte Synchronisation
  log("SYNC: #{skill_name} - Applying #{changes.length} changes")
  if Dir.exist?(target)
    FileUtils.rm_rf(target)
  end
  FileUtils.cp_r(source, target)
  log("SYNC: #{skill_name} - Complete")
  true
end

# Hauptfunktion
def main
  require 'find'
  require 'pathname'
  
  options = {}
  OptionParser.new do |opts|
    opts.banner = "Usage: sync_clawhub_git_local.rb [options]"
    
    opts.on("--skill SKILL", "Skill name") do |v|
      options[:skill] = v
    end
    
    opts.on("--direction DIRECTION", [:to_git, :to_clawhub], "Sync direction") do |v|
      options[:direction] = v
    end
    
    opts.on("--dry-run", "Nur Änderungen anzeigen") do |v|
      options[:dry_run] = v
    end
    
    opts.on("--force", "Ohne Backup") do |v|
      options[:force] = v
    end
  end.parse!
  
  if !options[:skill] || !options[:direction]
    puts "Error: --skill and --direction are required"
    exit 1
  end
  
  log("Starting sync: #{options[:skill]} (#{options[:direction]})")
  
  success = if options[:direction] == :to_git
              sync_to_git(options[:skill], options[:dry_run])
            else
              sync_to_clawhub(options[:skill], options[:dry_run])
            end
  
  unless success
    log("Sync failed", "ERROR")
    exit 1
  end
  
  log("Sync completed")
end

main if __FILE__ == $0
