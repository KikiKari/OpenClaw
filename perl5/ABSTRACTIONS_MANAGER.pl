#!/usr/bin/perl
# ABSTRACTIONS_MANAGER.py — portiert nach perl5
# Quelle: python, OpenClaw@gateway2:skills/script-abstractions-manager/scripts/ABSTRACTIONS_MANAGER.py
# Erzeugt: 2026-08-08 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;

# Skill-Einstieg fuer den kanonischen Abstractions Manager.

use File::Spec;
use File::Basename;

my $KANONISCHER_MANAGER = '/home/openclaw/.openclaw/workspace/abstractions/ABSTRACTIONS_MANAGER.py';

if (__FILE__ eq $0) {
    if (!-f $KANONISCHER_MANAGER) {
        die "Kanonischer Abstractions Manager fehlt: $KANONISCHER_MANAGER\n";
    }
    
    # Fuehre das Python-Skript aus
    my $cmd = "python3 " . quotemeta($KANONISCHER_MANAGER);
    system($cmd);
    
    # Ueberpruefe den Exit-Status
    if ($? == -1) {
        die "Konnte Kommando nicht ausfuehren: $!\n";
    } elsif ($? & 127) {
        die sprintf("Kind-Programm wurde mit Signal %d beendet", $? & 127) . 
            ($? & 128 ? " (core dumped)" : "") . "\n";
    } else {
        my $exit_code = $? >> 8;
        exit $exit_code if $exit_code != 0;
    }
}
