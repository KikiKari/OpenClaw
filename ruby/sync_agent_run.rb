#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "467c7f8c9dbf9e312ad441d02c1b5e8314d83f7ee75ed80b0b092564c3381537", "source_sha256": "7012bf54a442a99950a2c73407058fd2f7330b956a58bc3b2698e87ee308dec9", "target_language": "ruby"}
# sync_agent_run.py — portiert nach ruby
# Quelle: python, OpenClaw@gateway1:scripts/sync_agent_run.py
# auch in: OpenClaw@gateway2:scripts/sync_agent_run.py
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

# ClawHub ↔ Git Sync Agent - Produktionslauf

require 'pathname'
require 'time'
require 'json'

$LOAD_PATH << '/home/openclaw/.openclaw/workspace/scripts'
load 'sync_clawhub_git.rb'

CLAWHUB_DIR = Pathname.new('/home/openclaw/.openclaw/workspace/skills')
GIT_DIR = Pathname.new('/home/openclaw/.openclaw/workspace/git/skills')

def file_mtime(path)
  begin
    files = path.children.select { |p| p.file? && !p.to_s.include?('.git') }
    files.each { |p| files.concat(p.children) if p.directory? }
    return 0 if files.empty?
    files.map { |p| File.mtime(p).to_f }.max
  rescue
    0
  end
end

def log(message, level = "INFO")
  puts message
end

log("=" * 70)
log("CLAWHUB ↔ GIT SYNC AGENT - PRODUKTIONS-LAUF")
log("Zeitstempel: #{Time.now.iso8601}")
log("=" * 70)

clawhub_skills = CLAWHUB_DIR.children.select(&:directory?).map(&:basename).map(&:to_s).reject { |name| name.start_with?('.') }.to_set
git_skills = GIT_DIR.children.select(&:directory?).map(&:basename).map(&:to_s).reject { |name| name.start_with?('.') }.to_set

results = {
  "synced_to_git" => [],
  "synced_to_clawhub" => [],
  "up_to_date" => [],
  "errors" => []
}

# 1. NEU in ClawHub → zu Git syncen
log("\n[PHASE 1] ClawHub → Git Synchronisation")
log("-" * 40)

new_in_clawhub = (clawhub_skills - git_skills).sort
new_in_clawhub.each do |skill|
  begin
    if validate_skill(CLAWHUB_DIR / skill)
      log("→ Synchronisiere #{skill} zu Git...")
      if sync_to_git(skill, false)
        # Git init
        git_path = GIT_DIR / skill
        Dir.chdir(git_path) do
          system('git init -q 2>/dev/null')
          system('git add . -f 2>/dev/null')
          dt = Time.now.strftime("%Y-%m-%d %H:%M")
          system("git commit -m \"Initial: #{skill}\" -q 2>/dev/null")
        end
        results["synced_to_git"] << skill
        log("  ✓ #{skill} synchronisiert & Git initialisiert")
      else
        results["errors"] << "#{skill} (sync failed)"
      end
    else
      results["errors"] << "#{skill} (invalid)"
    end
  rescue => e
    log("  ✗ ERROR: #{skill} - #{e}", "ERROR")
    results["errors"] << "#{skill} (exception)"
  end
end

# 2. In beiden - prüfe Änderungen
log("\n[PHASE 2] Prüfe existierende Skills auf Änderungen")
log("-" * 40)

in_both = (clawhub_skills & git_skills).sort
in_both.each do |skill|
  begin
    c_mtime = file_mtime(CLAWHUB_DIR / skill)
    g_mtime = file_mtime(GIT_DIR / skill)
    diff = c_mtime - g_mtime

    if diff.abs > 60
      if diff > 0
        log("→ #{skill}: ClawHub neuer (+#{diff.to_i}s) → sync zu Git")
        if sync_to_git(skill, false)
          git_path = GIT_DIR / skill
          Dir.chdir(git_path) do
            system('git add . -f 2>/dev/null')
            dt = Time.now.strftime("%Y-%m-%d %H:%M")
            system("git commit -m \"Sync from ClawHub: #{dt}\" -q 2>/dev/null")
          end
          results["synced_to_git"] << skill
        else
          results["errors"] << "#{skill} (update failed)"
        end
      else
        log("→ #{skill}: Git neuer (+#{diff.abs.to_i}s) → sync zu ClawHub")
        if sync_to_clawhub(skill, false)
          results["synced_to_clawhub"] << skill
        else
          results["errors"] << "#{skill} (update failed)"
        end
      end
    else
      results["up_to_date"] << skill
    end
  rescue => e
    log("  ✗ ERROR: #{skill} - #{e}", "ERROR")
    results["errors"] << "#{skill} (exception)"
  end
end

# ZUSAMMENFASSUNG
log("\n" + "=" * 70)
log("SYNCHRONISATION ABGESCHLOSSEN")
log("=" * 70)
log("Zu Git synchronisiert:     #{results['synced_to_git'].length}")
unless results['synced_to_git'].empty?
  log("  #{results['synced_to_git'].join(', ')}")
end
log("Zu ClawHub synchronisiert: #{results['synced_to_clawhub'].length}")
unless results['synced_to_clawhub'].empty?
  log("  #{results['synced_to_clawhub'].join(', ')}")
end
log("Bereits aktuell:           #{results['up_to_date'].length}")
log("Fehler:                    #{results['errors'].length}")
unless results['errors'].empty?
  log("  #{results['errors'].join(', ')}")
end
log("=" * 70)

# Speichere State
STATE_FILE = Pathname.new("/home/openclaw/.openclaw/workspace/db/sync_state.json")
STATE_FILE.dirname.mkpath
state = {"last_run" => Time.now.iso8601, "results" => results}
File.write(STATE_FILE, JSON.pretty_generate(state))
log("State gespeichert: #{STATE_FILE}")
