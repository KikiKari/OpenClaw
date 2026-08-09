#!/usr/bin/env perl
# ABSTRACTIONS_MANAGER.py — portiert nach perl5
# Quelle: python, OpenClaw@gateway2:skills/script-abstractions-manager/scripts/ABSTRACTIONS_MANAGER.py
# Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use Path::Tiny;

# Skill-Einstieg fuer den kanonischen Abstractions Manager.

my $KANONISCHER_MANAGER = path("/home/openclaw/.openclaw/workspace/abstractions/ABSTRACTIONS_MANAGER.py");

if (__FILE__ eq $0) {
    if (!$KANONISCHER_MANAGER->is_file) {
        die "Kanonischer Abstractions Manager fehlt: $KANONISCHER_MANAGER\n";
    }
    do $KANONISCHER_MANAGER->stringify or die "Fehler beim Ausfuehren des Skripts: $@";
}
