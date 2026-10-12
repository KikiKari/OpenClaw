#!/usr/bin/perl
# test_android_recovery.cjs — portiert nach perl5
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_android_recovery.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_android_recovery.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_android_recovery.cjs
# auch in: Projects@codex/0pe-177-peak-protection:plugin-source/scripts/test_android_recovery.cjs
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use Test2::V0;
use File::Spec;
use File::Slurp qw(read_file);
use JSON;

# Emulate Node.js modules and functions
sub path_resolve {
    my @parts = @_;
    return File::Spec->rel2abs(File::Spec->catfile(@parts));
}

sub path_join {
    my @parts = @_;
    return File::Spec->catfile(@parts);
}

my $raw = path_resolve(__FILE__, '../../mobile/android/app/src/main/res/raw');

# Setup function equivalent
sub setup {
    my ($ios) = @_;
    my $now = 10000;
    my $plays = 0;
    my $seq = 0;
    my %timers = ();
    my @intervals = ();
    my %listeners = ();
    my @events = ();

    # Video mock object
    my $video = {
        clientWidth => 100,
        clientHeight => 100,
        currentTime => 1,
        paused => 0,
        ended => 0,
        readyState => 4,
        dataset => {},
        addEventListener => sub {
            my ($n, $f) = @_;
            $listeners{$n} = $f;
        },
        play => sub {
            $plays++;
        },
        textTracks => []
    };

    # Root mock object
    my $root = {
        location => {
            origin => 'https://www.tiktok.com',
            pathname => '/@creator/live'
        },
        crypto => {
            randomUUID => sub {
                $seq++;
                my $id = sprintf("%012d", $seq);
                return "11111111-1111-1111-1111-$id";
            }
        },
        Date => {
            now => sub {
                return $now;
            }
        },
        document => {
            scripts => [],
            body => {
                innerText => ''
            },
            querySelectorAll => sub {
                my ($s) = @_;
                return $s eq 'video' ? [$video] : [];
            },
            querySelector => sub { return undef; }
        },
        tlcBridge => {
            postMessage => sub {
                my ($s) = @_;
                push @events, decode_json($s);
            }
        },
        addEventListener => sub {
            my ($n, $f) = @_;
            $listeners{$n} = $f;
        },
        postMessage => sub {
            my ($m) = @_;
            push @events, $m;
        },
        setInterval => sub {
            my ($f) = @_;
            push @intervals, $f;
            return scalar(@intervals);
        },
        clearInterval => sub {},
        setTimeout => sub {
            my ($f, $ms) = @_;
            $seq++;
            $timers{$seq} = {
                f => $f,
                at => $now + $ms
            };
            return $seq;
        },
        clearTimeout => sub {
            my ($id) = @_;
            delete $timers{$id};
        }
    };

    if ($ios) {
        delete $root->{tlcBridge};
        $root->{webkit} = {
            messageHandlers => {
                tlcBridge => {
                    postMessage => sub {
                        my ($m) = @_;
                        push @events, $m;
                    }
                }
            }
        };
    }

    $root->{top} = $root;

    # Read and execute the JavaScript file content (mocked here)
    my $js_content = read_file(path_join($raw, 'android_recovery.js'));
    # In a real scenario, you would need to evaluate the JS code in a Perl context,
    # which is complex and typically requires external tools or bindings.
    # For this translation, we assume the JS execution modifies $root appropriately.

    return {
        dispatch => sub {
            my ($data) = @_;
            my $event_data = {
                source => $root,
                origin => $root->{location}->{origin},
                data => {
                    source => "tiktok-live-companion",
                    %$data
                }
            };
            if (exists $listeners{message}) {
                $listeners{message}->($event_data);
            }
        },
        root => $root,
        video => $video,
        events => \@events,
        timers => \%timers,
        get_plays => sub { return $plays; },
        tick => sub {
            my ($ms) = @_;
            $now += $ms;
            for my $f (@intervals) {
                $f->();
            }
            for my $id (keys %timers) {
                my $t = $timers{$id};
                if ($t->{at} <= $now) {
                    delete $timers{$id};
                    $t->{f}->();
                }
            }
        },
        api => $root->{TLC_MOBILE_RECOVERY} # Assuming this is set by JS execution
    };
}

# Test cases
sub test_player_recovery_waits_configured_interval_once_and_never_touches_navigation {
    my $s = setup();
    $s->{api}->{command}('set-auto-reconnect', { enabled => 1, delaySeconds => 3 });
    $s->{api}->{recover}('stalled');
    is(keys %{$s->{timers}}, 1, 'Timer should be set');
    $s->{tick}(2999);
    is($s->{get_plays}(), 0, 'Should not have played yet');
    $s->{tick}(1);
    is($s->{get_plays}(), 1, 'Should have played once');
    is($s->{root}->{location}->{pathname}, '/@creator/live', 'Pathname should remain unchanged');
}

sub test_user_pause_and_vlc_cancel_pending_recovery {
    for my $cmd ('pause', 'set-vlc-active') {
        my $s = setup();
        $s->{api}->{command}('set-auto-reconnect', { enabled => 1 });
        $s->{api}->{recover}('stalled');
        $s->{api}->{command}($cmd, { active => 1 });
        $s->{tick}(4000);
        is($s->{get_plays}(), 0, "Recovery should be canceled by $cmd");
    }
}

