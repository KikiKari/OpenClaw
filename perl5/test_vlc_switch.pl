#!/usr/bin/perl
# test_vlc_switch.cjs — portiert nach perl5
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_vlc_switch.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_vlc_switch.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_vlc_switch.cjs
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_vlc_switch.cjs
# Erzeugt: 2026-10-24 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Spec;
use JSON;

# Simulate JavaScript objects and functions using hashes and subroutines
my $listeners = {};
my $native = {
    muted => 0,
    paused => 0,
    pause => sub { $_[0]->{paused} = 1; },
    play => sub { $_[0]->{paused} = 0; return {}; } # Return a dummy promise-like object
};
my $fallback = { muted => 0, paused => 0 };
my @media = ($native, $fallback);
my $unrelatedVideo = { %$native };
my $speechAudio = { %$native };
my $surface = {
    querySelectorAll => sub {
        my $selector = shift;
        die "Selector mismatch" unless $selector eq 'video';
        return \@media;
    }
};
$fallback->{closest} = sub { return { parentElement => $surface }; };
my $gain = { value => 0.7 };
my $changed;

# Mock DOM environment
my $document = {
    querySelectorAll => sub { die 'Must not globally suppress page media'; },
    documentElement => {},
    addEventListener => sub { my ($name, $fn) = @_; $listeners->{$name} = $fn; },
    removeEventListener => sub { my $name = shift; delete $listeners->{$name}; }
};

# Mock MutationObserver
package MutationObserver;
sub new {
    my ($class, $fn) = @_;
    $changed = $fn;
    return bless {}, $class;
}
sub observe {}
sub disconnect {}

# Read content.js file
my $script_dir = __FILE__;
$script_dir =~ s/test_vlc_switch\.pl$//;
my $content_js_path = File::Spec->catfile($script_dir, '..', 'browser-extension', 'content.js');
open my $fh, '<:encoding(UTF-8)', $content_js_path or die "Cannot read $content_js_path: $!";
my $source = do { local $/; <$fh> };
close $fh;

# Extract relevant code snippets
my $start_pos = index($source, '  function suppressNativeAudio(');
my $end_pos = index($source, '  async function playMediaFallback(');
my $snippet = substr($source, $start_pos, $end_pos - $start_pos);

# Create context with necessary variables
our $audioPipeline = { video => $native, outputGain => { gain => $gain } };
our $document_ref = $document;
our $MutationObserver_class = 'MutationObserver';

# Execute the snippet in context
eval $snippet;
die "Error executing content.js snippet: $@" if $@;

# Call suppressNativeAudio function
my $release = suppressNativeAudio($fallback);

# Assertions
die "native.muted should be true" unless $native->{muted};
die "native.paused should be true" unless $native->{paused};
die "gain.value should be 0" unless $gain->{value} == 0;
die "fallback.muted should be false" if $fallback->{muted};
die "fallback.paused should be false" if $fallback->{paused};

$native->{paused} = 0;
&{$listeners->{play}}() if exists $listeners->{play};
die "native.paused should be true after play event" unless $native->{paused};

my $replacement = { %$native, muted => 0, paused => 0 };
push @media, $replacement;
$changed->() if defined $changed;
die "replacement.muted should be true" unless $replacement->{muted};
die "replacement.paused should be true" unless $replacement->{paused};

$release->();
die "native.muted should be false after release" if $native->{muted};
die "native.paused should be false after release" if $native->{paused};
die "gain.value should be 0.7 after release" unless $gain->{value} == 0.7;
die "listeners should be empty" if keys %$listeners;
die "unrelatedVideo.paused should be false" if $unrelatedVideo->{paused};
die "speechAudio.paused should be false" if $speechAudio->{paused};

$audioPipeline->{video} = $unrelatedVideo;
my $releaseUnrelated = suppressNativeAudio($fallback);
die "gain.value should remain unchanged for unrelated audio pipeline" unless $gain->{value} == 0.7;
$releaseUnrelated->();

# Read background.js file
my $background_js_path = File::Spec->catfile($script_dir, '..', 'browser-extension', 'background.js');
open $fh, '<:encoding(UTF-8)', $background_js_path or die "Cannot read $background_js_path: $!";
my $background = do { local $/; <$fh> };
close $fh;

# Extract normal live handling code
$start_pos = index($background, 'async function openNormalLive(');
$end_pos = index($background, 'chrome.sidePanel.setPanelBehavior');
my $normal = substr($background, $start_pos, $end_pos - $start_pos);

# Assertions on extracted code
die "Normal should navigate to updated URL" unless $normal =~ /await chrome\.tabs\.update\(tabId, \{ url: normalLiveUrl\(handle\) \}\)/;
die "Normal should not check reloading condition" if $normal =~ /if \(reloading\)/;
die "Content script should handle connected holders" unless $source =~ /if \(holder\?\.isConnected\) return holder\.querySelector\("video"\)/;

print "PASS: VLC isolates native audio, suppresses restarted/replaced media, restores on failure; Normal navigates even at same URL; existing fallback reused\n";

