#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "a23193eff7095114fd9d01059cca8da00e55fb848bdda1171e1c4409e706401d", "source_sha256": "bdae82d3ec0fc4e8614fc802f7059942e7aba36bab0cd06bdf01f8376c3c863c", "target_language": "ruby"}
# sync_status.py — portiert nach ruby
# Quelle: python, OpenClaw@gateway1:skills/sync-utils/scripts/sync_status.py
# auch in: OpenClaw@gateway2:skills/sync-utils/scripts/sync_status.py
# auch in: workspace@local:git/skills/sync-utils/scripts/sync_status.py
# auch in: workspace@local:skills/sync-utils/scripts/sync_status.py
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

# frozen_string_literal: true

# Sync Status - Zeigt Status aller Skills

require 'json'
require 'time'

# Import sync functions
$LOAD_PATH << '/home/openclaw/.openclaw/workspace/scripts'
load 'sync_clawhub_git.rb'

CLAWHUB_DIR = Pathname.new('/home/openclaw/.openclaw/workspace/skills')
GIT_DIR = Pathname.new('/home/openclaw/.openclaw/workspace/git/skills')
STATE_FILE = Pathname.new('/home/openclaw/.openclaw/workspace/db/sync_state.json')

def check_skill_status(skill_name)
  # Prüft Status eines Skills
  clawhub_path = CLAWHUB_DIR.join(skill_name)
  git_path = GIT_DIR.join(skill_name)

  status = {
    'name' => skill_name,
    'in_clawhub' => clawhub_path.exist?,
    'in_git' => git_path.exist?,
    'has_git_repo' => (git_path.join('.git').exist? if git_path.exist?),
    'status' => 'unknown',
    'last_modified' => {}
  }

  # Status bestimmen
  if status['in_clawhub'] && !status['in_git']
    status['status'] = 'only_clawhub'
  elsif status['in_git'] && !status['in_clawhub']
    status['status'] = 'only_git'
  elsif status['in_clawhub'] && status['in_git']
    # Timestamps vergleichen
    begin
      clawhub_files = clawhub_path.children(true).flat_map do |p|
        p.file? ? [p] : p.find { |sub| sub.file? }
      end.compact

      git_files = git_path.children(true).flat_map do |p|
        next [] if p.to_s.include?('.git')
        p.file? ? [p] : p.find { |sub| sub.file? && !sub.to_s.include?('.git') }
      end.compact

      clawhub_mtime = clawhub_files.map(&:mtime).max
      git_mtime = git_files.map(&:mtime).max

      status['last_modified']['clawhub'] = clawhub_mtime.strftime('%Y-%m-%d %H:%M:%S')
      status['last_modified']['git'] = git_mtime.strftime('%Y-%m-%d %H:%M:%S')

      if (clawhub_mtime - git_mtime).abs < 60
        status['status'] = 'synced'
      elsif clawhub_mtime > git_mtime
        status['status'] = 'clawhub_newer'
      else
        status['status'] = 'git_newer'
      end
    rescue StandardError
      status['status'] = 'error'
    end
  end

  status
end

def main
  # Hauptfunktion
  puts '=' * 80
  puts 'ClawHub ↔ Git Sync Status'
  puts '=' * 80
  puts "Zeitpunkt: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
  puts

  # Alle Skills finden
  all_skills = Set.new
  if CLAWHUB_DIR.exist?
    CLAWHUB_DIR.children.select(&:directory?).each do |d|
      all_skills.add(d.basename.to_s) unless d.basename.to_s.start_with?('.')
    end
  end
  if GIT_DIR.exist?
    GIT_DIR.children.select(&:directory?).each do |d|
      all_skills.add(d.basename.to_s) unless d.basename.to_s.start_with?('.')
    end
  end

  # Status-Kategorien
  categories = {
    'synced' => [],
    'clawhub_newer' => [],
    'git_newer' => [],
    'only_clawhub' => [],
    'only_git' => [],
    'error' => []
  }

  # Status für jeden Skill prüfen
  all_skills.sort.each do |skill|
    status = check_skill_status(skill)
    categories[status['status']] << status
  end

  # Ausgabe
  puts "📊 Gesamt: #{all_skills.length} Skills\n"

  # Synchronisiert
  if categories['synced'].any?
    puts "✅ Synchronisiert (#{categories['synced'].length})"
    categories['synced'].each { |s| puts "   - #{s['name']}" }
    puts
  end

  # ClawHub neuer
  if categories['clawhub_newer'].any?
    puts "🔄 ClawHub neuer (#{categories['clawhub_newer'].length})"
    categories['clawhub_newer'].each do |s|
      puts "   - #{s['name']} (ClawHub: #{s['last_modified']['clawhub']})"
    end
    puts
  end

  # Git neuer
  if categories['git_newer'].any?
    puts "🔄 Git neuer (#{categories['git_newer'].length})"
    categories['git_newer'].each do |s|
      puts "   - #{s['name']} (Git: #{s['last_modified']['git']})"
    end
    puts
  end

  # Nur in ClawHub
  if categories['only_clawhub'].any?
    puts "📦 Nur in ClawHub (#{categories['only_clawhub'].length})"
    categories['only_clawhub'].each { |s| puts "   - #{s['name']}" }
    puts
  end

  # Nur in Git
  if categories['only_git'].any?
    puts "📁 Nur in Git (#{categories['only_git'].length})"
    categories['only_git'].each { |s| puts "   - #{s['name']}" }
    puts
  end

  # Fehler
  if categories['error'].any?
    puts "❌ Fehler (#{categories['error'].length})"
    categories['error'].each { |s| puts "   - #{s['name']}" }
    puts
  end

  # State-File Info
  if STATE_FILE.exist?
    state = JSON.parse(STATE_FILE.read)
    last_runs = state.dig('last_sync', 'keys') || []
    unless last_runs.empty?
      puts "📅 Letzter automatischer Sync: #{last_runs.last}"
    end
  end

  puts '=' * 80
end

main if __FILE__ == $PROGRAM_NAME
