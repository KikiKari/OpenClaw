#!/usr/bin/perl
# test_external_speech_filter.cjs — portiert nach perl5
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_external_speech_filter.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_external_speech_filter.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_external_speech_filter.cjs
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_external_speech_filter.cjs
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use Test2::V0;

# Mock the required functions from content-core.js
sub shouldFilterExternalSpeechTrigger {
    my ($text, $enabled, $prefixes) = @_;
    return 0 unless $enabled;
    return 0 unless defined $text;
    
    my $trimmed_text = $text;
    $trimmed_text =~ s/^\s+//;
    
    if (defined $prefixes && length($prefixes) > 0) {
        for my $char (split //, $prefixes) {
            if (index($trimmed_text, $char) == 0) {
                return 1;
            }
        }
        return 0;
    } else {
        return substr($trimmed_text, 0, 1) eq '.';
    }
}

sub normalizeExternalSpeechTriggerCharacters {
    my ($text) = @_;
    
    # Handle undefined or empty input
    return '' unless defined $text;
    return '' if length($text) == 0;
    
    # For single dot, return dot
    return '.' if $text eq '.';
    
    # Remove leading/trailing whitespace
    $text =~ s/^\s+|\s+$//g;
    
    # Keep only valid trigger characters: .,-;: and Unicode emojis (basic handling)
    # This is simplified - real implementation would need proper Unicode handling
    $text =~ s/[^.,\-;:!\x{1F600}-\x{1F64F}\x{1F300}-\x{1F5FF}\x{1F680}-\x{1F6FF}\x{1F1E0}-\x{1F1FF}\x{2600}-\x{26FF}\x{2700}-\x{27BF}]//g;
    
    # Limit to first 5 characters for emoji case
    if (length($text) > 5) {
        $text = substr($text, 0, 5);
    }
    
    return $text;
}

# Main tests
for my $enabled (0, 1) {
    for my $text ('.Text', '. Text', '  .Text', "\t\n. Text", 'Normal', 'Ein Satz. Noch einer', '') {
        my $test_name = sprintf('{"enabled":%s,"text":"%s"}', $enabled ? 'true' : 'false', $text);
        
        my $expected = $enabled && (defined $text ? $text : '') =~ /^\s*\./;
        my $result = shouldFilterExternalSpeechTrigger($text, $enabled, undef);
        
        is($result, $expected, $test_name);
    }
}

# 0PE-187: individual literal prefixes, commas and semicolons are not separators
for my $enabled (0, 1) {
    for my $text ('.Hallo', ',Hallo', '- Hallo', '  , Hallo') {
        my $result = shouldFilterExternalSpeechTrigger($text, $enabled, '.,-');
        my $expected = $enabled ? 1 : 0;
        is($result, $expected, "0PE-187 prefix test: $text with enabled=$enabled");
    }
    
    for my $text ('Hallo, zusammen.', 'Normal-Text', 'Hallo', '.') {
        my $result = shouldFilterExternalSpeechTrigger($text, $enabled, ',-');
        is($result, 0, "0PE-187 non-trigger test: $text with enabled=$enabled");
    }
    
    {
        my $result = shouldFilterExternalSpeechTrigger(';Hallo', $enabled, ';');
        my $expected = $enabled ? 1 : 0;
        is($result, $expected, "semicolon prefix test with enabled=$enabled");
    }
    
    {
        my $result = shouldFilterExternalSpeechTrigger('[Hallo', $enabled, '[');
        my $expected = $enabled ? 1 : 0;
        is($result, $expected, "bracket prefix test with enabled=$enabled");
    }
    
    {
        my $result = shouldFilterExternalSpeechTrigger('Hallo', $enabled, '[');
        is($result, 0, "non-bracket prefix test with enabled=$enabled");
    }
}

# 0PE-187: five Unicode scalar triggers, paste sanitization and explicit empty selection
is(normalizeExternalSpeechTriggerCharacters(undef), '.', 'normalize undefined');
is(normalizeExternalSpeechTriggerCharacters(''), '', 'normalize empty string');
is(normalizeExternalSpeechTriggerCharacters('.,-;:!' ), '.,-;:', 'normalize punctuation with exclamation');
is(normalizeExternalSpeechTriggerCharacters(' a1 "\'.,- '), '.,-', 'normalize with spaces and quotes');

# Simplified emoji test - using placeholder since full Unicode support complex in Perl without modules
is(normalizeExternalSpeechTriggerCharacters('😀😁😂😃😄😅'), '😀😁😂😃😄', 'normalize emojis');

is(shouldFilterExternalSpeechTrigger('😀Hallo', 1, '😀'), 1, 'emoji trigger');
is(shouldFilterExternalSpeechTrigger('.Hallo', 1, ''), 0, 'empty prefixes');
is(shouldFilterExternalSpeechTrigger('.Hallo', 1, ','), 0, 'wrong prefix');

done_testing();
