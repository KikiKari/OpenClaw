#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "a95bf3344d46466e12f9a00e327ac75e2f42c591fccdb508ffce6e3fb194bd82", "source_sha256": "b470dd345a01d0a6c2fec8e2dd8ccd0a3b59e67f44ce1aa0e6f4d9c34420b355", "target_language": "ruby"}
# sync_agent.py — portiert nach ruby
# Quelle: python, OpenClaw@gateway2:skills/clawhub-git-sync-agent/scripts/sync_agent.py
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

# frozen_string_literal: true

# Permanenter ClawHub ↔ Git Sync Agent
# Multi-Node fähig, stündliche Ausführung

require 'json'
require 'fileutils'
require 'pathname'
require 'digest'

# Import sync functions
$LOAD_PATH << '/home/openclaw/.openclaw/workspace/scripts'
load 'sync_clawhub_git.rb'

CLAWHUB_DIR = Pathname.new('/home/openclaw/.openclaw/workspace/skills')
GIT_DIR = Pathname.new('/home/openclaw/.openclaw/workspace/git/skills')
STATE_FILE = Pathname.new('/home/openclaw/.openclaw/workspace/db/sync_state.json')

def load_state
  # Lädt den Sync-State
  if STATE_FILE.exist?
    JSON.parse(STATE_FILE.read)
  else
    { 'sync_history' => [], 'pending' => [] }
  end
end

def save_state(state)
  # Speichert den Sync-State
  # Ensure the parent directory exists (handle symlink to existing directory)
  unless STATE_FILE.dirname.directory?
    FileUtils.mkdir_p(STATE_FILE.dirname)
  end
  STATE_FILE.write(JSON.pretty_generate(state))
end

def get_all_skills
  # Findet alle Skills in beiden Verzeichnissen
  clawhub_skills = CLAWHUB_DIR.children.select do |d|
    d.directory? && !d.basename.to_s.start_with?('.') && !RESERVED_SKILL_NAMES.include?(d.basename.to_s) && (d + 'SKILL.md').exist?
  end.map(&:basename).map(&:to_s)

  git_skills = GIT_DIR.children.select do |d|
    d.directory? && !d.basename.to_s.start_with?('.') && !RESERVED_SKILL_NAMES.include?(d.basename.to_s) && (d + 'SKILL.md').exist?
  end.map(&:basename).map(&:to_s)

  (clawhub_skills + git_skills).uniq
end

def init_git_repo(skill_path, skill_name)
  # Initialisiert Git-Repo wenn nötig
  git_dir = skill_path + '.git'
  unless git_dir.exist?
    Dir.chdir(skill_path) do
      system('git', 'init', out: File::NULL, err: File::NULL)
      system('git', 'add', '.', out: File::NULL, err: File::NULL)
      system('git', 'commit', '-m', "Initial commit: #{skill_name} skill", out: File::NULL, err: File::NULL)
    end
    log("Git initialized for #{skill_name}")
  end
end

