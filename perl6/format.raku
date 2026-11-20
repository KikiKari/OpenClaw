#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "70759dc907087f37f51126a553f676f2f04468180c670ed2155277e7129ae9ae", "source_sha256": "ed82b1410f121f3b1436d54099143d7010035ba702c64f21d2669fce9dd3f2ae", "target_language": "perl6"}
# format.sh — portiert nach perl6
# Quelle: shell, workspace@local:skills/github-clones/openclaw/Swabble/scripts/format.sh
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

use v6;

my $root = $*CWD;
my $config = $root ~ '/.swiftformat';
my $sources = $root ~ '/Sources';

# Prüfe ob swiftformat verfügbar ist
try {
    run('swiftformat', '--version');
    CATCH {
        note "swiftformat nicht gefunden. Bitte installieren.";
        exit 1;
    }
}

# Führe swiftformat aus
my $proc = run('swiftformat', '--config', $config, $sources, :out, :err);

if $proc.exitcode != 0 {
    note "swiftformat fehlgeschlagen:";
    note $proc.err.slurp-rest;
    exit $proc.exitcode;
}
