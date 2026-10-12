#!/usr/bin/perl
# test_external_speech_filter.cjs — portiert nach perl5
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_external_speech_filter.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_external_speech_filter.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_external_speech_filter.cjs
# auch in: Projects@codex/0pe-177-peak-protection:plugin-source/scripts/test_external_speech_filter.cjs
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use Test2::V0;

# Importiere die Funktion shouldFilterExternalSpeechTrigger als filter
# (Annahme: Die Funktion ist in einem Perl-Modul implementiert)
require "./browser-extension/content-core.pl";  # oder wie auch immer das Modul heißen soll
my $filter = \&shouldFilterExternalSpeechTrigger;

# Führe Tests für verschiedene Kombinationen von enabled und text aus
for my $enabled (0, 1) {
    for my $text (qw(.Text . Text), "  .Text", "\t\n. Text", qw(Normal Ein Satz. Noch einer), "") {
        my $test_name = sprintf("%s - %s", $enabled ? "true" : "false", defined $text ? "'$text'" : "undef");
        
        # Erwartetes Ergebnis: enabled ist wahr UND text beginnt nach trimStart() mit '.'
        my $expected = $enabled && defined $text && $text =~ /^\s*\./;
        
        is($filter->($text, $enabled), $expected, $test_name);
    }
}

done_testing();
