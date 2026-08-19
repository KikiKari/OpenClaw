#!/usr/bin/perl
# ops-hub-heartbeat.js — portiert nach perl5
# Quelle: javascript, OpenClaw@gateway1:scripts/ops-hub-heartbeat.js
# auch in: OpenClaw@gateway2:scripts/ops-hub-heartbeat.js
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use utf8;
use File::Spec;
use File::Basename;

# Aktualisiere den Statusbericht mit aktueller Zeit
my $script_dir = dirname(__FILE__);
my $statusPath = File::Spec->catfile($script_dir, '..', 'docs', 'ops-hub', 'status.md');

sub updateHeartbeat {
    my $content;
    open(my $fh, '<:encoding(UTF-8)', $statusPath) or do {
        warn "❌ Konnte status.md nicht lesen: $!\n";
        return;
    };
    {
        local $/;
        $content = <$fh>;
    }
    close($fh);

    # Formatierung wie bei de-DE und Europe/Berlin
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
    $year += 1900;
    $mon += 1;
    my $now = sprintf("%02d.%02d.%04d, %02d:%02d:%02d", $mday, $mon, $year, $hour, $min, $sec);

    $content =~ s/(Letzter Heartbeat:) [^\n]*/$1 $now/;

    open($fh, '>:encoding(UTF-8)', $statusPath) or do {
        warn "❌ Konnte status.md nicht schreiben: $!\n";
        return;
    };
    print $fh $content;
    close($fh);

    print "✅ Heartbeat aktualisiert: $now\n";
}

updateHeartbeat();
