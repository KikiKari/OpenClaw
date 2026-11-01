#!/usr/bin/perl
# status-overview.html — portiert nach perl5
# Quelle: html, Projects@TikTok-Live-Companion:plugin-source/browser-extension/status-overview.html
# Erzeugt: 2026-11-01 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;

# Parameter prüfen
my $output_file = $ARGV[0] or die "Usage: $0 <output-file>\n";

# HTML-Struktur erstellen
my $html = create_html_document();

# In Datei schreiben
open my $fh, '>', $output_file or die "Kann Datei '$output_file' nicht öffnen: $!\n";
print $fh $html;
close $fh;

sub create_html_document {
    # DOCTYPE
    my $doctype = '<!doctype html>';
    
    # HTML-Element
    my $html_start = '<html lang="de">';
    my $html_end = '</html>';
    
    # HEAD-Bereich
    my $head = create_head();
    
    # BODY-Bereich
    my $body = create_body();
    
    # Komplettes Dokument zusammenfügen
    return join('', $doctype, $html_start, $head, $body, $html_end);
}

sub create_head {
    my @head_elements = (
        '<head>',
        '<meta charset="utf-8">',
        '<meta name="viewport" content="width=device-width,initial-scale=1">',
        '<title>STATUS-Overview</title>',
        '<link rel="stylesheet" href="status-overview.css">',
        '</head>'
    );
    
    return join('', @head_elements);
}

sub create_body {
    my @body_elements = (
        '<body>',
        '<main id="grid" aria-label="LIVE-Übersicht"></main>',
        '<script src="vendor-mpegts.js"></script>',
        '<script src="status-overview-player.js"></script>',
        '</body>'
    );
    
    return join('', @body_elements);
}