def sync_skill_bidirectional(skill_name)
  # Bidirektionale Synchronisation eines Skills
  clawhub_path = CLAWHUB_DIR + skill_name
  git_path = GIT_DIR + skill_name

  # Fall 1: Nur in ClawHub → zu Git
  if clawhub_path.exist? && !git_path.exist?
    log("NEW in ClawHub: #{skill_name} → syncing to Git")
    if sync_to_git(skill_name, dry_run: false)
      init_git_repo(git_path, skill_name)
      return 'synced_to_git'
    end

  # Fall 2: Nur in Git → zu ClawHub
  elsif git_path.exist? && !clawhub_path.exist?
    log("NEW in Git: #{skill_name} → syncing to ClawHub")
    if sync_to_clawhub(skill_name, dry_run: false)
      return 'synced_to_clawhub'
    end

  # Fall 3: In beiden vorhanden
  elsif clawhub_path.exist? && git_path.exist?
    unless validate_skill(clawhub_path)
      log("Validation failed for ClawHub skill: #{skill_name}", 'ERROR')
      return 'error'
    end
    unless validate_skill(git_path)
      log("Validation failed for Git skill: #{skill_name}", 'ERROR')
      return 'error'
    end

    clawhub_changes = preview_changes(clawhub_path, git_path)
    git_changes = preview_changes(git_path, clawhub_path)

    if clawhub_changes.empty? && git_changes.empty?
      log("Content is identical for: #{skill_name}")
      return 'no_change'
    end

    if !clawhub_changes.empty? && git_changes.empty?
      log("Content difference detected for: #{skill_name}")
      log("UPDATE: #{skill_name} ClawHub content is newer or different → syncing to Git")
      if sync_to_git(skill_name, dry_run: false)
        Dir.chdir(git_path) do
          system('git', 'add', '.', out: File::NULL, err: File::NULL)
          system('git', 'commit', '-m', "Sync from ClawHub content diff: #{Time.now.strftime('%Y-%m-%d %H:%M')}", out: File::NULL, err: File::NULL)
        end
        return 'updated_git'
      end
      log("Failed to sync #{skill_name} to Git after content diff", 'ERROR')
      return 'error'
    end

    if !git_changes.empty? && clawhub_changes.empty?
      log("Content difference detected for: #{skill_name}")
      log("UPDATE: #{skill_name} Git content is newer or different → syncing to ClawHub")
      if sync_to_clawhub(skill_name, dry_run: false)
        return 'updated_clawhub'
      end
      log("Failed to sync #{skill_name} to ClawHub after content diff", 'ERROR')
      return 'error'
    end

    log("Content difference detected for: #{skill_name}")
    if newest_mtime(clawhub_path) >= newest_mtime(git_path)
      log("UPDATE: #{skill_name} ClawHub content is newer or different → syncing to Git")
      if sync_to_git(skill_name, dry_run: false)
        Dir.chdir(git_path) do
          system('git', 'add', '.', out: File::NULL, err: File::NULL)
          system('git', 'commit', '-m', "Sync from ClawHub content diff: #{Time.now.strftime('%Y-%m-%d %H:%M')}", out: File::NULL, err: File::NULL)
        end
        return 'updated_git'
      end
    else
      log("UPDATE: #{skill_name} Git content is newer or different → syncing to ClawHub")
      if sync_to_clawhub(skill_name, dry_run: false)
        return 'updated_clawhub'
      end
    end

    log("Failed to resolve content diff for #{skill_name}", 'ERROR')
    return 'error'
  end

  'no_change'
end

# --- Hinzufügen dieser Hilfsfunktion ---
def get_hashes(skill_dir)
  # Erzeugt ein Dictionary von Datei-Hashes für einen Skill-Ordner.
  hashes = {}
  iter_sync_files(skill_dir).each do |file_path, rel_path|
    hashes[rel_path.to_s] = get_file_hash(file_path)
  end
  hashes
end

def preview_changes(source_dir, target_dir)
  # Berechnet Sync-Änderungen in einer Richtung, ohne zu schreiben.
  changes = []
  iter_sync_files(source_dir).each do |src_file, rel_path|
    tgt_file = target_dir + rel_path
    if !tgt_file.exist?
      changes << "ADD #{rel_path}"
    elsif get_file_hash(src_file) != get_file_hash(tgt_file)
      changes << "UPDATE #{rel_path}"
    end
  end
  changes
end

def newest_mtime(skill_dir)
  # Ermittelt die neueste mtime über alle relevanten Dateien.
  mtimes = iter_sync_files(skill_dir).map { |file_path, _| File.mtime(file_path) }
  mtimes.max || Time.at(0)
end

def main
  # Hauptfunktion des Sync-Agents mit Dry-Run Phase
  log('=== ClawHub ↔ Git Sync Agent gestartet ===')

  # Load previous state
  state = load_state
  all_skills = get_all_skills
  log("Gefundene Skills: #{all_skills.length}")

  # Dry-Run Phase: only report changes, no actual modifications
  log('--- Dry-Run Phase Start ---')
  all_skills.sort.each do |skill|
    # Perform dry-run sync in both directions to capture potential changes
    sync_to_git(skill, dry_run: true)
    sync_to_clawhub(skill, dry_run: true)
  end
  log('--- Dry-Run Phase End ---')

  results = {
    'synced_to_git' => [],
    'synced_to_clawhub' => [],
    'updated_git' => [],
    'updated_clawhub' => [],
    'no_change' => [],
    'errors' => []
  }

  # Actual Sync Phase
  all_skills.sort.each do |skill|
    begin
      result = sync_skill_bidirectional(skill)
      results[result] << skill
    rescue StandardError => e
      log("ERROR syncing #{skill}: #{e}", 'ERROR')
      results['errors'] << skill
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

  # State speichern
  state['sync_history'] ||= []
  state['sync_history'] << {
    'timestamp' => Time.now.iso8601,
    'results' => results
  }
  # Nur letzte 100 Einträge behalten
  state['sync_history'] = state['sync_history'].last(100)
  save_state(state)

  log("=== Sync Agent beendet ===\n")
end

main if __FILE__ == $PROGRAM_NAME
