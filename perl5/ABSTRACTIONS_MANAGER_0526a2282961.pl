#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "b7e04fdd13389956d8d734a1d0b1e9a9791f55aaa0fe58a807c86d91b35fbe18", "source_sha256": "1a472288a0369d1ab50d7682ef1fd8fb0f3252b751dcc14dceeea89b1522ec52", "target_language": "perl5"}
# ABSTRACTIONS_MANAGER.py — portiert nach perl5
# Quelle: python, OpenClaw@gateway2:skills/script-abstractions-manager/scripts/ABSTRACTIONS_MANAGER.py
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Spec;
use Cwd 'abs_path';

# Skill-Einstieg fuer den kanonischen Abstractions Manager.

my $KANONISCHER_MANAGER = '/home/openclaw/.openclaw/workspace/abstractions/ABSTRACTIONS_MANAGER.py';

sub main {
    # Pruefe ob die Datei existiert
    unless (-f $KANONISCHER_MANAGER) {
        die "Kanonischer Abstractions Manager fehlt: $KANONISCHER_MANAGER\n";
    }
    
    # Fuehre das Python-Skript aus
    my $exit_code = system("python3", $KANONISCHER_MANAGER);
    if ($exit_code != 0) {
        die "Fehler beim Ausfuehren des kanonischen Abstractions Managers\n";
    }
}

# Wenn das Skript direkt ausgefuehrt wird
if (abs_path($0) eq abs_path(__FILE__)) {
    main();
}
