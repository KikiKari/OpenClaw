#!/usr/bin/perl
# tiktok-common.js — portiert nach perl5
# Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live/scripts/tiktok-common.js
# Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use POSIX qw(uname);

# Shared TikTok LIVE safety contract: handle normalization, per-CPU load
# preflight, exact account LIVE selectors, strict HTTPS TikTok-CDN FLV
# validation, and normalized extractor statuses.

my $DEFAULT_MAX_LOAD_PER_CPU = 1.5;
my $USERNAME_PATTERN = qr/^[A-Za-z0-9._]{1,24}$/;
my %FAILURE_STATUSES = map { $_ => 1 } qw(offline restricted overloaded dependency_missing technical_error);

sub normalizeUsername {
    my ($raw) = @_;
    my $username = defined $raw ? $raw : '';
    $username =~ s/^\s+|\s+$//g;
    $username =~ s/^@+//;
    if ($username !~ $USERNAME_PATTERN) {
        die 'Invalid TikTok username; expected 1-24 letters, digits, dots, or underscores';
    }
    return $username;
}

sub loadState {
    my ($env) = @_;
    $env //= \%ENV;
    my $cpuCount = scalar @{ [uname()] } || 1;
    $cpuCount = 1 if $cpuCount < 1;
    my $observed = exists $env->{TIKTOK_TEST_LOAD_PER_CPU}
        ? $env->{TIKTOK_TEST_LOAD_PER_CPU} + 0
        : do {
            open(my $fh, '<', '/proc/loadavg') or return;
            my $load = <$fh>;
            close($fh);
            chomp($load);
            my @loads = split /\s+/, $load;
            $loads[0] / $cpuCount;
        };
    my $maximum = exists $env->{TIKTOK_MAX_LOAD_PER_CPU}
        ? $env->{TIKTOK_MAX_LOAD_PER_CPU} + 0
        : $DEFAULT_MAX_LOAD_PER_CPU;
    if (!defined $observed || !defined $maximum || $maximum <= 0) {
        die 'Invalid TikTok load configuration';
    }
    return {
        overloaded => $observed > $maximum,
        loadPerCpu => $observed,
        maximum => $maximum
    };
}

sub enforceLoadLimit {
    my ($method) = @_;
    my $state = loadState();
    return $state unless $state->{overloaded};
    print STDERR JSON::PP->new->encode({
        status => 'overloaded',
        method => $method,
        loadPerCpu => sprintf("%.3f", $state->{loadPerCpu}),
        maximum => $state->{maximum},
        message => 'Host is overloaded; retry on another node or later'
    }) . "\n";
    exit 75;
}

sub liveHrefSelectors {
    my ($username) = @_;
    my $href = "/\@$username/live";
    return ["a[href=\"$href\"]", "a[href^=\"$href?\"]"];
}

