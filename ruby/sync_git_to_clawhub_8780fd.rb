#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "b9999515abf4818627960f67b5cd248af3e665ffdec0ebf94eda580e6839ee6c", "source_sha256": "8780fd3b730020944ddee0cfabb1d6dde324ba0be8de46b91510150d0b3f4e96", "target_language": "ruby"}
# sync_git_to_clawhub.py — portiert nach ruby
# Quelle: python, OpenClaw@gateway2:scripts/sync_git_to_clawhub.py
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

# Sync die 4 Git-Repos zu ClawHub

require '/home/openclaw/.openclaw/workspace/scripts/sync_clawhub_git.rb'

# Die 4 Git-Repos die zu ClawHub müssen
git_repos = [
  "abstractions-utils",
  "sub-agents-utils", 
  "multi-nodes-utils",
  "Abstraktionen"
]

# Check if in git/
git_path = "/home/openclaw/.openclaw/workspace/git"
git_repos.each do |repo|
  if File.exist?("#{git_path}/#{repo}")
    log("Syncing #{repo} from Git to ClawHub...")
    # Rename für sync function
    if repo == "Abstraktionen"
      next  # Skip - ist kein Skill
    end
    sync_to_clawhub(repo, false)
    log("✅ #{repo} synced to ClawHub")
  end
end
