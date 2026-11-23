#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "450be9dde3ddfe0ccda28ed6eadf03d55d532e02756c05f1e2d6dd86f7da4213", "source_sha256": "2a279f44187e822afbb6a0af5593a2890c8e99b41f885f5d063355b6ea20b921", "target_language": "ruby"}
# sync_clawhub_git.py — portiert nach ruby
# Quelle: python, OpenClaw@gateway2:scripts/sync_clawhub_git.py
# auch in: Projects@clawhub:clawhub/Skills/sync_clawhub_git.py
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

require 'fileutils'
require 'digest'
require 'json'
require 'pathname'
require 'optparse'
require 'logger'

# Konfiguration
# Resolve paths relative to this repository so the helper works both in the
# hosted workspace and in environments without a /workspace mount.
WORKSPACE_ROOT = File.expand_path(File.join(File.dirname(__FILE__), '..'))
CLAWHUB_DIR = File.join(WORKSPACE_ROOT, "skills")
GIT_DIR = File.join(WORKSPACE_ROOT, "git", "skills")
BACKUP_DIR = File.join(WORKSPACE_ROOT, "backups", "sync")
LOG_FILE = File.join(WORKSPACE_ROOT, "logs", "sync-agent.log")
IGNORED_NAMES = [".git", ".clawhub", "node_modules", "__pycache__", ".pytest_cache"].to_set
RESERVED_SKILL_NAMES = ["github-clones", "skills", "backups", ".restore", "git", "Abstraktionen"].to_set
PRESERVED_TARGET_NAMES = IGNORED_NAMES

# Erstelle Verzeichnisse
FileUtils.mkdir_p(GIT_DIR)
FileUtils.mkdir_p(BACKUP_DIR)
FileUtils.mkdir_p(File.dirname(LOG_FILE))

# Logging
def log(message, level = "INFO")
  timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
  entry = "[#{timestamp}] [#{level}] #{message}"
  puts entry
  File.open(LOG_FILE, 'a') { |f| f.puts(entry) }
end

# Validierung
def validate_skill(skill_dir)
  """Prüft Skill-Struktur - SKILL.md required, scripts/ optional"""
  skill_name = File.basename(skill_dir)
  if RESERVED_SKILL_NAMES.include?(skill_name)
    log("Validation failed: #{skill_name} is reserved and must not be synced as a skill", "ERROR")
    return false
  end
  unless File.exist?(File.join(skill_dir, "SKILL.md"))
    log("Validation failed: #{skill_name} missing SKILL.md", "ERROR")
    return false
  end
  true
end

def _is_ignored_path(path_parts)
  return path_parts.any? { |part| IGNORED_NAMES.include?(part) } || path_parts.last&.end_with?(".pyc")
end

def _is_generated_duplicate_path(root, rel_path_parts)
  """Detect generated duplicate folders such as <skill>/<skill> or scripts/scripts."""
  return false if rel_path_parts.empty?
  if rel_path_parts.first == File.basename(root)
    return true
  end
  (1...rel_path_parts.length).each do |i|
    if rel_path_parts[i] == rel_path_parts[i - 1]
      return true
    end
  end
  false
end

def iter_sync_files(root)
  """Yield files that should participate in sync comparisons."""
  Dir.glob(File.join(root, "**/*"), File::FNM_DOTMATCH).select { |f| File.file?(f) }.each do |file|
    rel_path = Pathname.new(file).relative_path_from(Pathname.new(root)).to_s
    next if rel_path.start_with?(".")
    
    rel_parts = rel_path.split("/")
    
    # Skip ignored paths
    next if _is_ignored_path(rel_parts)
    
    # Skip generated duplicates
    next if _is_generated_duplicate_path(root, rel_parts)
    
    # Special handling for SKILL.md - only allow at root
    if File.basename(file) == "SKILL.md" && rel_path != "SKILL.md"
      next
    end
    
    yield file, rel_path
  end
end

def reset_sync_target(target)
  """Remove stale synced content before copying, preserving local-only metadata."""
  FileUtils.mkdir_p(target)
  Dir.foreach(target) do |child|
    next if ['.', '..'].include?(child)
    next if PRESERVED_TARGET_NAMES.include?(child)
    child_path = File.join(target, child)
    if File.directory?(child_path) && !File.symlink?(child_path)
      FileUtils.rm_rf(child_path)
    else
      File.delete(child_path)
    end
  end
end