sub isAllowedStreamUrl {
    my ($value) = @_;
    eval {
        my $url = URI->new($value);
        my $hostname = lc($url->host // '');
        return $url->scheme eq 'https' &&
               lc($url->path) =~ /\.flv/ &&
               $hostname =~ /(^|\.)tiktokcdn(-[a-z0-9-]+)?\.com$/;
    };
    return 0 if $@;
    return 1;
}

sub isSuccessfulStreamResponse {
    my ($status, $value) = @_;
    return defined $status &&
           int($status) == $status &&
           $status >= 200 &&
           $status < 300 &&
           isAllowedStreamUrl($value);
}

# Order matters: longer keys first so `_uhd_60` never matches as `hd_60`/`hd`.
my $QUALITY_URL_PATTERN = qr/_(uhd_60|hd_60|origin|hd|sd|ld|ao)\.(?:flv|m3u8)/;

sub qualityKeyFromUrl {
    my ($value) = @_;
    eval {
        my $url = URI->new($value);
        my $path = lc($url->path);
        if ($path =~ $QUALITY_URL_PATTERN) {
            return $1;
        }
        return undef;
    };
    return undef if $@;
    return undef;
}

sub normalizeExtractorResult {
    my ($value, $method, $username) = @_;
    my $technicalError = {
        success => 0,
        status => 'technical_error',
        method => $method,
        username => $username,
        message => 'invalid extractor result'
    };
    return $technicalError unless ref($value) eq 'HASH';
    if ($value->{success}) {
        if ($value->{status} ne 'live' || !isAllowedStreamUrl($value->{url})) {
            return $technicalError;
        }
        my %result = %$value;
        $result{success} = 1;
        $result{status} = 'live';
        return \%result;
    }
    unless (defined $value->{success} && !$value->{success}) {
        return $technicalError;
    }
    my %result = %$value;
    $result{success} = 0;
    $result{status} = exists $FAILURE_STATUSES{$value->{status}}
        ? $value->{status}
        : 'technical_error';
    $result{method} = defined $value->{method} && ref($value->{method}) eq '' ? $value->{method} : $method;
    $result{username} = defined $value->{username} && ref($value->{username}) eq '' ? $value->{username} : $username;
    delete $result{url};
    delete $result{streams};
    delete $result{allUrls};
    return \%result;
}

sub classifyFinalFailure {
    my ($results) = @_;
    my %statuses;
    for my $result (@$results) {
        next unless ref($result) eq 'HASH' && defined $result->{status};
        $statuses{$result->{status}} = 1 if exists $FAILURE_STATUSES{$result->{status}};
    }
    return 'overloaded' if exists $statuses{overloaded};
    return 'restricted' if exists $statuses{restricted};
    return 'technical_error' if exists $statuses{technical_error};
    return 'offline' if exists $statuses{offline};
    return 'dependency_missing' if exists $statuses{dependency_missing};
    return 'technical_error';
}

sub exitCodeForResult {
    my ($result) = @_;
    return 0 if ref($result) eq 'HASH' && $result->{success} && $result->{status} eq 'live';
    return 75 if ref($result) eq 'HASH' && $result->{status} eq 'overloaded';
    return 1 if ref($result) eq 'HASH' && ($result->{status} eq 'offline' || $result->{status} eq 'restricted');
    return 2;
}

sub classifyDirectLiveState {
    my ($args) = @_;
    my $username = $args->{username};
    my $currentPath = $args->{currentPath};
    my $title = $args->{title};
    my $bodyText = $args->{bodyText};
    my $successfulStreamResponse = $args->{successfulStreamResponse};
    
    my $expectedPath = "/\@$username/live";
    if ($currentPath ne $expectedPath) {
        return { status => 'offline', reason => 'target live page redirected' };
    }
    if ($successfulStreamResponse) {
        return { status => 'live', reason => 'successful TikTok CDN stream response' };
    }

    my $normalizedBody = defined $bodyText ? $bodyText : '';
    $normalizedBody =~ s/\s+/ /g;
    $normalizedBody = lc($normalizedBody);
    my $normalizedTitle = defined $title ? lc($title) : '';
    my $accountLiveTitle = index($normalizedTitle, "(\@$username)") != -1 && index($normalizedTitle, "is live") != -1;
    $accountLiveTitle = index($normalizedTitle, "(\@$username)") != -1 && index(lc($username), "is live") != -1 if !$accountLiveTitle;
    my @endedMarkers = (
        'live has ended',
        'das live ist beendet',
        'live wurde beendet',
        'dieses live ist beendet',
        'stream has ended'
    );
    for my $marker (@endedMarkers) {
        if (index($normalizedBody, $marker) != -1) {
            return { status => 'offline', reason => 'target live page reports ended stream' };
        }
    }

    my @restrictionMarkers = (
        'dieses live enthält themen, die von einigen als unangenehm empfunden werden könnten',
        'melde dich an, um das beste aus deiner tiktok-erfahrung herauszuholen',
        'bei tiktok anmelden',
        'melde dich an für das volle live-erlebnis',
        'melde dich an für das vollständige erlebnis',
        'this live may contain content that could be uncomfortable',
        'log in to tiktok',
        'log in for the full live experience',
        'mature content',
        'age-restricted',
        'viewer discretion'
    );
    if ($accountLiveTitle) {
        for my $marker (@restrictionMarkers) {
            if (index($normalizedBody, $marker) != -1) {
                return { status => 'restricted', reason => 'target live page requires authentication' };
            }
        }
        return {
            status => 'restricted',
            reason => 'target is live but no accessible media response was available'
        };
    }
    return { status => 'offline', reason => 'no account-specific live signal' };
}

sub forcedOffline {
    my ($method, $username) = @_;
    return 0 unless exists $ENV{TIKTOK_TEST_OFFLINE} && $ENV{TIKTOK_TEST_OFFLINE} eq '1';
    print STDERR JSON::PP->new->encode({
        success => 0,
        status => 'offline',
        method => $method,
        username => $username,
        message => 'forced offline test mode'
    }) . "\n";
    return 1;
}

1;
