#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "658d588b53b4c1e278fe851d6fa7ae8278f4cd3b635b3e0f3ab44038f6156090", "source_sha256": "3ee904e4ee842489bd9bef8522f5a93fc06583e6cb1c3c5243afae19a4e2ed5f", "target_language": "ruby"}
# db_maintainer.py — portiert nach ruby
# Quelle: python, OpenClaw@gateway1:skills/db-maintainer/scripts/db_maintainer.py
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

# Database Maintainer Sub-Agent
# Automated database maintenance with 30min checks, hourly backups (3 days retention),
# band tree command execution for important/openclaw-tree.txt

require 'sqlite3'
require 'digest'
require 'json'
require 'fileutils'
require 'pathname'
require 'time'

WORKSPACE = Pathname.new('/home/openclaw/.openclaw/workspace')
DB_DIR = WORKSPACE + 'db'
BACKUP_DIR = DB_DIR + 'backups'
LOG_DIR = WORKSPACE + 'logs' + 'db-maintainer'
IMPORTANT_DIR = WORKSPACE + 'important'

# Verzeichnisse erstellen
[BACKUP_DIR, LOG_DIR].each { |dir| FileUtils.mkdir_p(dir) }

class Logger
  # Einfacher Logger mit Datei-Ausgabe
  
  def initialize
    @today = Time.now.strftime('%Y-%m-%d')
    @log_file = LOG_DIR + "#{@today}.log"
  end
  
  def log(level, message)
    timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
    line = "[#{timestamp}] [#{level}] #{message}"
    puts line
    File.open(@log_file, 'a') { |f| f.puts line }
  end
  
  def info(msg); log('INFO', msg); end
  def warn(msg); log('WARN', msg); end
  def error(msg); log('ERROR', msg); end
end

