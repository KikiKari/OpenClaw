#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "626b644b1c3b76686f7ff7f9c235540a35ccc1c676dbc6cef5dac59bc9dcbccc", "source_sha256": "f1fb75db28e47070c42c0b401c9bdae5ac468bcd98550232038e409983691fad", "target_language": "perl6"}
# chat.css — portiert nach perl6
# Quelle: css, workspace@local:skills/github-clones/openclaw/ui/src/styles/chat.css
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

use v6;

sub MAIN($output-file) {
    my @imports = (
        './chat/layout.css',
        './chat/text.css',
        './chat/grouped.css',
        './chat/tool-cards.css',
        './chat/sidebar.css'
    );

    my $css-content = '';

    for @imports -> $import {
        $css-content ~= "\@import \"$import\";\n";
    }

    spurt($output-file, $css-content);
}
