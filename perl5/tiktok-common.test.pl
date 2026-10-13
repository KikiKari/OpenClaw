#!/usr/bin/perl
# tiktok-common.test.js — portiert nach perl5
# Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live/scripts/tiktok-common.test.js
# Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use Test::More;
use File::Spec;
use Cwd qw(abs_path);

# Lade das Modul tiktok-common.pm
my $script_dir = dirname(abs_path($0));
my $module_path = File::Spec->catfile($script_dir, 'tiktok-common.pm');
require $module_path;

# Test normalizeUsername
is(tiktok_common::normalizeUsername('@example_creator'), 'example_creator', 'normalizeUsername with @');
is(tiktok_common::normalizeUsername(' example_creator '), 'example_creator', 'normalizeUsername with spaces');
eval { tiktok_common::normalizeUsername('example_creator;id') };
like($@, qr/^Username contains invalid characters/, 'normalizeUsername throws on invalid chars');

# Test liveHrefSelectors
my $selectors = tiktok_common::liveHrefSelectors('example_creator');
is_deeply($selectors, [
    'a[href="/@example_creator/live"]',
    'a[href^="/@example_creator/live?"]'
], 'liveHrefSelectors output');

# Test loadState
my $env_backup = { %ENV };
$ENV{TIKTOK_TEST_LOAD_PER_CPU} = '2';
$ENV{TIKTOK_MAX_LOAD_PER_CPU} = '1.5';
my $state = tiktok_common::loadState();
is($state->{overloaded}, 1, 'loadState overloaded flag');
%ENV = %$env_backup;

# Test isAllowedStreamUrl
ok(tiktok_common::isAllowedStreamUrl('https://pull-flv-f77-tt04.tiktokcdn-eu.com/game/live.flv?sign=x'), 'isAllowedStreamUrl valid HTTPS');
ok(!tiktok_common::isAllowedStreamUrl('https://attacker.example/path/tiktokcdn/video.flv'), 'isAllowedStreamUrl invalid domain');
ok(!tiktok_common::isAllowedStreamUrl('http://pull-flv-f77-tt04.tiktokcdn-eu.com/game/live.flv'), 'isAllowedStreamUrl invalid HTTP');

# Test isSuccessfulStreamResponse
my $allowed_url = 'https://pull-flv-f77-tt04.tiktokcdn-eu.com/game/live.flv?sign=x';
ok(tiktok_common::isSuccessfulStreamResponse(200, $allowed_url), 'isSuccessfulStreamResponse 200');
ok(tiktok_common::isSuccessfulStreamResponse(206, $allowed_url), 'isSuccessfulStreamResponse 206');
ok(!tiktok_common::isSuccessfulStreamResponse(404, $allowed_url), 'isSuccessfulStreamResponse 404');

# Test normalizeExtractorResult
my $result;

$result = tiktok_common::normalizeExtractorResult(
    { success => 'false', status => 'offline' },
    'streamlink',
    'example_creator'
);
is($result->{status}, 'technical_error', 'normalizeExtractorResult string false');

$result = tiktok_common::normalizeExtractorResult(
    { success => 1, status => 'live' },
    'streamlink',
    'example_creator'
);
is($result->{status}, 'technical_error', 'normalizeExtractorResult non-hash success');

$result = tiktok_common::normalizeExtractorResult(
    { success => 0, status => 'offline', url => $allowed_url },
    'streamlink',
    'example_creator'
);
is($result->{status}, 'offline', 'normalizeExtractorResult offline');
is($result->{url}, undef, 'normalizeExtractorResult offline url removed');

$result = tiktok_common::normalizeExtractorResult(
    { success => 1, status => 'live', url => $allowed_url },
    'streamlink',
    'example_creator'
);
is($result->{status}, 'live', 'normalizeExtractorResult live');

# Test classifyFinalFailure
is(tiktok_common::classifyFinalFailure([
    { status => 'offline' },
    { status => 'dependency_missing' }
]), 'offline', 'classifyFinalFailure priority');

# Test exitCodeForResult
is(tiktok_common::exitCodeForResult({ success => 0, status => 'restricted' }), 1, 'exitCodeForResult restricted');
is(tiktok_common::exitCodeForResult({ success => 0, status => 'technical_error' }), 2, 'exitCodeForResult technical_error');

# Test classifyDirectLiveState
my $state_data;

$state_data = {
    username => 'example_creator',
    currentPath => '/@example_creator/live',
    title => 'Example (@example_creator) is LIVE - TikTok LIVE',
    bodyText => 'Dieses LIVE enthält Themen, die unangenehm sein könnten.',
    successfulStreamResponse => 0
};
is(tiktok_common::classifyDirectLiveState($state_data)->{status}, 'restricted', 'classifyDirectLiveState restricted');

$state_data = {
    username => 'example_creator',
    currentPath => '/@example_creator/live',
    title => 'Example (@example_creator) is LIVE - TikTok LIVE',
    bodyText => 'LIVE has ended',
    successfulStreamResponse => 0
};
is(tiktok_common::classifyDirectLiveState($state_data)->{status}, 'offline', 'classifyDirectLiveState offline');

$state_data = {
    username => 'example_creator',
    currentPath => '/@example_creator/live',
    title => 'Example (@example_creator) is LIVE - TikTok LIVE',
    bodyText => 'Suggested LIVE creators',
    successfulStreamResponse => 1
};
is(tiktok_common::classifyDirectLiveState($state_data)->{status}, 'live', 'classifyDirectLiveState live');

done_testing();

sub dirname {
    my $path = shift;
    my ($volume, $directories, $file) = File::Spec->splitpath($path);
    return File::Spec->catpath($volume, $directories, '');
}
