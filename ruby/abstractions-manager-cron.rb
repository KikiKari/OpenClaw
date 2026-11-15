#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "c41900172d4dbdbc50d92fd074d96b9981440a669b5a696eaaff1a41c30f9573", "source_sha256": "1b01ca0f5943b16d3905faf557953600ee54f15ecf1dc18c1461585eba94d376", "target_language": "ruby"}
# abstractions-manager-cron.sh — portiert nach ruby
# Quelle: shell, OpenClaw@gateway1:scripts/abstractions-manager-cron.sh
# Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

ENV['PATH'] = "/home/openclaw/.local/bin:/usr/local/bin:/usr/bin:/bin"

# Lade Umgebungsvariablen aus .env Datei
File.readlines('/home/openclaw/.openclaw/.env').each do |line|
  line.strip!
  # Überspringe Kommentare und leere Zeilen
  next if line.empty? || line.start_with?('#')
  
  # Teile die Zeile am ersten '=' auf
  if line.include?('=')
    key, value = line.split('=', 2)
    # Entferne potenzielle Anführungszeichen am Anfang und Ende des Werts
    value = value.gsub(/\A(['"])(.*)\1\z/, '\2') if value
    ENV[key] = value
  end
end

# Prüfe ob OPENROUTER_API_KEY gesetzt ist
raise "OPENROUTER_API_KEY fehlt" unless ENV['OPENROUTER_API_KEY']

# Setze GITHUB_TOKEN aus alternativen Umgebungsvariablen
ENV['GITHUB_TOKEN'] ||= ENV['GH_TOKEN'] || ENV['GH_ACCESS_TOKEN'] || ''

# Erstelle Lock-Datei Pfad
lock_file = '/home/openclaw/.openclaw/locks/abstractions-manager.lock'

# Versuche Lock zu erhalten (non-blocking)
begin
  File.open(lock_file, File::RDWR|File::CREAT, 0644) do |f|
    # Versuche exklusiven Lock zu erhalten
    if f.flock(File::LOCK_EX | File::LOCK_NB)
      # Führe Python-Skript aus
      exec('/usr/bin/python3', 
           '/home/openclaw/.openclaw/workspace/skills/script-abstractions-manager/scripts/ABSTRACTIONS_MANAGER.py', 
           *ARGV)
    else
      # Lock konnte nicht erhalten werden - exit mit Fehlercode
      exit(1)
    end
  end
rescue => e
  STDERR.puts "Fehler beim Ausführen des Skripts: #{e.message}"
  exit(1)
end
