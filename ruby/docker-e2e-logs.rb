#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "ec4927805b3dc84757d1afb91a06e379011946e8b7e48ed120ab29dd0f3be1ce", "source_sha256": "c5da3d5a6d1b96d5dbfcceb3eeaaf1082185c08fa2edcbc7b87c36871484ccf2", "target_language": "ruby"}
# docker-e2e-logs.sh — portiert nach ruby
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/lib/docker-e2e-logs.sh
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

def run_logged(label, *command)
  require 'tempfile'
  log_file = Tempfile.new(["openclaw-#{label}", ".log"])
  log_file.close
  
  begin
    # Execute command and redirect stdout and stderr to log file
    output = `#{command.shelljoin} 2>&1`
    File.write(log_file.path, output)
    
    # Check if command failed
    unless $?.success?
      puts File.read(log_file.path)
      return false
    end
    
    true
  ensure
    log_file.unlink
  end
end

class Array
  def shelljoin
    map { |arg| arg.include?(' ') ? "'#{arg}'" : arg }.join(' ')
  end
end
