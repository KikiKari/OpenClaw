#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "dd2c99a657f9534eea30bc9080b8130b371c56765ffa88cb725c232943f06a17", "source_sha256": "94ca1324b379194574325edaa6a3862182f09ae2d497d1200288dad11f17bde2", "target_language": "ruby"}
# sync-local.sh — portiert nach ruby
# Quelle: shell, Onboarding@main:scripts/sync-local.sh
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

# Ruby-Äquivalent zu sync-local.ps1 — inkrementeller Git-Sync für den Dev-Stack.
# Nutzung: scripts/sync-local.rb [--branch <name>] [--interval <s>] [--once]

require 'optparse'
require 'open3'
require 'pathname'
require 'time'

class SyncLocal
  def initialize
    @branch = "claude/onboarding-persistent-sandbox-vjfmcx"
    @interval = 20
    @compose_file = "docker-compose.dev.yml"
    @once = false
    
    parse_options
    @start_dir = Pathname.new(__FILE__).dirname.parent
  end
  
  def parse_options
    OptionParser.new do |opts|
      opts.banner = "Usage: #{$0} [options]"
      
      opts.on("--branch NAME", "Git branch name") do |name|
        @branch = name
      end
      
      opts.on("--interval SECONDS", Integer, "Sync interval in seconds") do |seconds|
        @interval = seconds
      end
      
      opts.on("--once", "Run only once") do
        @once = true
      end
    end.parse!
  end
  
  def log(message)
    puts "[#{Time.now.strftime('%H:%M:%S')}] #{message}"
  end
  
  def compose(*args)
    cmd = ["docker", "compose", "-f", @compose_file, *args]
    result = system(*cmd)
    log("WARNUNG: docker compose #{args.join(' ')} fehlgeschlagen") unless result
    result
  end
  
  def run_command(cmd)
    stdin, stdout, stderr, wait_thr = Open3.popen3(cmd)
    stdin.close
    output = stdout.read
    error = stderr.read
    stdout.close
    stderr.close
    [output.strip, error.strip, wait_thr.value.success?]
  end
  
  def git_current_branch
    output, _, success = run_command("git rev-parse --abbrev-ref HEAD")
    success ? output : nil
  end
  
  def git_fetch(branch)
    system("git fetch origin #{branch} --quiet", out: File::NULL, err: File::NULL)
  end
  
  def git_switch(branch)
    success = system("git switch #{branch}", out: File::NULL, err: File::NULL)
    unless success
      system("git switch -c #{branch} --track origin/#{branch}", out: File::NULL, err: File::NULL)
    end
  end
  
  def git_rev_parse(ref)
    output, _, success = run_command("git rev-parse #{ref}")
    success ? output : nil
  end
  
  def git_diff_names(local_rev, remote_rev)
    output, _, success = run_command("git diff --name-only #{local_rev}..#{remote_rev}")
    success ? output.split("\n") : []
  end
  
  def git_merge_base_ancestor?(local_rev, remote_rev)
    system("git merge-base --is-ancestor #{local_rev} #{remote_rev}", out: File::NULL, err: File::NULL)
  end
  
  def git_merge_ff_only(remote_rev)
    system("git merge --ff-only #{remote_rev} --quiet", out: File::NULL, err: File::NULL)
  end
  
  def check_and_update
    unless git_fetch(@branch)
      log("Fetch fehlgeschlagen (Netzwerk?) — nächster Versuch in #{@interval}s")
      return
    end
    
    local_rev = git_rev_parse("HEAD")
    remote_rev = git_rev_parse("origin/#{@branch}")
    
    if local_rev != remote_rev
      unless git_merge_base_ancestor?(local_rev, remote_rev)
        log("ACHTUNG: Lokaler Stand von origin/#{@branch} abgewichen — kein automatischer Merge, bitte manuell auflösen.")
        return
      end
      
      changed_files = git_diff_names(local_rev, remote_rev)
      git_merge_ff_only(remote_rev)
      
      short_local = local_rev[0..6]
      short_remote = remote_rev[0..6]
      log("Aktualisiert #{short_local} -> #{short_remote} (#{changed_files.length} Datei(en))")
      
      needs_none = true
      
      if changed_files.include?(@compose_file)
        log("Compose-Datei geändert — erzeuge Dev-Stack neu …")
        compose("up", "-d")
        needs_none = false
      end
      
      backend_changed = changed_files.any? { |f| f.match(%r{^backend/(Dockerfile|requirements.*\.txt)$}) }
      if backend_changed
        log("Backend-Dependencies/Dockerfile geändert — baue nur das Backend neu …")
        compose("up", "-d", "--build", "backend")
        needs_none = false
      end
      
      frontend_changed = changed_files.any? { |f| f.match(/^(package\.json|package-lock\.json)$/) }
      if frontend_changed
        log("Frontend-Dependencies geändert — starte Frontend neu (npm install läuft im Container) …")
        compose("restart", "frontend")
        needs_none = false
      end
      
      log("Nur Quellcode/Assets — Hot-Reload übernimmt, kein Build nötig.") if needs_none
    end
  end
  
  def run
    Dir.chdir(@start_dir) do
      current = git_current_branch
      if current != @branch
        log("Wechsle von '#{current}' auf '#{@branch}' …")
        git_fetch(@branch)
        git_switch(@branch)
      end
      
      log("Sync aktiv: origin/#{@branch} -> #{Dir.pwd} (Intervall #{@interval}s, Compose: #{@compose_file})")
      
      loop do
        check_and_update
        break if @once
        sleep(@interval)
      end
    end
  end
end

SyncLocal.new.run
