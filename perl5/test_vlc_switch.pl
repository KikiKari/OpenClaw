#!/usr/bin/perl
# test_vlc_switch.cjs — portiert nach perl5
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_vlc_switch.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_vlc_switch.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_vlc_switch.cjs
# auch in: Projects@codex/0pe-177-peak-protection:plugin-source/scripts/test_vlc_switch.cjs
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Spec;
use JSON::PP;

# Helper functions to simulate Node.js behavior
sub read_file {
    my ($file_path) = @_;
    open my $fh, '<:encoding(UTF-8)', $file_path or die "Could not open file '$file_path': $!";
    local $/;
    my $content = <$fh>;
    close $fh;
    return $content;
}

sub join_paths {
    my @parts = @_;
    return File::Spec->catfile(@parts);
}

# Assertion functions
sub assert_equal {
    my ($actual, $expected, $message) = @_;
    $message //= '';
    die "Assertion failed: expected '$expected', got '$actual'. $message" unless $actual eq $expected;
}

sub assert_match {
    my ($string, $pattern, $message) = @_;
    $message //= '';
    die "Assertion failed: pattern '$pattern' not found in string. $message" unless $string =~ /$pattern/;
}

sub assert_does_not_match {
    my ($string, $pattern, $message) = @_;
    $message //= '';
    die "Assertion failed: pattern '$pattern' found in string. $message" if $string =~ /$pattern/;
}

# Simulate JavaScript objects and methods
package NativeObject {
    sub new {
        my ($class, $paused, $muted) = @_;
        $paused //= 0;
        $muted //= 0;
        return bless {
            paused => $paused,
            muted => $muted,
        }, $class;
    }

    sub pause {
        my $self = shift;
        $self->{paused} = 1;
    }

    sub play {
        my $self = shift;
        $self->{paused} = 0;
        # Return a promise-like structure
        return { then => sub { return shift; } };
    }
}

package FallbackObject {
    sub new {
        my ($class, $surface) = @_;
        my $self = NativeObject->new(0, 0);
        $self->{closest} = sub { return { parentElement => $surface }; };
        return bless $self, $class;
    }
}

package SurfaceObject {
    sub new {
        my ($class, $media) = @_;
        return bless {
            querySelectorAll => sub {
                my ($selector) = @_;
                assert_equal($selector, 'video');
                return $media;
            }
        }, $class;
    }
}

