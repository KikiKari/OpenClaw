#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "5ffbf77d6b5cc10c2346ffad0ecda0861279e5a3fae2da6f35b968286bed7b3d", "source_sha256": "7fc810e8bcb817cb81407c2ad604d4bd70dce9f3ff8cb2bbfbcacfec00febd1c", "target_language": "perl6"}
# status-overview.html — portiert nach perl6
# Quelle: html, Projects@TikTok-Live-Companion:plugin-source/browser-extension/status-overview.html
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

use v6;

sub create-html-document() {
    my $html = '<!doctype html>' ~ "\n" ~
               '<html lang="de">' ~ "\n" ~
               '<head>' ~ "\n" ~
               '    <meta charset="utf-8">' ~ "\n" ~
               '    <meta name="viewport" content="width=device-width,initial-scale=1">' ~ "\n" ~
               '    <title>STATUS-Overview</title>' ~ "\n" ~
               '    <link rel="stylesheet" href="status-overview.css">' ~ "\n" ~
               '</head>' ~ "\n" ~
               '<body>' ~ "\n" ~
               '    <main id="grid" aria-label="LIVE-Übersicht"></main>' ~ "\n" ~
               '    <script src="vendor-mpegts.js"></script>' ~ "\n" ~
               '    <script src="status-overview-player.js"></script>' ~ "\n" ~
               '</body>' ~ "\n" ~
               '</html>';
    
    return $html;
}

sub MAIN($output-file) {
    my $content = create-html-document();
    
    # Schreibe den Inhalt in die angegebene Datei
    spurt($output-file, $content);
    
    say "HTML document written to $output-file";
}