sub test_media_progress_cancels_attempt_without_replacing_media {
    my $s = setup();
    $s->{api}->{command}('set-auto-reconnect', { enabled => 1 });
    $s->{api}->{recover}('waiting');
    $s->{video}->{currentTime} = 2;
    $s->{tick}(3000);
    is($s->{get_plays}(), 0, 'Recovery should be canceled by media progress');
}

sub test_caption_websocket_activity_expires_independently_from_menu {
    my $s = setup();
    $s->{dispatch}({ type => "caption", caption => { contents => [{ lang => "de", text => "test" }] } });
    my @caption_events = grep { $_->{type} eq "caption-state" } @{$s->{events}};
    my $last_event = $caption_events[-1];
    is($last_event->{payload}->{websocket}, 1, 'Websocket should be active initially');
    $s->{tick}(16000);
    @caption_events = grep { $_->{type} eq 'caption-state' } @{$s->{events}};
    $last_event = $caption_events[-1];
    is($last_event->{payload}->{websocket}, '', 'Websocket should be inactive after timeout');
    is($last_event->{payload}->{activityTtlMs}, 15000, 'Activity TTL should be 15000');
}

sub test_android_uses_byte_identical_browser_controller_and_protocol_parser {
    my @files = (
        ['hook_recovery.js', 'hook-recovery.js'],
        ['recovery_hook.js', 'hook.js'],
        ['proto_main.js', 'proto-main.js']
    );
    
    for my $pair (@files) {
        my ($mobile, $browser) = @$pair;
        my $mobile_path = path_join($raw, $mobile);
        my $browser_path = path_resolve(__FILE__, '../browser-extension', $browser);
        my $mobile_content = read_file($mobile_path);
        my $browser_content = read_file($browser_path);
        is($mobile_content, $browser_content, "$mobile should match $browser");
    }
}

sub test_ios_webkit_bridge_receives_correlated_recovery_observations {
    my $s = setup(1);
    $s->{tick}(1000);
    my $e = (grep { $_->{type} eq 'player-observation' } @{$s->{events}})[0];
    ok($e, 'Player observation event should exist');
    is($e->{payload}->{frameKind}, 'top', 'Frame kind should be top');
    like($e->{payload}->{documentId}, qr/^[a-f0-9-]{36}$/, 'Document ID should be UUID format');
    $s->{dispatch}({ type => 'caption', caption => { text => 'ios-caption' } });
    my @caption_events = grep { $_->{type} eq 'caption' } @{$s->{events}};
    is($caption_events[-1]->{payload}->{text}, 'ios-caption', 'Caption text should match');
}

sub test_ios_and_android_inject_identical_recovery_implementations {
    my $ios = path_resolve(__FILE__, '../../mobile/ios/Resources');
    my @files = (
        ['android_recovery.js', 'mobile-recovery.js'],
        ['hook_recovery.js', 'hook-recovery.js'],
        ['recovery_hook.js', 'recovery-hook.js'],
        ['export_privacy.js', 'export-privacy.js'],
        ['proto_main.js', 'proto-main.js'],
        ['content_core.js', 'content-core.js']
    );
    
    for my $pair (@files) {
        my ($a, $b) = @$pair;
        my $android_path = path_join($raw, $a);
        my $ios_path = path_join($ios, $b);
        my $android_content = read_file($android_path);
        my $ios_content = read_file($ios_path);
        is($android_content, $ios_content, "$a should match $b");
    }
}

sub test_connection_off_stops_companion_chat_delivery_on_resumes_without_touching_player {
    for my $ios (0, 1) {
        my $s = setup($ios);
        $s->{api}->{command}('set-connection', { enabled => 0 });
        $s->{dispatch}({ type => 'chat-message', chatMessage => { content => 'hidden from Companion' } });
        my @chat_events = grep { $_->{type} eq 'chat' } @{$s->{events}};
        is(scalar(@chat_events), 0, 'Chat should be hidden when connection is off');
        
        $s->{api}->{command}('set-connection', { enabled => 1 });
        $s->{dispatch}({ type => 'chat-message', chatMessage => { content => 'visible' } });
        @chat_events = grep { $_->{type} eq 'chat' } @{$s->{events}};
        is(scalar(@chat_events), 1, 'Chat should be visible when connection is on');
        is($s->{get_plays}(), 0, 'Player should not be touched');
    }
}

# Run tests
test_player_recovery_waits_configured_interval_once_and_never_touches_navigation();
test_user_pause_and_vlc_cancel_pending_recovery();
test_media_progress_cancels_attempt_without_replacing_media();
test_caption_websocket_activity_expires_independently_from_menu();
test_android_uses_byte_identical_browser_controller_and_protocol_parser();
test_ios_webkit_bridge_receives_correlated_recovery_observations();
test_ios_and_android_inject_identical_recovery_implementations();
test_connection_off_stops_companion_chat_delivery_on_resumes_without_touching_player();

done_testing();
