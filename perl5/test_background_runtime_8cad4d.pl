#!/usr/bin/perl
# test_background_runtime.cjs — portiert nach perl5
# Quelle: javascript, Projects@codex/0pe-177-peak-protection:plugin-source/scripts/test_background_runtime.cjs
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use Test2::V0;
use File::Spec;
use Cwd;

my $extension = File::Spec->rel2abs(File::Spec->catdir(dirname(__FILE__), '..', 'browser-extension'));
require File::Spec->catfile($extension, 'content-core.js');
require File::Spec->catfile($extension, 'export-privacy.js');

sub dirname {
    my ($path) = @_;
    $path =~ s/\/[^\/]*$//;
    return $path;
}

sub test_0PE_170_startup_retry_backs_off_caps_at_three_attempts_and_ignores_stale_documents {
    my $state = core::newEmbedSession("test", "creator", 1000);
    my $observe = sub {
        my ($now, $status, $documentId, $documentStartedAtMs) = @_;
        $documentId //= "a";
        $documentStartedAtMs //= 1000;
        my $result = core::advanceEmbedSession($state, { status => $status, documentId => $documentId, documentStartedAtMs => $documentStartedAtMs }, $now);
        $state = $result->{session};
        return $result->{action};
    };
    is($observe->(2000, "server-error"), "none");
    is($state->{nextAttemptAtMs}, 4000);
    is($observe->(3999, "server-error"), "none");
    is($observe->(4000, "server-error"), "reload");
    is($state->{attempt}, 2);
    is($observe->(5000, "playing"), "none");
    is($state->{phase}, "loading", "old document cannot complete a newer attempt");
    $observe->(6000, "unavailable", "b", 4500);
    is($state->{nextAttemptAtMs}, 10000);
    is($observe->(10000, "unavailable", "b", 4500), "reload");
    $observe->(11000, "server-error", "c", 10500);
    is($state->{phase}, "failed");
    is($state->{attempt}, 3);
    is($observe->(100000, "server-error", "c", 10500), "none");
}

sub test_0PE_170_playback_before_retry_cancels_it_while_login_ended_gesture_never_reload {
    my $observation = sub {
        my ($status) = @_;
        return { status => $status, documentId => "a", documentStartedAtMs => 1000 };
    };
    my $initial = core::newEmbedSession("test", "creator", 1000);
    my $waiting = core::advanceEmbedSession($initial, $observation->("server-error"), 2000)->{session};
    my $recovered = core::advanceEmbedSession($waiting, $observation->("playing"), 3000);
    is($recovered->{session}->{phase}, "playing");
    is($recovered->{session}->{nextAttemptAtMs}, undef);
    for my $status ("login-required", "ended", "awaiting-gesture") {
        my $result = core::advanceEmbedSession($waiting, $observation->($status), 6000);
        is($result->{action}, "none");
        is($result->{session}->{nextAttemptAtMs}, undef);
    }
    is(core::advanceEmbedSession({ %$initial, phase => "cancelled" }, $observation->("server-error"), 100000)->{action}, "none");
    is(core::classifyEmbedObservation({ text => "Server error" }), "server-error");
    is(core::classifyEmbedObservation({ text => "LIVE is unavailable" }), "unavailable");
    is(core::classifyEmbedObservation({ text => "Melde dich an für das vollständige Erlebnis" }), "login-required");
    is(core::classifyEmbedObservation({ playing => 1, readyState => 4 }), "playing");
    is(core::classifyEmbedObservation({ paused => 1, readyState => 4 }), "awaiting-gesture");
}

done_testing();
