#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "79f60413437df76815522496b6a152f6f051db5a83c22bc2c8a12cff5b824708", "source_sha256": "b97ad7dc26be724af240b4c0c98ec196e729e0702664b99c65e0e3c435a1b5af", "target_language": "ruby"}
# sync-local.ps1 — portiert nach ruby
# Quelle: powershell, Onboarding@main:scripts/sync-local.ps1
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

# SYNOPSIS
#   Hält den lokalen Dev-Stack (docker-compose.dev.yml) inkrementell mit GitHub synchron.
#
# DESCRIPTION
#   Pollt origin/<Branch> und zieht neue Commits per Fast-Forward. Danach entscheidet
#   der Diff, was nötig ist:
#     - nur Quellcode geändert            -> nichts tun, Hot-Reload übernimmt
#     - package.json / package-lock.json  -> Frontend-Container neu starten
#                                            (Entrypoint installiert Dependencies nur
#                                            bei geändertem Lockfile-Hash nach)
#     - backend/Dockerfile, requirements* -> Backend-Image gezielt neu bauen
#     - docker-compose.dev.yml            -> Dev-Stack neu erzeugen
#   Es wird nie „blind" der ganze Branch neu gebaut.
#
# EXAMPLE
#   ruby scripts/sync-local.rb                # Dauerbetrieb, 20-s-Intervall
#   ruby scripts/sync-local.rb --once         # genau ein Sync-Durchlauf
#   ruby scripts/sync-local.rb --branch main # anderen Branch verfolgen

require 'optparse'
require 'open3'
require 'pathname'

options = {
  branch: 'claude/onboarding-persistent-sandbox-vjfmcx',
  interval_seconds: 20,
  compose_file: 'docker-compose.dev.yml',
  once: false
}

OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} [options]"

  opts.on('--branch BRANCH', String, 'Branch to track') do |b|
    options[:branch] = b
  end

  opts.on('--interval SECONDS', Integer, 'Polling interval in seconds') do |i|
    options[:interval_seconds] = i
  end

  opts.on('--compose-file FILE', String, 'Docker compose file to use') do |f|
    options[:compose_file] = f
  end

  opts.on('--once', 'Run only once') do
    options[:once] = true
  end
end.parse!

def log(msg)
  puts "[#{Time.now.strftime('%H:%M:%S')}] #{msg}"
end

def invoke_compose(compose_args, compose_file)
  cmd = ['docker', 'compose', '-f', compose_file] + compose_args
  stdout, stderr, status = Open3.capture3(*cmd)
  unless status.success?
    log "WARNUNG: docker compose #{compose_args.join(' ')} fehlgeschlagen (Exit #{status.exitstatus})"
  end
end

repo_root = Pathname.new(__FILE__).dirname.parent.to_s
Dir.chdir(repo_root)

# Sicherstellen, dass der Ziel-Branch ausgecheckt ist.
current = `git rev-parse --abbrev-ref HEAD`.strip
if current != options[:branch]
  log "Wechsle von '#{current}' auf '#{options[:branch]}' …"
  system("git fetch origin #{options[:branch]}")
  
  result = system("git switch #{options[:branch]} 2>/dev/null")
  unless result
    system("git switch -c #{options[:branch]} --track origin/#{options[:branch]}")
  end
  
  unless $?.success?
    raise "Branch '#{options[:branch]}' konnte nicht ausgecheckt werden."
  end
end

log "Sync aktiv: origin/#{options[:branch]} -> #{repo_root} (Intervall #{options[:interval_seconds]}s, Compose: #{options[:compose_file]})"

loop do
  result = system("git fetch origin #{options[:branch]} --quiet")
  unless result
    log "Fetch fehlgeschlagen (Netzwerk?) — nächster Versuch in #{options[:interval_seconds]}s"
  else
    local = `git rev-parse HEAD`.strip
    remote = `git rev-parse origin/#{options[:branch]}`.strip

    if local != remote
      result = system("git merge-base --is-ancestor #{local} #{remote}")
      unless result
        log "ACHTUNG: Lokaler Stand ist von origin/#{options[:branch]} abgewichen (lokale Commits?). Kein automatischer Merge — bitte manuell auflösen."
      else
        changed_output, _ = Open3.capture2('git', 'diff', '--name-only', "#{local}..#{remote}")
        changed = changed_output.strip.split("\n").reject(&:empty?)

        system("git merge --ff-only #{remote} --quiet")
        log "Aktualisiert #{local[0,7]} -> #{remote[0,7]} (#{changed.length} Datei(en))"

        frontend_deps = changed.select { |file| ['package.json', 'package-lock.json'].include?(file) }
        backend_image = changed.select { |file| /^backend\/(Dockerfile|requirements.*\.txt)$/.match(file) }
        compose_changed = changed.include?(options[:compose_file])

        if compose_changed
          log "Compose-Datei geändert — erzeuge Dev-Stack neu …"
          invoke_compose(['up', '-d'], options[:compose_file])
        end
        
        if backend_image.any?
          log "Backend-Dependencies/Dockerfile geändert — baue nur das Backend neu …"
          invoke_compose(['up', '-d', '--build', 'backend'], options[:compose_file])
        end
        
        if frontend_deps.any?
          log "Frontend-Dependencies geändert — starte Frontend neu (npm install läuft im Container) …"
          invoke_compose(['restart', 'frontend'], options[:compose_file])
        end
        
        if !(compose_changed || backend_image.any? || frontend_deps.any?)
          log "Nur Quellcode/Assets — Hot-Reload übernimmt, kein Build nötig."
        end
      end
    end
  end

  break if options[:once]
  sleep(options[:interval_seconds])
end
