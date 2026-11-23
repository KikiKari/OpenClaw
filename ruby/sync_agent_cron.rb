#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "772eb34a995835d2f0dd701291ebced71e77028d80e9062fe72cbf349840df4c", "source_sha256": "6dcc2c07911eedad64d93e999a1605091bebc0ed6eadad479df838626620545d", "target_language": "ruby"}
# sync_agent_cron.py — portiert nach ruby
# Quelle: python, OpenClaw@gateway1:scripts/sync_agent_cron.py
# auch in: OpenClaw@gateway2:scripts/sync_agent_cron.py
# auch in: workspace@local:scripts/sync_agent_cron.py
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

# frozen_string_literal: true

# ClawHub ↔ Git Sync Agent - Cron Version mit Dry-Run + Auto-Sync

require 'pathname'
require 'fileutils'
require 'json'
require 'time'

CLAWHUB_DIR = Pathname.new('/home/openclaw/.openclaw/workspace/skills')
GIT_DIR = Pathname.new('/home/openclaw/.openclaw/workspace/git/skills')
LOG_FILE = Pathname.new('/home/openclaw/.openclaw/workspace/logs/sync-agent.log')

# Füge das Skriptverzeichnis zum Load Path hinzu
$LOAD_PATH.unshift('/home/openclaw/.openclaw/workspace/scripts')

# Lade die benötigten Module
load 'sync_clawhub_git.rb'

def file_mtime(path)
  begin
    files = path.glob('**/*').select { |p| p.file? && !p.to_s.include?('.git') }
    return 0 if files.empty?
    files.map { |p| p.mtime }.max.to_f
  rescue StandardError
    0
  end
end

def write_to_log(message, level = 'INFO')
  timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
  entry = "[#{timestamp}] [#{level}] #{message}"
  puts entry
  File.open(LOG_FILE, 'a') { |f| f.puts entry }
end

# Hauptlog-Funktion überschreiben
module SyncClawhubGit
  def self.log(message, level = 'INFO')
    write_to_log(message, level)
  end
end

write_to_log('=' * 70)
write_to_log('CLAWHUB ↔ GIT SYNC AGENT - CRON LAUF')
write_to_log("Zeitstempel: #{Time.now.iso8601}")
write_to_log('=' * 70)

clawhub_skills = CLAWHUB_DIR.children.select(&:directory?).map(&:basename).map(&:to_s).reject { |name| name.start_with?('.') }.to_set
git_skills = GIT_DIR.children.select(&:directory?).map(&:basename).map(&:to_s).reject { |name| name.start_with?('.') }.to_set

# DRY-RUN: Erkenne Änderungen
write_to_log("\n[DRY-RUN] Analysiere Änderungen...")

changes_detected = {
  'new_in_clawhub' => [],
  'new_in_git' => [],
  'clawhub_newer' => [],
  'git_newer' => [],
  'synced' => []
}

# 1. Neue Skills
new_in_clawhub = (clawhub_skills - git_skills).sort
new_in_git = (git_skills - clawhub_skills).sort
changes_detected['new_in_clawhub'] = new_in_clawhub
changes_detected['new_in_git'] = new_in_git

# 2. Existierende prüfen
in_both = (clawhub_skills & git_skills).sort
in_both.each do |skill|
  c_mtime = file_mtime(CLAWHUB_DIR.join(skill))
  g_mtime = file_mtime(GIT_DIR.join(skill))
  diff = c_mtime - g_mtime

  if diff.abs > 60
    if diff > 0
      changes_detected['clawhub_newer'] << [skill, diff]
    else
      changes_detected['git_newer'] << [skill, diff.abs]
    end
  else
    changes_detected['synced'] << skill
  end
end

# Report
total_changes = new_in_clawhub.length + new_in_git.length + changes_detected['clawhub_newer'].length + changes_detected['git_newer'].length
write_to_log("Neu in ClawHub: #{new_in_clawhub.length}")
write_to_log("Neu in Git: #{new_in_git.length}")
write_to_log("ClawHub neuer: #{changes_detected['clawhub_newer'].length}")
write_to_log("Git neuer: #{changes_detected['git_newer'].length}")
write_to_log("Synchron: #{changes_detected['synced'].length}")

if total_changes.zero?
  write_to_log("\n✅ Keine Änderungen erkannt. Sync nicht nötig.")
  write_to_log('=' * 70)
  exit(0)
end

write_to_log("\n🔄 #{total_changes} Änderungen erkannt - starte Synchronisation...")

