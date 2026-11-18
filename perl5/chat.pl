#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "c02afeeb1911a415d1b12cfacf0ae593def57894eb4ef2e12a3b2b21e9649304", "source_sha256": "f1fb75db28e47070c42c0b401c9bdae5ac468bcd98550232038e409983691fad", "target_language": "perl5"}
# chat.css — portiert nach perl5
# Quelle: css, workspace@local:skills/github-clones/openclaw/ui/src/styles/chat.css
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;

# Prüfe ob ein Dateiname übergeben wurde
if (@ARGV != 1) {
    die "Usage: $0 <output_filename>\n";
}

my $output_file = $ARGV[0];

# Array mit den zu importierenden CSS-Dateien
my @imports = (
    './chat/layout.css',
    './chat/text.css',
    './chat/grouped.css',
    './chat/tool-cards.css',
    './chat/sidebar.css'
);

# Öffne die Ausgabedatei zum Schreiben
open(my $fh, '>', $output_file) or die "Kann Datei '$output_file' nicht öffnen: $!";

# Schreibe die @import-Anweisungen in die Datei
foreach my $import (@imports) {
    print $fh '@import "' . $import . "\";\n";
}

# Schließe die Datei
close($fh);

print "CSS-Datei wurde erfolgreich erstellt: $output_file\n";
