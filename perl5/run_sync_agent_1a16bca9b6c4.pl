#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "980ef0029d4a90a46da5577a65a2cc3f4868a721edd1d82c9cd5e41cb27421a9", "source_sha256": "c372bc97113533b0ca2400d318d3cd0e8cd55cea37f0cc563ab714990cc9efb6", "target_language": "perl5"}
# run_sync_agent.py — portiert nach perl5
# Quelle: python, OpenClaw@gateway2:scripts/run_sync_agent.py
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use lib '/workspace/scripts';
use lib '/workspace/skills/clawhub-git-sync-agent/scripts';

# Sandbox-Wrapper fuer sync_agent.py: mappt hartcodierte Host-Pfade auf /workspace.

require sync_agent;

$sync_agent::CLAWHUB_DIR = '/workspace/skills';
$sync_agent::GIT_DIR = '/workspace/git/skills';
$sync_agent::STATE_FILE = '/workspace/db/sync_state.json';

sync_agent::main() if __FILE__ eq $0;
