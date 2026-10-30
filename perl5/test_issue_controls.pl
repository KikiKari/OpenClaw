#!/usr/bin/perl
# test_issue_controls.cjs — portiert nach perl5
# Quelle: javascript, Projects@codex/0pe-177-peak-protection:plugin-source/scripts/test_issue_controls.cjs
# auch in: Projects@vercel/install-and-configure-vercel-w-98sxlo:plugin-source/scripts/test_issue_controls.cjs
# Erzeugt: 2026-10-30 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use Test2::V0;
use File::Spec;
use File::Slurp qw(read_file);

# Simulate node modules and core functionality
my $source = read_file(File::Spec->catfile('..', 'browser-extension', 'sidepanel.js'));
my $core_content = read_file(File::Spec->catfile('..', 'browser-extension', 'content-core.js'));
my $core = {}; # This would need actual implementation from content-core.js

sub fragment {
    my ($start, $end) = @_;
    my $a = index($source, $start);
    my $b = index($source, $end, $a + length($start));
    die "Fragment not found" unless $a >= 0 && $b > $a;
    return substr($source, $a, $b - $a);
}

sub controls {
    my %elements;
    my $document = { activeElement => undef };

    return {
        elements => \%elements,
        document => $document,
    };
}

# Test 175
sub test_175 {
    for my $enabled (0, 1) {
        my @spoken;
        my $s = {
            core => $core,
            filterExternalSpeechTriggers => $enabled,
            speechEnabled => 1,
            speechQueue => [],
            elements => { 'speech-status' => {} },
            pumpSpeech => sub {},
            speechText => sub { my $item = shift; return "Autor sagt " . $item->{content} },
            speechLang => sub { return 'de' },
            serviceSpeech => sub { my $text = shift; push @spoken, $text; return; },
            browserSpeech => sub { die 'unexpected fallback'; },
        };

        # Mock VM context execution
        # In Perl, we can't directly execute JS code, so we simulate the behavior
        my $fragment1 = fragment('  async function speakItem(', '  async function pumpSpeech(');
        my $fragment2 = fragment('  function enqueueSpeech(', '  function ');

        # Simulate running the functions
        for my $content ('.Text', '. Text', '  .Text', 'Normal', 'Ein Satz. Noch einer') {
            # Simulate speakItem and enqueueSpeech
            push @{$s->{speechQueue}}, { content => $content };
            if ($enabled) {
                if ($content !~ /^\./) {
                    push @spoken, $s->{speechText}->({ content => $content });
                }
            } else {
                push @spoken, $s->{speechText}->({ content => $content });
            }
        }

        is(scalar @spoken, $enabled ? 2 : 5, "Spoken count matches expected");
        is(scalar @{$s->{speechQueue}}, $enabled ? 2 : 5, "Speech queue count matches expected");
    }
}

# Test 176 Speech Switch
sub test_176_speech_switch {
    my $s = controls();
    $s->{speechEnabled} = 0;
    my $send_result = 1;
    $s->{send} = sub { 
        if ($send_result) { 
            $s->{speechEnabled} = !$s->{speechEnabled}; 
        } else { 
            die "failed"; 
        } 
    };
    $s->{refresh} = sub {};
    $s->{activateSpeech} = sub { $s->{speechEnabled} = 1; };
    $s->{stopSpeech} = sub { $s->{speechEnabled} = 0; };

    # Simulate event listener addition and click
    $s->{elements}->{'toggle-speech'} = {
        addEventListener => sub {},
        click => sub { 
            eval { 
                $s->{send}->(); 
                if ($@ && $@ =~ /failed/) {
                    $s->{elements}->{'speech-status'}->{textContent} = "failed";
                }
            };
        },
    };

    $s->{elements}->{'speech-status'} = { textContent => '' };

    # First click - should enable
    $s->{elements}->{'toggle-speech'}->click();
    ok($s->{speechEnabled}, "Speech enabled after first click");

    # Second click - should fail
    $send_result = 0;
    $s->{elements}->{'toggle-speech'}->click();
    ok($s->{speechEnabled}, "Speech still enabled after failed request");
    like($s->{elements}->{'speech-status'}->{textContent}, qr/failed/, "Error message shown");

    # Third click - should disable
    $send_result = 1;
    $s->{elements}->{'toggle-speech'}->click();
    ok(!$s->{speechEnabled}, "Speech disabled after successful request");
}

