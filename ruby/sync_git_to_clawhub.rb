#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "9926d8110fc6fed59f384306968b6d71bd398d716754ccfb9e6370369d9f3afa", "source_sha256": "6e59b459db4fb36ac761c1c0efd5b719de1cb0a62c0e628aa8274f5ef6a1056c", "target_language": "ruby"}
# sync_git_to_clawhub.py — portiert nach ruby
# Quelle: python, OpenClaw@gateway1:scripts/sync_git_to_clawhub.py
# auch in: workspace@local:scripts/sync_git_to_clawhub.py
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

# Sync die aktiven Skill-Repositories zu ClawHub.

require_relative '/home/openclaw/.openclaw/workspace/scripts/sync_clawhub_git'

# Nur aktive Skill-Repositories synchronisieren.
git_repos = [
  "sub-agents-utils",
  "multi-nodes-utils",
]

# Check if in git/
git_path = "/home/openclaw/.openclaw/workspace/git"
git_repos.each do |repo|
  if File.exist?("#{git_path}/#{repo}")
    log("Syncing #{repo} from Git to ClawHub...")
    sync_to_clawhub(repo, false)
    log("✅ #{repo} synced to ClawHub")
  end
end
