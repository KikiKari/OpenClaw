#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "ce95d07c4c2ec474168e9c021b3b1d5948506204645d8e3a1ac507b9094549bf", "source_sha256": "4c10c6b6fd911cb95da119f761f402073d1a836cab6b40a9f3b989536d5df5ec", "target_language": "ruby"}
# git_publish.py — portiert nach ruby
# Quelle: python, OpenClaw@gateway1:skills/git-publish-agent/scripts/git_publish.py
# auch in: OpenClaw@gateway2:skills/git-publish-agent/scripts/git_publish.py
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

# Git Publish Agent - Automatisierte Skill-Veröffentlichung

require 'optparse'
require 'pathname'
require 'date'
require 'open3'

SKILLS_DIR = Pathname.new(ENV['HOME']) / '.openclaw' / 'workspace' / 'skills'

def git_commit(skill_path, message = nil)
  # Commit skill changes.
  unless message
    message = "[skill] Auto-update #{skill_path.basename} - #{DateTime.now.iso8601}"
  end
  
  Open3.popen3('git', 'add', skill_path.to_s, chdir: SKILLS_DIR.parent.to_s) do |stdin, stdout, stderr, wait_thr|
    # Process runs, we just need the exit status later
  end
  
  stdout_str, stderr_str, status = Open3.capture3('git', 'commit', '-m', message, chdir: SKILLS_DIR.parent.to_s)
  status.success?
end

def clawhub_publish(skill_name)
  # Publish to ClawHub.
  skill_path = SKILLS_DIR / skill_name
  stdout_str, stderr_str, status = Open3.capture3(
    'clawhub', 'publish', skill_path.to_s,
    '--slug', skill_name,
    '--version', '1.0.0'
  )
  [status.success?, stdout_str]
end

def batch_publish
  # Publish all changed skills with rate limiting.
  # Check git status
  stdout_str, stderr_str, status = Open3.capture3(
    'git', 'status', '--short', SKILLS_DIR.to_s
  )
  
  changed = []
  stdout_str.split("\n").each do |line|
    line.strip!
    if !line.empty? && line.include?('skills/')
      skill = line.split('skills/').last.split('/')[0]
      changed << skill unless changed.include?(skill)
    end
  end
  
  puts "Changed skills: #{changed}"
  
  # Publish with delay
  changed.first(5).each_with_index do |skill, i| # Max 5 per batch
    if i > 0
      puts "Waiting 15min for rate limit..."
      # In real: sleep(900)
    end
    
    puts "Publishing #{skill}..."
    commit_ok = git_commit(SKILLS_DIR / skill)
    if commit_ok
      pub_ok, output = clawhub_publish(skill)
      puts "  #{pub_ok ? '✓' : '✗'} #{output}"
    end
  end
end

def main
  options = {}
  OptionParser.new do |opts|
    opts.banner = "Usage: git_publish.rb [options]"
    opts.on("--skill SKILL", "Single skill to publish") do |skill|
      options[:skill] = skill
    end
    opts.on("--all", "Publish all changed") do
      options[:all] = true
    end
    opts.on("--no-publish", "Commit only") do
      options[:no_publish] = true
    end
    opts.on("--message MESSAGE", "Custom commit message") do |msg|
      options[:message] = msg
    end
  end.parse!

  if options[:skill]
    skill_path = SKILLS_DIR / options[:skill]
    if options[:no_publish]
      git_commit(skill_path, options[:message])
    else
      git_commit(skill_path, options[:message])
      clawhub_publish(options[:skill])
    end
  elsif options[:all]
    batch_publish
  else
    puts "Use --skill <name> or --all"
  end
end

main if __FILE__ == $0
