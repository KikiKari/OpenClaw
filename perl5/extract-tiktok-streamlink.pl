#!/usr/bin/env perl
# extract-tiktok-streamlink.sh — portiert nach perl5
# Quelle: shell, OpenClaw@gateway2:skills/tiktok-live-mon/scripts/extraction-methods/extract-tiktok-streamlink.sh
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use POSIX qw(strftime);
use JSON;

my $username = $ARGV[0] // '';
$username =~ s/^@//;
my $quality = $ARGV[1] // 'best';
my $json_flag = $ARGV[2] // '';
my $timestamp = strftime("%Y-%m-%dT%H:%M:%SZ", gmtime);

sub emit_json {
    my ($success, $method, $user, $url, $qual, $author, $title, $error, $ts, $status) = @_;
    my %payload = (
        success => $success,
        method => $method,
        username => $user,
        url => $url // '',
        quality => $qual,
        author => $author // '',
        title => $title // '',
        error => $error // '',
        timestamp => $ts,
        status => $status
    );
    # Remove empty values
    for my $key (keys %payload) {
        delete $payload{$key} if !defined($payload{$key}) || $payload{$key} eq '';
    }
    if (exists $payload{success}) {
        $payload{success} = lc($payload{success}) eq 'true' ? JSON::true : JSON::false;
    }
    print STDERR encode_json(\%payload) . "\n";
}

if ($username !~ /^[A-Za-z0-9._]{1,24}$/) {
    print STDERR "Invalid TikTok username\n";
    exit 64;
}

unless ($quality =~ /^(best|worst|original|1080p60|720p60|720p|540p|360p|auto)$/) {
    print STDERR "Invalid stream quality\n";
    exit 64;
}

# Get load average per CPU
my $ncpu = `getconf _NPROCESSORS_ONLN`;
chomp $ncpu;
$ncpu = 1 if !$ncpu || $ncpu <= 0;
my $load_avg = `uptime | awk -F'load averages?:' '{gsub(/ *, */, \" \", \$2); print \$2}' | awk '{print \$1}'`;
chomp $load_avg;
my $load_per_cpu = $load_avg / $ncpu;

my $max_load = $ENV{TIKTOK_MAX_LOAD_PER_CPU} // 1.5;
if ($load_per_cpu > $max_load) {
    emit_json("false", "streamlink", $username, undef, $quality, undef, undef, "host overloaded", $timestamp, "overloaded");
    exit 75;
}

# Check if streamlink exists
if (system('which streamlink >/dev/null 2>&1') != 0) {
    emit_json("false", "streamlink", $username, undef, $quality, undef, undef, "streamlink not installed", $timestamp, "dependency_missing");
    exit 2;
}

my $live_url = "https://www.tiktok.com/\@$username/live";

my %quality_map = (
    'original' => 'origin,uhd_60,hd_60,hd,sd,ld,best,worst',
    'auto' => 'best,origin,uhd_60,hd_60,hd,sd,ld,worst',
    '1080p60' => 'uhd_60,hd_60,hd,sd,ld,worst',
    '720p60' => 'hd_60,hd,sd,ld,worst',
    '720p' => 'hd,sd,ld,worst',
    '540p' => 'sd,ld,worst',
    '360p' => 'ld,worst'
);

my $selector = $quality_map{$quality} // $quality;

# Try streamlink with --json first
my $output = `streamlink --json '$live_url' '$selector' 2>/dev/null`;
my $exit_code = $? >> 8;

if ($exit_code != 0 || !$output) {
    # Fallback to --stream-url
    my $url = `streamlink --stream-url '$live_url' '$selector' 2>/dev/null`;
    chomp $url;
    if ($? >> 8 != 0 || !$url) {
        emit_json("false", "streamlink", $username, undef, $quality, undef, undef, "streamlink failed or no stream found", $timestamp, "offline");
        exit 1;
    }
    if ($json_flag eq '--json') {
        emit_json("true", "streamlink", $username, $url, $quality, undef, undef, undef, $timestamp, "live");
    } else {
        print "$url\n";
    }
    exit 0;
}

# Parse JSON output
my ($url, $author, $title);
eval {
    my $data = decode_json($output);
    $url = $data->{url} // '';
    
    if (!$url && ref($data->{streams}) eq 'HASH') {
        my @keys = ('best', 'worst', keys %{$data->{streams}});
        for my $key (@keys) {
            if (exists $data->{streams}{$key} && ref($data->{streams}{$key}) eq 'HASH' && $data->{streams}{$key}{url}) {
                $url = $data->{streams}{$key}{url};
                last;
            }
        }
    }
    
    my $metadata = $data->{metadata} // {};
    $author = $metadata->{author} // '';
    $title = $metadata->{title} // '';
};
if ($@) {
    emit_json("false", "streamlink", $username, undef, $quality, undef, undef, "invalid streamlink JSON", $timestamp, "technical_error");
    exit 2;
}

if (!$url) {
    emit_json("false", "streamlink", $username, undef, $quality, $author, $title, "could not extract stream URL", $timestamp, "offline");
    exit 1;
}

if ($json_flag eq '--json') {
    emit_json("true", "streamlink", $username, $url, $quality, $author, $title, undef, $timestamp, "live");
} else {
    print "$url\n";
}
