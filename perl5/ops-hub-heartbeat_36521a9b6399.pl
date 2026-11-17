#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "752984c353a22647974bfd529140305ba7a5951ba837b6fe1f7870083a951d34", "source_sha256": "8621f6f7e524474de82b3d877ee62bbcbd9fa3b247b69c437b063b71fa995f5a", "target_language": "perl5"}
# ops-hub-heartbeat.js — portiert nach perl5
# Quelle: javascript, OpenClaw@gateway1:scripts/ops-hub-heartbeat.js
# auch in: OpenClaw@gateway2:scripts/ops-hub-heartbeat.js
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use utf8;
use File::Spec;
use File::Basename;
use POSIX qw(strftime);

# Aktualisiere den Statusbericht mit aktueller Zeit
my $script_dir = dirname(__FILE__);
my $status_path = File::Spec->catfile($script_dir, '..', 'docs', 'ops-hub', 'status.md');

sub update_heartbeat {
    my $content;
    open(my $fh, '<:encoding(UTF-8)', $status_path) or do {
        print STDERR "❌ Konnte status.md nicht lesen: $!\n";
        return;
    };
    {
        local $/;
        $content = <$fh>;
    }
    close($fh);

    # Setze die Zeitzone auf Europe/Berlin
    $ENV{TZ} = 'Europe/Berlin';
    my $now = strftime("%d.%m.%Y, %H:%M:%S", localtime);
    
    # Ersetze den Heartbeat-Zeitstempel
    $content =~ s/(Letzter Heartbeat:) [^\n]*/$1 $now/;

    open($fh, '>:encoding(UTF-8)', $status_path) or do {
        print STDERR "❌ Konnte status.md nicht schreiben: $!\n";
        return;
    };
    print $fh $content;
    close($fh);
    
    print "✅ Heartbeat aktualisiert: $now\n";
}

update_heartbeat();