class DatabaseMaintainer
  def initialize
    @logger = Logger.new
    @state_file = DB_DIR + 'maintainer_state.json'
    @retention_days = 3  # 3 Tage Backup-Aufbewahrung
  end
  
  def load_state
    # Lädt letzten Check-Zustand
    if @state_file.exist?
      JSON.parse(File.read(@state_file))
    else
      { 'last_check' => nil, 'last_backup' => nil, 'last_tree_update' => nil, 'file_hashes' => {} }
    end
  end
  
  def save_state(state)
    # Speichert aktuellen Zustand
    File.open(@state_file, 'w') { |f| f.write(JSON.pretty_generate(state)) }
  end
  
  def get_file_hash(filepath)
    # Berechnet MD5-Hash einer Datei
    Digest::MD5.file(filepath).to_s
  rescue
    nil
  end
  
  def run_tree_command
    # Führt tree -a -L 8 auf workspace aus und gibt Ergebnis zurück
    output, status = Open3.capture2e('tree', '-a', '-L', '8', WORKSPACE.to_s)
    if status.success?
      @logger.info('tree -a -L 8 erfolgreich ausgeführt')
      output
    else
      @logger.error("tree command fehlgeschlagen: #{output}")
      nil
    end
  rescue => e
    @logger.error("tree command Exception: #{e}")
    nil
  end
  
  def update_tree_file(tree_output)
    # Schreibt tree-output in important/openclaw-tree.txt
    return false unless tree_output
    
    tree_file = IMPORTANT_DIR + 'openclaw-tree.txt'
    
    # Header mit Timestamp
    header = <<~HEADER
      # OpenClaw Workspace Tree
      # Generiert: #{Time.now.iso8601}
      # Befehl: tree -a -L 8 #{WORKSPACE}
      # Diese Datei wird automatisch von db-maintainer aktualisiert
      
    HEADER
    
    begin
      File.open(tree_file, 'w') { |f| f.write(header + tree_output) }
      @logger.info("openclaw-tree.txt aktualisiert: #{tree_file}")
      true
    rescue => e
      @logger.error("Fehler beim Schreiben von openclaw-tree.txt: #{e}")
      false
    end
  end
  
  def scan_documentations
    # Scannt alle .md Dateien auf Änderungen
    docs = []
    
    Dir.glob(WORKSPACE + '**/*.md').each do |file_path|
      file = Pathname.new(file_path)
      next unless file.file? && !file.symlink?
      next if file.to_s.include?('db/backups') || file.to_s.include?('node_modules')
      
      docs << {
        'path' => file.relative_path_from(WORKSPACE).to_s,
        'hash' => get_file_hash(file),
        'mtime' => file.mtime.to_f
      }
    end
    
    docs
  end
  
  def check_for_changes
    # Prüft auf Änderungen seit letztem Lauf
    state = load_state
    current_docs = scan_documentations
    
    changes = []
    current_hashes = {}
    
    current_docs.each do |doc|
      path = doc['path']
      current_hashes[path] = doc['hash']
      
      if !state['file_hashes'].key?(path)
        changes << "NEW: #{path}"
      elsif state['file_hashes'][path] != doc['hash']
        changes << "CHANGED: #{path}"
      end
    end
    
    # Prüfe auf gelöschte Dateien
    (state['file_hashes'].keys - current_hashes.keys).each do |old_path|
      changes << "DELETED: #{old_path}"
    end
    
    [changes, current_hashes]
  end
  
  def update_databases
    # Führt DB-Update-Scripts aus
    output, status = Open3.capture2e('python3', (WORKSPACE + 'scripts' + 'update_docs_db.py').to_s)
    
    if status.success?
      @logger.info('docs.db aktualisiert')
      true
    else
      @logger.error("DB-Update fehlgeschlagen: #{output}")
      false
    end
  rescue => e
    @logger.error("DB-Update Exception: #{e}")
    false
  end
  
  def update_tree_db_v2
    # Führt tree_indexer_v2.py aus
    output, status = Open3.capture2e('python3', (WORKSPACE + 'scripts' + 'tree_indexer_v2.py').to_s)
    
    if status.success?
      @logger.info('tree.db v2 aktualisiert')
      true
    else
      @logger.error("Tree-DB v2 fehlgeschlagen: #{output}")
      false
    end
  rescue => e
    @logger.error("Tree-DB v2 Exception: #{e}")
    false
  end
  
  def create_backup
    # Erstellt Backup beider Datenbanken
    timestamp = Time.now.strftime('%Y-%m-%d_%H-%M')
    
    ['docs.db', 'tree.db'].each do |db_name|
      source = DB_DIR + db_name
      if source.exist?
        backup_name = "#{timestamp}_#{db_name}.bak"
        backup_path = BACKUP_DIR + backup_name
        FileUtils.cp(source, backup_path)
        @logger.info("Backup erstellt: #{backup_name}")
      end
    end
    
    timestamp
  end
  
  def cleanup_old_backups
    # Löscht Backups älter als 3 Tage
    cutoff = Time.now - (@retention_days * 24 * 60 * 60)
    deleted = 0
    
    ['docs.db', 'tree.db'].each do |db_name|
      Dir.glob(BACKUP_DIR + "*_#{db_name}.bak").each do |backup_path|
        backup = Pathname.new(backup_path)
        # Extrahiere Datum aus filename (Format: YYYY-MM-DD_HH-MM)
        begin
          parts = backup.basename.to_s.split('_')
          date_str = parts[0]
          time_str = parts[1]
          backup_time = Time.parse("#{date_str}_#{time_str}")
          
          if backup_time < cutoff
            backup.delete
            deleted += 1
            @logger.info("Altes Backup gelöscht: #{backup.basename}")
          end
        rescue => e
          @logger.warn("Konnte Backup-Datum nicht parsen: #{backup.basename} - #{e.message}")
        end
      end
    end
    
    if deleted == 0
      @logger.info('Keine alten Backups zum Löschen')
    else
      @logger.info("#{deleted} alte Backups gelöscht (< 3 Tage)")
    end
  end
  
  def run_cycle
    # Ein kompletter Wartungszyklus
    separator = '=' * 60
    @logger.info(separator)
    @logger.info('DB MAINTAINER CYCLE START')
    @logger.info(separator)
    
    state = load_state
    
    # 1. Tree-Befehl ausführen und in openclaw-tree.txt schreiben
    @logger.info('Führe tree -a -L 8 aus...')
    tree_output = run_tree_command
    if tree_output
      update_tree_file(tree_output)
      state['last_tree_update'] = Time.now.iso8601
    end
    
    # 2. tree.db aktualisieren (intern v2)
    @logger.info('Aktualisiere tree.db v2...')
    update_tree_db_v2
    
    # 3. Änderungen prüfen
    @logger.info('Prüfe auf Dokumentations-Änderungen...')
    changes, current_hashes = check_for_changes
    
    if changes.any?
      @logger.info("#{changes.length} Änderungen gefunden:")
      changes.first(10).each { |change| @logger.info("  - #{change}") }
      if changes.length > 10
        @logger.info("  ... und #{changes.length - 10} weitere")
      end
      
      # 4. docs.db aktualisieren
      @logger.info('Aktualisiere docs.db...')
      if update_databases
        state['last_check'] = Time.now.iso8601
        state['file_hashes'] = current_hashes
      end
    else
      @logger.info('Keine Dokumentations-Änderungen gefunden')
    end
    
    # 5. Prüfe ob Backup fällig (stündlich)
    last_backup = state['last_backup']
    
    if last_backup
      last_backup_time = Time.parse(last_backup)
      do_backup = Time.now - last_backup_time >= 3600 # 1 hour in seconds
    else
      do_backup = true
    end
    
    if do_backup
      @logger.info('Erstelle stündliches Backup...')
      timestamp = create_backup
      state['last_backup'] = Time.now.iso8601
      
      # 6. Alte Backups aufräumen (3 Tage Retention)
      @logger.info('Räume alte Backups auf (3 Tage Retention)...')
      cleanup_old_backups
    else
      @logger.info('Backup nicht nötig (letztes < 1h)')
    end
    
    save_state(state)
    
    @logger.info(separator)
    @logger.info('DB MAINTAINER CYCLE END')
    @logger.info(separator)
  end
end

def main
  # Hauptfunktion
  maintainer = DatabaseMaintainer.new
  
  begin
    maintainer.run_cycle
  rescue => e
    maintainer.logger.error("CRITICAL ERROR: #{e}")
    exit(1)
  end
end

# Add required libraries at the top
require 'open3'

if __FILE__ == $0
  main
end
