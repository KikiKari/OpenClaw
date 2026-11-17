#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "0d44de0ca89dac963994c06ecb3ef238db6f6e6ac88c9e79f0f9246b6b6fd08d", "source_sha256": "77eca70a7a8f9c0ff8dc240b14d8c37999854c241e031b8167e1fcd650cbd334", "target_language": "ruby"}
# install_cron.py — portiert nach ruby
# Quelle: python, OpenClaw@gateway1:skills/db-maintainer/scripts/install_cron.py
# auch in: OpenClaw@gateway2:skills/db-maintainer/scripts/install_cron.py
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

# frozen_string_literal: true

# Installiert den DB-Maintainer als Cron-Job

require 'json'
require 'fileutils'

CRON_JOB = <<~CRON
  # DB Maintainer - Alle 30 Minuten
  */30 * * * * cd /home/openclaw/.openclaw/workspace && python3 skills/db-maintainer/scripts/db_maintainer.py >> logs/db-maintainer/cron.log 2>&1
CRON

def install
  workspace = '/home/openclaw/.openclaw/workspace'
  cron_file = File.join(workspace, 'crons', 'db-maintainer.cron')
  
  FileUtils.mkdir_p(File.dirname(cron_file))
  
  File.write(cron_file, CRON_JOB)
  
  puts "✅ Cron-Job installiert: #{cron_file}"
  puts '   Füge zu crontab hinzu mit: crontab < crons/db-maintainer.cron'
  
  # Auch in OpenClaw cron registrieren
  jobs_json = File.join(workspace, '.openclaw', 'cron', 'jobs.json')
  if File.exist?(jobs_json)
    jobs = JSON.parse(File.read(jobs_json))
    
    jobs['db-maintainer'] = {
      'schedule' => '*/30 * * * *',
      'command' => 'python3 skills/db-maintainer/scripts/db_maintainer.py',
      'enabled' => true
    }
    
    File.write(jobs_json, JSON.pretty_generate(jobs))
    
    puts '✅ In OpenClaw cron registriert'
  end
end

install if __FILE__ == $0