# Exercise switch functionality
sub exerciseSwitch {
    # Read sidepanel.js file
    my $sidepanel_js_path = File::Spec->catfile($script_dir, '..', 'browser-extension', 'sidepanel.js');
    open $fh, '<:encoding(UTF-8)', $sidepanel_js_path or die "Cannot read $sidepanel_js_path: $!";
    my $panel = do { local $/; <$fh> };
    close $fh;

    # Find click handler section
    $start_pos = index($panel, '  elements["player-vlc-frame"].addEventListener("click"');
    $end_pos = index($panel, '  elements["player-volume"].addEventListener', $start_pos);
    my $clickSnippet = substr($panel, $start_pos, $end_pos - $start_pos);

    # Setup mock elements
    my $starts = 0;
    my $button = {
        addEventListener => sub {
            my ($event, $fn) = @_;
            die "Event type mismatch" unless $event eq 'click';
            # Store click handler
            $button->{_clickHandler} = $fn;
        }
    };

    our $elements = { 'player-vlc-frame' => $button };
    our $installVlcIfNeeded = sub { die 'Internal replacement must not wait for desktop installation'; };
    our $runPlayer = sub {
        my ($action, $target) = @_;
        die "Action mismatch" unless $action eq 'play-vlc-source';
        die "Target mismatch" unless $target eq $button;
        $starts++;
    };

    # Execute click handler snippet
    eval $clickSnippet;
    die "Error executing click snippet: $@" if $@;

    # Trigger click event
    if (defined $button->{_clickHandler}) {
        &{$button->{_clickHandler}}();
    }

    die "VLC click should dispatch internal player immediately" unless $starts == 1;

    # Test primaryVideo selection logic
    my $largeNative = {
        closest => sub { return undef; },
        getBoundingClientRect => sub { return { width => 1000, height => 1000 }; }
    };
    my $smallReplacement = {
        closest => sub { return {}; },
        getBoundingClientRect => sub { return { width => 100, height => 100 }; }
    };

    our $activeMediaFallbackItem = {};
    our $mediaFallbackRunning = 0;
    our $document_selection = {
        querySelector => sub { return $smallReplacement; },
        querySelectorAll => sub { return [$largeNative, $smallReplacement]; }
    };

    # Extract primaryVideo function
    $start_pos = index($source, '  function primaryVideo(');
    $end_pos = index($source, '  function playerToggleControl(');
    my $primaryVideoSnippet = substr($source, $start_pos, $end_pos - $start_pos);

    # Execute primaryVideo snippet
    eval $primaryVideoSnippet;
    die "Error executing primaryVideo snippet: $@" if $@;

    # Check primaryVideo behavior
    my $result = primaryVideo();
    die "Active replacement should win regardless of video size" unless $result == $smallReplacement;

    $activeMediaFallbackItem = undef;
    $mediaFallbackRunning = 1;
    $result = primaryVideo();
    die "Starting replacement should own player controls" unless $result == $smallReplacement;

    $mediaFallbackRunning = 0;
    $result = primaryVideo();
    die "Inactive replacement should be excluded from native selection" unless $result == $largeNative;

    # Test navigation behavior
    my $navigated = 0;
    our $chrome = {
        tabs => {
            get => sub { return { url => 'https://www.tiktok.com/@test/live' }; },
            update => sub { $navigated++; }
        }
    };
    our $getState = sub { return {}; };
    our $pageHandle = sub { return 'test'; };
    our $cancelEmbedSession = sub {};
    our $cancelRecoveryForModeChange = sub {};
    our $closeEmbedChatSource = sub {};
    our $armLiveTab = sub {};
    our $normalLiveUrl = sub { return 'https://www.tiktok.com/@test/live'; };

    # Execute normal live function
    eval $normal;
    die "Error executing normal live snippet: $@" if $@;

    openNormalLive(1);
    die "Normal must navigate even from the same LIVE URL" unless $navigated == 1;

    # Test media fallback failure handling
    my $released = 0;
    my $removed = 0;
    my $created = 0;
    my $video = {
        pause => sub {},
        removeAttribute => sub {},
        load => sub {}
    };

    our $mediaFallbackRunning_var = 0;
    our $mediaFallbackPageUrl = 'live';
    our $location = { href => 'live' };
    our $attemptedMediaFallbackUrls = {};
    our $activeMediaFallbackItem_var = undef;
    our $releaseNativeAudio = undef;
    our $mediaFallbackCandidates = sub { return $_[0]; };
    our $mediaFallbackKey = sub { return $_[0]->{url}; };
    our $ensureMediaFallbackVideo = sub { $created++; return $video; };
    our $suppressNativeAudio_var = sub { return sub { $released++; }; };
    our $setMediaFallbackStatus = sub {};
    our $destroyMediaFallbackPlayer = sub {};
    our $tryMediaUrl = sub { return { ok => 0, reason => 'test failure' }; };
    our $getPlayerState = sub { return {}; };
    our $document_player = { getElementById => sub { return { remove => sub { $removed++; } }; } };

    # Extract playMediaFallback function
    $start_pos = index($source, '  async function playMediaFallback(');
    $end_pos = index($source, '  async function configureLimiter(');
    my $playMediaFallbackSnippet = substr($source, $start_pos, $end_pos - $start_pos);

    # Execute playMediaFallback snippet
    eval $playMediaFallbackSnippet;
    die "Error executing playMediaFallback snippet: $@" if $@;

    # Test empty sources case
    playMediaFallback([]);
    die "No sources should not cover the native player" unless $created == 0;

    # Test failed startup case
    my $result_obj = playMediaFallback([{ url => 'test', quality => 'test' }]);
    die "Should indicate activation failure" unless !$result_obj->{activated};
    die "Failed startup should restore native audio" unless $released == 1;
    die "Failed startup should remove replacement" unless $removed == 1;
    die "mediaFallbackRunning should be false after failure" if $mediaFallbackRunning_var;

    print "PASS: actual Normal handler navigates same URL; failed VLC startup restores native player; empty sources create no overlay\n";
}

# Run exerciseSwitch and handle errors
eval {
    exerciseSwitch();
};
if ($@) {
    warn $@;
    exit 1;
}
