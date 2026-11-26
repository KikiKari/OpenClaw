#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "989a92392bdacb57865eff6317421ee66833d4992a49a16731f429522ca1601e", "source_sha256": "e86a7b42e9bd3c3d2f9321883c9d29b0e6b2774e4eb99056dd5093ca64b5b5c8", "target_language": "ruby"}
# sync_bulk.py — portiert nach ruby
# Quelle: python, OpenClaw@gateway1:skills/sync-utils/scripts/sync_bulk.py
# auch in: OpenClaw@gateway2:skills/sync-utils/scripts/sync_bulk.py
# auch in: workspace@local:git/skills/sync-utils/scripts/sync_bulk.py
# auch in: workspace@local:skills/sync-utils/scripts/sync_bulk.py
# Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

# frozen_string_literal: true

# Bulk Sync - Synchronisiert alle Skills

require 'pathname'
require 'optparse'

# Import sync functions
$LOAD_PATH << '/home/openclaw/.openclaw/workspace/scripts'
require 'sync_clawhub_git'

CLAWHUB_DIR = Pathname.new('/home/openclaw/.openclaw/workspace/skills')
GIT_DIR = Pathname.new('/home/openclaw/.openclaw/workspace/git/skills')

def sync_all_skills(dry_run: true)
  # Alle Skills finden
  all_skills = Set.new
  
  if CLAWHUB_DIR.exist?
    CLAWHUB_DIR.children.each do |d|
      all_skills.add(d.basename.to_s) if d.directory? && !d.basename.to_s.start_with?('.')
    end
  end
  
  if GIT_DIR.exist?
    GIT_DIR.children.each do |d|
      all_skills.add(d.basename.to_s) if d.directory? && !d.basename.to_s.start_with?('.')
    end
  end
  
  log("Bulk Sync: #{all_skills.size} Skills gefunden")
  
  results = {
    synced: [],
    skipped: [],
    failed: []
  }
  
  all_skills.sort.each do |skill|
    clawhub_path = CLAWHUB_DIR.join(skill)
    git_path = GIT_DIR.join(skill)
    
    begin
      # Nur in ClawHub → zu Git
      if clawhub_path.exist? && !git_path.exist?
        if validate_skill(clawhub_path)
          log("Syncing #{skill} to Git...")
          if sync_to_git(skill, dry_run)
            results[:synced] << "#{skill} → Git"
          else
            results[:failed] << skill
          end
        else
          results[:skipped] << "#{skill} (validation failed)"
        end
      
      # Nur in Git → zu ClawHub
      elsif git_path.exist? && !clawhub_path.exist?
        if validate_skill(git_path)
          log("Syncing #{skill} to ClawHub...")
          if sync_to_clawhub(skill, dry_run)
            results[:synced] << "#{skill} → ClawHub"
          else
            results[:failed] << skill
          end
        else
          results[:skipped] << "#{skill} (validation failed)"
        end
      
      # In beiden - prüfe ob Update nötig
      elsif clawhub_path.exist? && git_path.exist?
        # Vereinfachte Prüfung
        clawhub_files = clawhub_path.children.select(&:file?)
        clawhub_files += Dir[clawhub_path.join('**/*')].select { |f| File.file?(f) }
        git_files = git_path.children.select(&:file?)
        git_files += Dir[git_path.join('**/*')].select { |f| File.file?(f) && !f.include?('/.git/') }
        
        next if clawhub_files.empty? && git_files.empty?
        
        clawhub_mtime = clawhub_files.map { |f| File.stat(f).mtime }.max
        git_mtime = git_files.map { |f| File.stat(f).mtime }.max
        
        if (clawhub_mtime - git_mtime).abs > 60
          if clawhub_mtime > git_mtime
            log("Updating #{skill} in Git...")
            if sync_to_git(skill, dry_run)
              results[:synced] << "#{skill} → Git (update)"
            else
              results[:failed] << skill
            end
          else
            log("Updating #{skill} in ClawHub...")
            if sync_to_clawhub(skill, dry_run)
              results[:synced] << "#{skill} → ClawHub (update)"
            else
              results[:failed] << skill
            end
          end
        else
          results[:skipped] << "#{skill} (already synced)"
        end
      end
      
    rescue => e
      log("Error processing #{skill}: #{e}", 'ERROR')
      results[:failed] << skill
    end
  end
  
  # Zusammenfassung
  puts "\n" + '=' * 60
  puts "Bulk Sync #{dry_run ? 'DRY-RUN' : 'EXECUTED'} - Zusammenfassung"
  puts '=' * 60
  puts "✅ Synchronisiert: #{results[:synced].size}"
  results[:synced].each { |item| puts "   - #{item}" }
  puts "\n⏭️  Übersprungen: #{results[:skipped].size}"
  if results[:skipped].size <= 10
    results[:skipped].each { |item| puts "   - #{item}" }
  else
    puts "   - #{results[:skipped].size} Skills (bereits synchron oder Validierung fehlgeschlagen)"
  end
  puts "\n❌ Fehlgeschlagen: #{results[:failed].size}"
  results[:failed].each { |item| puts "   - #{item}" }
  puts '=' * 60
end

def main
  options = {}
  
  OptionParser.new do |opts|
    opts.banner = 'Usage: sync_bulk.rb [options]'
    opts.on('--dry-run', 'Nur Änderungen anzeigen') do
      options[:dry_run] = true
    end
    opts.on('--execute', 'Sync ausführen') do
      options[:execute] = true
    end
  end.parse!
  
  if !options[:dry_run] && !options[:execute]
    puts 'Bitte --dry-run oder --execute angeben'
    exit 1
  end
  
  sync_all_skills(dry_run: options[:dry_run])
end

main if __FILE__ == $0