def copy_sync_files(source, target)
  reset_sync_target(target)
  iter_sync_files(source) do |src_file, rel_path|
    dest_file = File.join(target, rel_path)
    FileUtils.mkdir_p(File.dirname(dest_file))
    FileUtils.cp(src_file, dest_file)
  end
end

# Backup
def create_backup(source, skill_name)
  """Erstellt Backup eines Skills"""
  timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
  backup_path = File.join(BACKUP_DIR, "#{skill_name}_#{timestamp}")
  
  # Backup verzeichnis löschen falls es existiert
  if File.exist?(backup_path)
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
    return true
  rescue => e
    log("Backup failed: #{e}", "ERROR")
    return false
  end
end

# Hash-Vergleich
def get_file_hash(file_path)
  """SHA256-Hash einer Datei"""
  # Ensure the path points to a regular file.
  return "" unless File.file?(file_path)
  
  begin
    Digest::SHA256.file(file_path).hexdigest
  rescue => e
    log("Failed to hash #{file_path}: #{e}", "ERROR")
    ""
  end
end

# Sync Richtung ClawHub → Git
def sync_to_git(skill_name, dry_run: true)
  """Synchronisiert ClawHub Skill zu Git"""
  source = File.join(CLAWHUB_DIR, skill_name)
  target = File.join(GIT_DIR, skill_name)
  
  unless validate_skill(source)
    return false
  end
  
  # Backup vor Änderungen (nur wenn target existiert)
  if !dry_run && File.exist?(target)
    create_backup(target, skill_name)
  end
  
  # Änderungen erkennen
  changes = []
  iter_sync_files(source) do |src_file, rel_path|
    tgt_file = File.join(target, rel_path)
    if !File.exist?(tgt_file)
      changes.push("ADD #{rel_path}")
    elsif get_file_hash(src_file) != get_file_hash(tgt_file)
      changes.push("UPDATE #{rel_path}")
    end
  end
  
  # Dry-Run Report
  if dry_run
    log("DRY-RUN: #{skill_name} - #{changes.length} changes")
    changes.each do |change|
      log("  #{change}")
    end
    return true
  end
  
  # Echte Synchronisation
  log("SYNC: #{skill_name} - Applying #{changes.length} changes")
  copy_sync_files(source, target)
  log("SYNC: #{skill_name} - Complete")
  return true
end

# Sync Richtung Git → ClawHub
def sync_to_clawhub(skill_name, dry_run: true)
  """Synchronisiert Git Skill zu ClawHub"""
  source = File.join(GIT_DIR, skill_name)
  target = File.join(CLAWHUB_DIR, skill_name)
  
  unless validate_skill(source)
    return false
  end
  
  # Backup vor Änderungen (nur wenn target existiert)
  if !dry_run && File.exist?(target)
    create_backup(target, skill_name)
  end

  # Änderungen erkennen (gleiche Logik wie oben)
  changes = []
  iter_sync_files(source) do |src_file, rel_path|
    tgt_file = File.join(target, rel_path)
    if !File.exist?(tgt_file)
      changes.push("ADD #{rel_path}")
    elsif get_file_hash(src_file) != get_file_hash(tgt_file)
      changes.push("UPDATE #{rel_path}")
    end
  end

  # Dry-Run Report
  if dry_run
    log("DRY-RUN: #{skill_name} - #{changes.length} changes")
    changes.each do |change|
      log("  #{change}")
    end
    return true
  end

  # Echte Synchronisation
  log("SYNC: #{skill_name} - Applying #{changes.length} changes")
  copy_sync_files(source, target)
  log("SYNC: #{skill_name} - Complete")
  return true
end

# Hauptfunktion
def main
  options = {}
  OptionParser.new do |opts|
    opts.banner = "Usage: sync_clawhub_git.rb [options]"
    
    opts.on("--skill SKILL", "Skill name") do |v|
      options[:skill] = v
    end
    
    opts.on("--direction DIRECTION", "Direction (to-git or to-clawhub)") do |v|
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
    puts "Missing required arguments"
    exit 1
  end
  
  log("Starting sync: #{options[:skill]} (#{options[:direction]})")
  
  success = if options[:direction] == 'to-git'
              sync_to_git(options[:skill], dry_run: options[:dry_run])
            else
              sync_to_clawhub(options[:skill], dry_run: options[:dry_run])
            end
  
  unless success
    log("Sync failed", "ERROR")
    exit 1
  end
  
  log("Sync completed")
end

main if __FILE__ == $0