# ECHTE SYNCHRONISATION
results = { 'synced_to_git' => [], 'synced_to_clawhub' => [], 'up_to_date' => [], 'errors' => [] }

# 1. NEU in ClawHub → zu Git
new_in_clawhub.each do |skill|
  begin
    if SyncClawhubGit.validate_skill(CLAWHUB_DIR.join(skill))
      write_to_log("→ Synchronisiere #{skill} zu Git...")
      if SyncClawhubGit.sync_to_git(skill, false)
        git_path = GIT_DIR.join(skill)
        Dir.chdir(git_path) do
          system('git init -q 2>/dev/null', out: '/dev/null')
          system('git add . -f 2>/dev/null', out: '/dev/null')
          system("git commit -m \"Initial: #{skill}\" -q 2>/dev/null", out: '/dev/null')
        end
        results['synced_to_git'] << skill
        write_to_log("  ✓ #{skill} synchronisiert")
      end
    else
      results['errors'] << "#{skill} (invalid)"
    end
  rescue StandardError => e
    write_to_log("  ✗ ERROR: #{skill} - #{e.message}", 'ERROR')
    results['errors'] << skill
  end
end

# 2. NEU in Git → zu ClawHub
new_in_git.each do |skill|
  begin
    if SyncClawhubGit.validate_skill(GIT_DIR.join(skill))
      write_to_log("→ Synchronisiere #{skill} zu ClawHub...")
      if SyncClawhubGit.sync_to_clawhub(skill, false)
        results['synced_to_clawhub'] << skill
        write_to_log("  ✓ #{skill} synchronisiert")
      end
    else
      results['errors'] << "#{skill} (invalid)"
    end
  rescue StandardError => e
    write_to_log("  ✗ ERROR: #{skill} - #{e.message}", 'ERROR')
    results['errors'] << skill
  end
end

# 3. Updates
changes_detected['clawhub_newer'].each do |skill, diff|
  begin
    write_to_log("→ Update #{skill} (ClawHub +#{diff.to_i}s neuer)...")
    if SyncClawhubGit.sync_to_git(skill, false)
      git_path = GIT_DIR.join(skill)
      Dir.chdir(git_path) do
        system('git add . -f 2>/dev/null', out: '/dev/null')
        dt = Time.now.strftime('%Y-%m-%d %H:%M')
        system("git commit -m \"Sync from ClawHub: #{dt}\" -q 2>/dev/null", out: '/dev/null')
      end
      results['synced_to_git'] << skill
      write_to_log("  ✓ #{skill} aktualisiert")
    end
  rescue StandardError => e
    write_to_log("  ✗ ERROR: #{skill} - #{e.message}", 'ERROR')
    results['errors'] << skill
  end
end

changes_detected['git_newer'].each do |skill, diff|
  begin
    write_to_log("→ Update #{skill} (Git +#{diff.to_i}s neuer)...")
    if SyncClawhubGit.sync_to_clawhub(skill, false)
      results['synced_to_clawhub'] << skill
      write_to_log("  ✓ #{skill} aktualisiert")
    end
  rescue StandardError => e
    write_to_log("  ✗ ERROR: #{skill} - #{e.message}", 'ERROR')
    results['errors'] << skill
  end
end

results['up_to_date'] = changes_detected['synced']

# ZUSAMMENFASSUNG
write_to_log("\n" + '=' * 70)
write_to_log('SYNCHRONISATION ABGESCHLOSSEN')
write_to_log('=' * 70)
write_to_log("Zu Git synchronisiert:     #{results['synced_to_git'].length}")
write_to_log("Zu ClawHub synchronisiert: #{results['synced_to_clawhub'].length}")
write_to_log("Bereits aktuell:           #{results['up_to_date'].length}")
write_to_log("Fehler:                    #{results['errors'].length}")
unless results['errors'].empty?
  write_to_log("  Fehlerhafte: #{results['errors'].join(', ')}")
end
write_to_log('=' * 70)

# State speichern
STATE_FILE = Pathname.new('/home/openclaw/.openclaw/workspace/db/sync_state.json')
STATE_FILE.dirname.mkpath
state = {
  'last_run' => Time.now.iso8601,
  'results' => results,
  'changes_detected' => changes_detected.transform_values { |v| v.is_a?(Array) ? v.length : v }
}
File.write(STATE_FILE, JSON.pretty_generate(state))
write_to_log("State gespeichert: #{STATE_FILE}")
