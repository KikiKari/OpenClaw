#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "d64327ebf66bdf48fa3beecf4e4dea3bd678a517757b2338dc8c6122fa1956b4", "source_sha256": "61022646f18bff569b8abac746e220ff7bb0333624b5b9fe62e2210671ee2acc", "target_language": "ruby"}
# sync_clawhub_git.py — portiert nach ruby
# Quelle: python, OpenClaw@gateway1:scripts/sync_clawhub_git.py
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

# frozen_string_literal: true

#
# Bidirektionale ClawHub ↔ Git Synchronisation
#

require 'fileutils'
require 'digest'
require 'json'
require 'time'

# Konfiguration
CLAWHUB_DIR = Pathname.new('/home/openclaw/.openclaw/workspace/skills')
GIT_DIR = Pathname.new('/home/openclaw/.openclaw/workspace/git/skills')
BACKUP_DIR = Pathname.new('/home/openclaw/.openclaw/workspace/backups/sync')
LOG_FILE = Pathname.new('/home/openclaw/.openclaw/workspace/logs/sync-agent.log')

# Erstelle Verzeichnisse
[CLAWHUB_DIR, GIT_DIR, BACKUP_DIR, LOG_FILE.dirname].each do |dir|
  dir.mkpath unless dir.exist?
end

# Logging
def log(message, level = 'INFO')
  timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
  entry = "[#{timestamp}] [#{level}] #{message}"
  puts entry
  File.open(LOG_FILE, 'a') { |f| f.puts entry }
end

# Validierung
def validate_skill(skill_dir)
  # Prüft Skill-Struktur - SKILL.md required, scripts/ optional
  return true if (skill_dir + 'SKILL.md').exist?

  log("Validation failed: #{skill_dir.basename} missing SKILL.md", 'ERROR')
  false
end

# Backup
def create_backup(source, skill_name)
  # Erstellt Backup eines Skills
  timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
  backup_path = BACKUP_DIR + "#{skill_name}_#{timestamp}"

  # Backup verzeichnis löschen falls es existiert
  if backup_path.exist?
    begin
      FileUtils.rm_rf(backup_path)
      log("Removed existing backup: #{backup_path}")
    rescue => e
      log("Failed to remove existing backup #{backup_path}: #{e}", 'ERROR')
      return false
    end
  end

  begin
    FileUtils.cp_r(source, backup_path)
    log("Backup created: #{backup_path}")
    true
  rescue => e
    log("Backup failed: #{e}", 'ERROR')
    false
  end
end

# Hash-Vergleich
def get_file_hash(file_path)
  # SHA256-Hash einer Datei
  Digest::SHA256.file(file_path).hexdigest
end

# Sync Richtung ClawHub → Git
def sync_to_git(skill_name, dry_run: true)
  # Synchronisiert ClawHub Skill zu Git
  source = CLAWHUB_DIR + skill_name
  target = GIT_DIR + skill_name

  return false unless validate_skill(source)

  # Backup vor Änderungen (nur wenn target existiert)
  create_backup(target, skill_name) if !dry_run && target.exist?

  # Änderungen erkennen
  changes = []
  source.find do |path|
    next unless path.file?

    rel_path = path.relative_path_from(source)
    tgt_file = target + rel_path

    if !tgt_file.exist?
      changes << "ADD #{rel_path}"
    elsif get_file_hash(path) != get_file_hash(tgt_file)
      changes << "UPDATE #{rel_path}"
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
  if target.exist?
    FileUtils.rm_rf(target)
  end
  FileUtils.cp_r(source, target)
  # Entferne .git Ordner falls vorhanden
  git_folder = target + '.git'
  FileUtils.rm_rf(git_folder) if git_folder.exist?
  log("SYNC: #{skill_name} - Complete")
  true
end

# Sync Richtung Git → ClawHub
def sync_to_clawhub(skill_name, dry_run: true)
  # Synchronisiert Git Skill zu ClawHub
  source = GIT_DIR + skill_name
  target = CLAWHUB_DIR + skill_name

  return false unless validate_skill(source)

  # Backup vor Änderungen (nur wenn target existiert)
  create_backup(target, skill_name) if !dry_run && target.exist?

  # Änderungen erkennen (gleiche Logik wie oben)
  changes = []
  source.find do |path|
    next unless path.file?

    rel_path = path.relative_path_from(source)
    tgt_file = target + rel_path

    if !tgt_file.exist?
      changes << "ADD #{rel_path}"
    elsif get_file_hash(path) != get_file_hash(tgt_file)
      changes << "UPDATE #{rel_path}"
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
  if target.exist?
    FileUtils.rm_rf(target)
  end
  FileUtils.cp_r(source, target)
  # Entferne .git Ordner falls vorhanden
  git_folder = target + '.git'
  FileUtils.rm_rf(git_folder) if git_folder.exist?
  log("SYNC: #{skill_name} - Complete")
  true
end

# Hauptfunktion
def main
  require 'optparse'

  options = {}
  OptionParser.new do |opts|
    opts.banner = 'Usage: sync_clawhub_git.rb [options]'

    opts.on('--skill SKILL', 'Skill name') do |v|
      options[:skill] = v
    end

    opts.on('--direction DIRECTION', ['to-git', 'to-clawhub'], 'Sync direction') do |v|
      options[:direction] = v
    end

    opts.on('--dry-run', 'Nur Änderungen anzeigen') do |v|
      options[:dry_run] = v
    end

    opts.on('--force', 'Ohne Backup') do |v|
      options[:force] = v
    end
  end.parse!

  if !options[:skill] || !options[:direction]
    puts 'Error: --skill and --direction are required'
    exit 1
  end

  log("Starting sync: #{options[:skill]} (#{options[:direction]})")

  success = if options[:direction] == 'to-git'
              sync_to_git(options[:skill], dry_run: options[:dry_run])
            else
              sync_to_clawhub(options[:skill], dry_run: options[:dry_run])
            end

  unless success
    log('Sync failed', 'ERROR')
    exit 1
  end

  log('Sync completed')
end

main if __FILE__ == $0
