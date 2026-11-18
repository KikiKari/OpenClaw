#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "a4a4cd25d515b55de17b3bde7520fea0d68733f43f2687f5fe365500f874f49c", "source_sha256": "1b01ca0f5943b16d3905faf557953600ee54f15ecf1dc18c1461585eba94d376", "target_language": "ruby"}
# abstractions-manager-cron.sh — portiert nach ruby
# Quelle: shell, OpenClaw@gateway1:scripts/abstractions-manager-cron.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

ENV['PATH'] = '/home/openclaw/.local/bin:/usr/local/bin:/usr/bin:/bin'

# Lade Umgebungsvariablen aus .env Datei
env_file = '/home/openclaw/.openclaw/.env'
if File.exist?(env_file)
  File.readlines(env_file).each do |line|
    line.strip!
    next if line.empty? || line.start_with?('#')
    
    if line.include?('=')
      key, value = line.split('=', 2)
      ENV[key] = value
    end
  end
end

# Prüfe ob OPENROUTER_API_KEY gesetzt ist
raise 'OPENROUTER_API_KEY fehlt' unless ENV['OPENROUTER_API_KEY']

# Setze GITHUB_TOKEN aus verfügbaren Tokens
ENV['GITHUB_TOKEN'] ||= ENV['GH_TOKEN'] || ENV['GH_ACCESS_TOKEN'] || ''

# Pfade definieren
lock_file = '/home/openclaw/.openclaw/locks/abstractions-manager.lock'
python_script = '/home/openclaw/.openclaw/workspace/skills/script-abstractions-manager/scripts/ABSTRACTIONS_MANAGER.py'

# Versuche Lock-Datei zu erstellen und Script auszuführen
begin
  File.open(lock_file, File::CREAT | File::EXCL) do |lock|
    # Führe Python-Script mit allen Argumenten aus
    exec('python3', python_script, *ARGV)
  end
rescue Errno::EEXIST
  # Lock-Datei existiert bereits - beende mit Fehler
  STDERR.puts "Lock file exists - exiting"
  exit 1
end
