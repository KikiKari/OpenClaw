#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "6ea73aca712c6b94284bd2d6c9ef1077004f99a1c714dce268d213c78c17e4f5", "source_sha256": "c372bc97113533b0ca2400d318d3cd0e8cd55cea37f0cc563ab714990cc9efb6", "target_language": "perl6"}
# run_sync_agent.py — portiert nach perl6
# Quelle: python, OpenClaw@gateway2:scripts/run_sync_agent.py
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

# Sandbox-Wrapper für sync_agent.py: mappt hartcodierte Host-Pfade auf /workspace.

use v6;

# Füge Pfade zum Suchpfad hinzu
@*INC.unshift: '/workspace/scripts';
@*INC.unshift: '/workspace/skills/clawhub-git-sync-agent/scripts';

# Importiere das sync_agent Modul
require 'sync_agent.rakumod';  # oder .pm6 je nach Dateiendung

# Definiere die Workspace-Pfade
my $WS = '/workspace';
our $CLAWHUB_DIR is export = $WS ~ '/skills';
our $GIT_DIR is export = $WS ~ '/git/skills';
our $STATE_FILE is export = $WS ~ '/db/sync_state.json';

# Hauptprogramm ausführen
sub MAIN() {
    sync_agent::main();
}