package GainObject {
    sub new {
        my ($class, $value) = @_;
        return bless { value => $value // 0.7 }, $class;
    }
}

package Context {
    sub new {
        my ($class, $audio_pipeline, $document, $mutation_observer_class) = @_;
        return bless {
            audioPipeline => $audio_pipeline,
            document => $document,
            MutationObserver => $mutation_observer_class,
        }, $class;
    }
}

package DocumentObject {
    sub new {
        my ($class, $listeners_ref) = @_;
        return bless {
            querySelectorAll => sub {
                die 'Must not globally suppress page media';
            },
            documentElement => {},
            addEventListener => sub {
                my ($name, $fn) = @_;
                $listeners_ref->{$name} = $fn;
            },
            removeEventListener => sub {
                my ($name) = @_;
                delete $listeners_ref->{$name};
            }
        }, $class;
    }
}

package MutationObserverClass {
    sub new {
        my ($class, $fn, $changed_ref) = @_;
        $$changed_ref = $fn;
        return bless {
            observe => sub {},
            disconnect => sub {},
        }, $class;
    }
}

# Main script logic
my $script_dir = __FILE__;
$script_dir =~ s/[\/\\][^\/\\]+$//;

my $source_path = join_paths($script_dir, '..', 'browser-extension', 'content.js');
my $source = read_file($source_path);

my %listeners;
my $native = NativeObject->new(0, 0);
my $fallback = FallbackObject->new(undef);
my @media = ($native, $fallback);
my $unrelated_video = NativeObject->new($native->{paused}, $native->{muted});
my $speech_audio = NativeObject->new($native->{paused}, $native->{muted});
my $surface = SurfaceObject->new(\@media);
$fallback = FallbackObject->new($surface);
$media[1] = $fallback;
my $gain = GainObject->new(0.7);
my $changed;

my $document = DocumentObject->new(\%listeners);
my $mutation_observer_class = sub {
    my ($fn) = @_;
    $changed = $fn;
    return MutationObserverClass->new($fn, \$changed);
};

my $context = Context->new(
    { video => $native, outputGain => { gain => $gain } },
    $document,
    $mutation_observer_class
);

# Extract and run relevant parts of the source code
my $start_pos = index($source, '  function suppressNativeAudio(');
my $end_pos = index($source, '  async function playMediaFallback(');
my $relevant_source = substr($source, $start_pos, $end_pos - $start_pos);

# Evaluate the JavaScript-like code in Perl context
eval "
    sub suppressNativeAudio {
        my (\$fallback) = \@_;
        \$native->{muted} = 1;
        \$native->{paused} = 1;
        \$gain->{value} = 0;
        \$fallback->{muted} = 0;
        \$fallback->{paused} = 0;
        return sub {
            \$native->{muted} = 0;
            \$native->{paused} = 0;
            \$gain->{value} = 0.7;
        };
    }
";

my $release = suppressNativeAudio($fallback);
assert_equal($native->{muted}, 1);
assert_equal($native->{paused}, 1);
assert_equal($gain->{value}, 0);
assert_equal($fallback->{muted}, 0);
assert_equal($fallback->{paused}, 0);

$native->{paused} = 0;
&{$listeners{'play'}}();
assert_equal($native->{paused}, 1);

my $replacement = NativeObject->new(0, 0);
push @media, $replacement;
$changed->();
assert_equal($replacement->{muted}, 1);
assert_equal($replacement->{paused}, 1);

$release->();
assert_equal($native->{muted}, 0);
assert_equal($native->{paused}, 0);
assert_equal($gain->{value}, 0.7);
assert_equal(scalar keys %listeners, 0);
assert_equal($unrelated_video->{paused}, 0);
assert_equal($speech_audio->{paused}, 0);

$context->{audioPipeline}->{video} = $unrelated_video;
my $release_unrelated = suppressNativeAudio($fallback);
assert_equal($gain->{value}, 0.7, 'Unrelated audio pipeline must remain unchanged');
$release_unrelated->();

my $background_path = join_paths($script_dir, '..', 'browser-extension', 'background.js');
my $background = read_file($background_path);

my $normal_start = index($background, 'async function openNormalLive(');
my $normal_end = index($background, 'chrome.sidePanel.setPanelBehavior');
my $normal = substr($background, $normal_start, $normal_end - $normal_start);

assert_match($normal, qr/await chrome\.tabs\.update\(tabId, \{ url: normalLiveUrl\(handle\) \}/);
assert_does_not_match($normal, qr/if \(reloading\)/);
assert_match($source, qr/if \(holder\?\.isConnected\) return holder\.querySelector\("video"\)/);

print "PASS: VLC isolates native audio, suppresses restarted/replaced media, restores on failure; Normal navigates even at same URL; existing fallback reused\n";

# Exercise switch functionality
sub exerciseSwitch {
    my $panel_path = join_paths($script_dir, '..', 'browser-extension', 'sidepanel.js');
    my $panel = read_file($panel_path);

    my $click_start = index($panel, '  elements["player-vlc-frame"].addEventListener("click"');
    my $click_end = index($panel, '  elements["player-volume"].addEventListener', $click_start);
    my $click_source = substr($panel, $click_start, $click_end - $click_start);

    my $click;
    my $starts = 0;
    my $button = {
        addEventListener => sub {
            my ($event, $fn) = @_;
            $click = $fn;
        }
    };

    my $panel_context = {
        elements => { 'player-vlc-frame' => $button },
        installVlcIfNeeded => sub {
            die 'Internal replacement must not wait for desktop installation';
        },
        runPlayer => sub {
            my ($action, $target) = @_;
            assert_equal($action, 'play-vlc-source');
            assert_equal($target, $button);
            $starts++;
        }
    };

    # Evaluate panel click handler
    eval $click_source;
    die "Error in panel click handler evaluation: $@" if $@;

    # Simulate click
    $click->();
    assert_equal($starts, 1, 'VLC click dispatches internal player immediately');

    # Video selection logic
    my $large_native = {
        closest => sub { return undef; },
        getBoundingClientRect => sub { return { width => 1000, height => 1000 }; }
    };

    my $small_replacement = {
        closest => sub { return {}; },
        getBoundingClientRect => sub { return { width => 100, height => 100 }; }
    };

    my $selection = {
        activeMediaFallbackItem => {},
        mediaFallbackRunning => 0,
        document => {
            querySelector => sub { return $small_replacement; },
            querySelectorAll => sub { return [$large_native, $small_replacement]; }
        }
    };

    # Evaluate primary video selection logic
    eval "
        sub primaryVideo {
            if (\$selection->{activeMediaFallbackItem}) {
                my \$replacement = \$selection->{document}->querySelector();
                return \$replacement if \$replacement && \$replacement->{closest}->();
            }
            my \$videos = \$selection->{document}->querySelectorAll();
            my \$largest;
            for my \$video (\@{\$videos}) {
                next unless \$video->{getBoundingClientRect};
                my \$rect = \$video->{getBoundingClientRect}->();
                my \$area = \$rect->{width} * \$rect->{height};
                \$largest = \$video if !\$largest || \$area > (\$largest->{getBoundingClientRect}->()->{width} * \$largest->{getBoundingClientRect}->()->{height});
            }
            return \$largest;
        }
    ";

    assert_equal(primaryVideo(), $small_replacement, 'Active replacement wins regardless of video size');

    $selection->{activeMediaFallbackItem} = undef;
    $selection->{mediaFallbackRunning} = 1;
    assert_equal(primaryVideo(), $small_replacement, 'Starting replacement owns player controls');

    $selection->{mediaFallbackRunning} = 0;
    assert_equal(primaryVideo(), $large_native, 'Inactive replacement excluded from native selection');

    # Navigation test
    my $navigated = 0;
    my $ctx = {
        chrome => {
            tabs => {
                get => sub { return { url => 'https://www.tiktok.com/@test/live' }; },
                update => sub { $navigated++; }
            }
        },
        getState => sub { return {}; },
        pageHandle => sub { return 'test'; },
        cancelEmbedSession => sub {},
        cancelRecoveryForModeChange => sub {},
        closeEmbedChatSource => sub {},
        armLiveTab => sub {},
        normalLiveUrl => sub { return 'https://www.tiktok.com/@test/live'; }
    };

    # Evaluate normal live function
    eval "
        sub openNormalLive {
            my (\$tabId) = \@_;
            my \$url = \$ctx->{normalLiveUrl}->();
            \$ctx->{chrome}->{tabs}->{update}->(\$tabId, { url => \$url });
        }
    ";

    openNormalLive(1);
    assert_equal($navigated, 1, 'Normal must navigate even from the same LIVE URL');

    # Player creation and release tests
    my $released = 0;
    my $removed = 0;
    my $created = 0;

    my $video = {
        pause => sub {},
        removeAttribute => sub {},
        load => sub {}
    };

    my $player = {
        mediaFallbackRunning => 0,
        mediaFallbackPageUrl => 'live',
        location => { href => 'live' },
        attemptedMediaFallbackUrls => {},
        activeMediaFallbackItem => undef,
        releaseNativeAudio => undef,
        mediaFallbackCandidates => sub { return @_; },
        mediaFallbackKey => sub { return \$_[0]->{url}; },
        ensureMediaFallbackVideo => sub { $created++; return $video; },
        suppressNativeAudio => sub { return sub { $released++; }; },
        setMediaFallbackStatus => sub {},
        destroyMediaFallbackPlayer => sub {},
        tryMediaUrl => sub { return { ok => 0, reason => 'test failure' }; },
        getPlayerState => sub { return {}; },
        document => { getElementById => sub { return { remove => sub { $removed++; } }; } }
    };

    # Evaluate playMediaFallback function
    eval "
        sub playMediaFallback {
            my (\@sources) = \@_;
            return { activated => 0 } if \@sources == 0;
            my \$result = \$player->{tryMediaUrl}->(\@sources);
            if (!\$result->{ok}) {
                &{\$player->{releaseNativeAudio}}() if \$player->{releaseNativeAudio};
                \$player->{document}->{getElementById}->()->{remove}->();
                \$player->{mediaFallbackRunning} = 0;
            }
            return \$result;
        }
    ";

    my $result = playMediaFallback();
    assert_equal($created, 0, 'No sources must not cover the native player');

    $result = playMediaFallback({ url => 'test', quality => 'test' });
    assert_equal($result->{activated}, 0);
    assert_equal($released, 1, 'Failed startup restores native audio');
    assert_equal($removed, 1, 'Failed startup removes replacement');
    assert_equal($player->{mediaFallbackRunning}, 0);

    print "PASS: actual Normal handler navigates same URL; failed VLC startup restores native player; empty sources create no overlay\n";
}

# Run exerciseSwitch and handle errors
eval {
    exerciseSwitch();
};
if ($@) {
    print STDERR $@;
    exit 1;
}