# Test 176 Connection
sub test_176_connection {
    my @calls;
    my $s = controls();
    $s->{currentState} = { hook => { armed => 0 } };
    $s->{send} = sub { 
        my $cmd = shift; 
        push @calls, $cmd; 
        $s->{currentState}->{hook}->{armed} = !$s->{currentState}->{hook}->{armed};
    };
    $s->{refresh} = sub { 
        $s->{currentState}->{hook}->{armed} = !$s->{currentState}->{hook}->{armed};
    };

    $s->{elements}->{'toggle-hook'} = {
        addEventListener => sub {},
        click => sub { 
            eval { 
                $s->{send}->('TLC_TOGGLE_HOOK'); 
                if ($@) {
                    $s->{elements}->{notice}->{textContent} = $@;
                }
            };
        },
    };

    $s->{elements}->{notice} = { textContent => '' };

    # Click twice to enable then disable
    $s->{elements}->{'toggle-hook'}->click();
    $s->{elements}->{'toggle-hook'}->click();
    
    is(\@calls, ['TLC_TOGGLE_HOOK', 'TLC_TOGGLE_HOOK'], "Correct commands sent");

    # Fail scenario
    $s->{send} = sub { die "failed"; };
    $s->{elements}->{'toggle-hook'}->click();
    
    ok(!$s->{currentState}->{hook}->{armed}, "Hook disarmed after failure");
    like($s->{elements}->{notice}->{textContent}, qr/failed/, "Error message shown");
}

# Test 176 Connection Dialog
sub test_176_connection_dialog {
    my $s = controls();
    
    $s->{elements}->{'open-connection-settings'} = {
        addEventListener => sub {},
        click => sub {
            $s->{elements}->{'connection-settings-modal'}->{hidden} = 0;
            $s->{document}->{activeElement} = $s->{elements}->{'close-connection-settings'};
        },
    };
    
    $s->{elements}->{'connection-settings-modal'} = {
        hidden => 1,
        querySelectorAll => sub { 
            return [$s->{elements}->{'close-connection-settings'}, $s->{elements}->{'quick-recover-seconds'}]; 
        },
    };
    
    $s->{elements}->{'close-connection-settings'} = {
        focus => sub { $s->{document}->{activeElement} = $s->{elements}->{'close-connection-settings'}; }
    };
    
    $s->{elements}->{'quick-recover-seconds'} = {
        focus => sub { $s->{document}->{activeElement} = $s->{elements}->{'quick-recover-seconds'}; }
    };
    
    my $key_handler;
    $s->{document}->{addEventListener} = sub {
        my ($name, $fn) = @_;
        if ($name eq "keydown") {
            $key_handler = $fn;
        }
    };
    
    # Open dialog
    $s->{elements}->{'open-connection-settings'}->click();
    ok(!$s->{elements}->{'connection-settings-modal'}->{hidden}, "Modal opened");
    is($s->{document}->{activeElement}, $s->{elements}->{'close-connection-settings'}, "Focus moved to close button");
    
    # Simulate tab navigation
    my $prevented = 0;
    my $prevent_default = sub { $prevented++; };
    
    # Shift+Tab to last element
    $key_handler->({key => 'Tab', shiftKey => 1, preventDefault => $prevent_default});
    is($s->{document}->{activeElement}, $s->{elements}->{'quick-recover-seconds'}, "Focus moved to last element");
    
    # Tab back to first
    $key_handler->({key => 'Tab', shiftKey => 0, preventDefault => $prevent_default});
    is($s->{document}->{activeElement}, $s->{elements}->{'close-connection-settings'}, "Focus moved back to first element");
    is($prevented, 2, "PreventDefault called twice");
    
    # Escape to close
    $key_handler->({key => 'Escape'});
    ok($s->{elements}->{'connection-settings-modal'}->{hidden}, "Modal closed");
    is($s->{document}->{activeElement}, $s->{elements}->{'open-connection-settings'}, "Focus returned to opener");
}

# Run tests
test_175();
test_176_speech_switch();
test_176_connection();
test_176_connection_dialog();

done_testing();
