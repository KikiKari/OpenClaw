#!/usr/bin/perl
# extract-tiktok-yt-dlp.sh — portiert nach perl5
# Quelle: shell, OpenClaw@gateway2:skills/tiktok-live-mon/scripts/extraction-methods/extract-tiktok-yt-dlp.sh
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use JSON;
use File::Temp qw(tempdir);
use POSIX qw(strftime);

# Bounded fallback used by the enhanced extractor. Temporary files are cleaned
# on every exit and output is normalized again by tiktok-get-stream.js.
# Standalone overload exits 75 before yt-dlp starts.

my $USERNAME = $ARGV[0] // '';
$USERNAME =~ s/^@//;
my $FORMAT = $ARGV[1] // 'best';
my $JSON_FLAG = $ARGV[2] // '';
my $TIMESTAMP = strftime('%Y-%m-%dT%H:%M:%SZ', gmtime());
my $TMP_DIR = tempdir('/tmp/tiktok-yt-dlp.XXXXXX', CLEANUP => 1);

sub emit_json {
    my (%payload) = @_;
    delete $payload{$_} for grep { !$payload{$_} } keys %payload;
    if (exists $payload{success}) {
        $payload{success} = lc($payload{success}) eq 'true';
    }
    print STDERR encode_json(\%payload) . "\n";
}

if ($USERNAME !~ /^[A-Za-z0-9._]{1,24}$/) {
    print STDERR "Invalid TikTok username\n";
    exit 64;
}

my %valid_formats = map { $_ => 1 } (
    'hls-origin/hls-pull/hls-uhd_60/hls-hd_60/hls-hd/hls-sd/hls-ld/flv-origin/flv-hd/flv-ld',
    'hls-uhd_60/hls-hd_60/hls-hd/hls-sd/hls-ld/flv-hd/flv-ld',
    'hls-hd_60/hls-hd/hls-sd/hls-ld/flv-hd/flv-ld',
    'hls-hd/hls-sd/hls-ld/flv-hd/flv-sd/flv-ld',
    'hls-sd/hls-ld/flv-sd/flv-ld',
    'hls-ld/flv-ld',
    'hls-origin/hls-hd/hls-sd/hls-ld/hls-pull/flv-origin/flv-hd/flv-ld'
);

unless (exists $valid_formats{$FORMAT}) {
    print STDERR "Invalid yt-dlp format\n";
    exit 64;
}

open(my $fh, '-|', 'python3', '-c', 'import os; print(os.getloadavg()[0] / max(1, os.cpu_count() or 1))') or die $!;
my $LOAD_PER_CPU = <$fh>;
chomp $LOAD_PER_CPU;
close $fh;

my $MAX_LOAD = $ENV{'TIKTOK_MAX_LOAD_PER_CPU'} // '1.5';

open(my $fh2, '-|', 'python3', '-c', 'import sys; sys.exit(0 if float(sys.argv[1]) > float(sys.argv[2]) else 1)', $LOAD_PER_CPU, $MAX_LOAD) or die $!;
my $overload_exit = close($fh2) ? 1 : 0;

if (!$overload_exit) {
    emit_json(
        success => 'false',
        method => 'yt-dlp',
        username => $USERNAME,
        url => '',
        format => $FORMAT,
        error => 'host overloaded',
        timestamp => $TIMESTAMP,
        status => 'overloaded'
    );
    exit 75;
}

unless (`which yt-dlp`) {
    emit_json(
        success => 'false',
        method => 'yt-dlp',
        username => $USERNAME,
        url => '',
        format => $FORMAT,
        error => 'yt-dlp not installed',
        timestamp => $TIMESTAMP,
        status => 'dependency_missing'
    );
    exit 2;
}

my $LIVE_URL = "https://www.tiktok.com/\@$USERNAME/live";
my $stdout_file = "$TMP_DIR/stdout.json";
my $stderr_file = "$TMP_DIR/stderr.log";

system("yt-dlp --no-warnings --dump-single-json --skip-download --format '$FORMAT' '$LIVE_URL' >'$stdout_file' 2>'$stderr_file'");
my $EXIT_CODE = $? >> 8;

if ($EXIT_CODE != 0) {
    open(my $fh, '<', $stderr_file) or die "Cannot open $stderr_file: $!";
    my $stderr_content = do { local $/; <$fh> };
    close $fh;
    
    my $STATUS = 'technical_error';
    my $CODE = 2;
    
    if ($stderr_content =~ /not currently live|No live cdn found|not available|private video/i) {
        $STATUS = 'offline';
        $CODE = 1;
    }
    
    substr($stderr_content, 1000) = '' if length($stderr_content) > 1000;
    
    emit_json(
        success => 'false',
        method => 'yt-dlp',
        username => $USERNAME,
        url => '',
        format => $FORMAT,
        error => $stderr_content,
        timestamp => $TIMESTAMP,
        status => $STATUS
    );
    exit $CODE;
}

open(my $fh3, '<', $stdout_file) or die "Cannot open $stdout_file: $!";
my $json_text = do { local $/; <$fh3> };
close $fh3;

my $data = decode_json($json_text);
my @candidates;

if (defined $data->{url} && !ref($data->{url})) {
    push @candidates, $data->{url};
}

if (ref($data->{formats}) eq 'ARRAY') {
    for my $item (@{$data->{formats}}) {
        if (ref($item) eq 'HASH' && defined $item->{url} && !ref($item->{url})) {
            push @candidates, $item->{url};
        }
    }
}

my $URL = '';
for my $value (@candidates) {
    my $low = lc($value);
    if ($value =~ /^https:\/\// && ($low =~ /\.m3u8/ || $low =~ /\.flv/) && $low !~ /only_audio=1/) {
        $URL = $value;
        last;
    }
}

if (!$URL) {
    emit_json(
        success => 'false',
        method => 'yt-dlp',
        username => $USERNAME,
        url => '',
        format => $FORMAT,
        error => 'could not extract HTTPS video URL',
        timestamp => $TIMESTAMP,
        status => 'offline'
    );
    exit 1;
}

if ($JSON_FLAG eq '--json') {
    emit_json(
        success => 'true',
        method => 'yt-dlp',
        username => $USERNAME,
        url => $URL,
        format => $FORMAT,
        error => '',
        timestamp => $TIMESTAMP,
        status => 'live'
    );
} else {
    print "$URL\n";
}
