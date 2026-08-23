#!/usr/bin/perl
# sync_git_to_clawhub.py — portiert nach perl5
# Quelle: python, OpenClaw@gateway2:scripts/sync_git_to_clawhub.py
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use lib '/home/openclaw/.openclaw/workspace/scripts';
require 'sync_clawhub_git.pl';

# Die 4 Git-Repos die zu ClawHub müssen
my @git_repos = (
    "abstractions-utils",
    "sub-agents-utils", 
    "multi-nodes-utils",
    "Abstraktionen"
);

# Check if in git/
my $git_path = "/home/openclaw/.openclaw/workspace/git";
foreach my $repo (@git_repos) {
    if (-d "$git_path/$repo") {
        sync_clawhub_git::log("Syncing $repo from Git to ClawHub...");
        # Rename für sync function
        if ($repo eq "Abstraktionen") {
            next;  # Skip - ist kein Skill
        }
        sync_clawhub_git::sync_to_clawhub($repo, 0);  # dry_run=False
        sync_clawhub_git::log("✅ $repo synced to ClawHub");
    }
}
