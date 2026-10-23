#!/usr/bin/perl
# tiktok-get-stream.js — portiert nach perl5
# Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live-mon/scripts/tiktok-get-stream.js
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use utf8;
use JSON qw(decode_json encode_json);
use File::Spec;
use POSIX qw(WIFEXITED WEXITSTATUS);
use Time::HiRes qw(usleep);
use Fcntl qw(:mode);

# Konstanten
my $FALLBACK_TIMEOUT_MS = 45000;
my $FALLBACK_MAX_OUTPUT = 1024 * 1024;

# Gemeinsame Funktionen einbinden (vereinfacht)
sub log_message {
    my ($message) = @_;
    print STDERR "$message\n";
}

sub normalize_username {
    my ($username) = @_;
    $username =~ s/^@//;
    if ($username !~ /^[a-zA-Z0-9._-]+$/) {
        die "Invalid username format\n";
    }
    return $username;
}

sub quality_key_from_url {
    my ($url) = @_;
    for my $suffix (qw(_origin.flv _uhd_60.flv _hd_60.flv _hd.flv _sd.flv _ld.flv)) {
        return $suffix if $url =~ /\Q$suffix\E/;
    }
    return 'unknown';
}

sub is_successful_stream_response {
    my ($status, $url) = @_;
    return $status == 200 && $url =~ /\.flv$/;
}

sub normalize_extractor_result {
    my ($data, $method, $username) = @_;
    $data->{method} //= $method;
    $data->{username} //= $username;
    $data->{success} //= 0;
    $data->{status} //= 'unknown';
    return $data;
}

sub classify_final_failure {
    my ($results) = @_;
    for my $result (@$results) {
        return $result->{status} if $result->{status} eq 'restricted' || $result->{status} eq 'overloaded';
    }
    return 'technical_error';
}

sub exit_code_for_result {
    my ($result) = @_;
    return 0 if $result->{success};
    return 1 if $result->{status} eq 'offline' || $result->{status} eq 'restricted';
    return 75 if $result->{status} eq 'overloaded';
    return 2;
}

sub enforce_load_limit {
    # Vereinfachte Implementierung
}

sub forced_offline {
    # Vereinfachte Implementierung
    return 0;
}

sub human_delay {
    my ($min, $max) = @_;
    $min //= 2000;
    $max //= 4000;
    return int(rand($max - $min + 1)) + $min;
}

# Fallback-Ausführung
sub run_fallback {
    my ($script_path, $args) = @_;
    my @cmd = ('bash', $script_path, @$args);
    my $pid = fork();
    if (!defined $pid) {
        die "fork failed: $!";
    }
    if ($pid == 0) {
        open(STDIN, '</dev/null') or die "can't redirect stdin: $!";
        open(STDOUT, '>&', \*STDOUT) or die "can't dup stdout: $!";
        open(STDERR, '>&', \*STDERR) or die "can't dup stderr: $!";
        exec(@cmd) or die "exec failed: $!";
    }

    my $stdout = '';
    my $stderr = '';
    my $overflow = 0;
    my $timed_out = 0;

    eval {
        local $SIG{ALRM} = sub { die "timeout"; };
        alarm(int($FALLBACK_TIMEOUT_MS / 1000) + 5);
        {
            my $rin = '';
            vec($rin, fileno(STDIN), 1) = 1;
            my $win = $rin;
            my $ein = $rin;
            select($rin, $win, $ein, $FALLBACK_TIMEOUT_MS / 1000);
            last unless vec($rin, fileno(STDIN), 1);
        }
        alarm(0);
    };
    if ($@ && $@ eq "timeout\n") {
        $timed_out = 1;
        kill 'TERM', $pid;
        usleep(3000000);
        kill 'KILL', $pid;
    }

    waitpid($pid, 0);
    my $exit_code = $? >> 8;

    if ($overflow) {
        return { code => 2, stdout => '', stderr => 'fallback output exceeded limit' };
    } elsif ($timed_out) {
        return { code => 2, stdout => $stdout, stderr => "${stderr}fallback timeout" };
    } else {
        chomp($stdout);
        chomp($stderr);
        return { code => $exit_code // 2, stdout => $stdout, stderr => $stderr };
    }
}

sub parse_fallback_result {
    my ($method, $username, $execution) = @_;
    for my $text ($execution->{stdout}, $execution->{stderr}) {
        next unless $text;
        eval {
            my $value = decode_json($text);
            if (ref($value) eq 'HASH') {
                return normalize_extractor_result($value, $method, $username);
            }
        };
    }
    my $message = $execution->{stderr} || "fallback exited $execution->{code}";
    return normalize_extractor_result({
        success => 0,
        status => $execution->{code} == 75 ? 'overloaded' : 'technical_error',
        method => $method,
        username => $username,
        message => $message
    }, $method, $username);
}

# Playwright Preflight
sub playwright_preflight {
    # Vereinfachte Prüfung
    my $executable = '/usr/bin/chromium-browser'; # Beispiel-Pfad
    if (-x $executable) {
        return { ok => 1, executable => $executable };
    } else {
        return {
            ok => 0,
            status => 'dependency_missing',
            error => "Playwright Chromium unavailable"
        };
    }
}

# Popup-Behandlung (simuliert)
sub handle_popups {
    # In Perl nicht direkt umsetzbar ohne entsprechende Bibliotheken
    return 1;
}

# Einschränkungsprüfung (simuliert)
sub check_restrictions {
    # In Perl nicht direkt umsetzbar ohne entsprechende Bibliotheken
    return { restricted => 0, reason => undef };
}

# Playwright-basierte Extraktion (simuliert)
sub extract_with_playwright {
    my ($username, $quality_preference) = @_;
    my $preflight = playwright_preflight();
    unless ($preflight->{ok}) {
        return {
            success => 0,
            method => 'playwright',
            status => $preflight->{status},
            error => $preflight->{error}
        };
    }

    # Simulierte FLV-URLs
    my @collected_urls = (
        { url => "https://example.com/stream_hd.flv", status => 200, timestamp => '2023-01-01T00:00:00Z' },
        { url => "https://example.com/stream_sd.flv", status => 200, timestamp => '2023-01-01T00:00:01Z' }
    );

    unless (@collected_urls) {
        return { success => 0, method => 'playwright', status => 'offline', restricted => 0, reason => 'No FLV URLs found' };
    }

    my %unique_urls;
    for my $item (@collected_urls) {
        my $base_url = (split(/\?/, $item->{url}))[0];
        $unique_urls{$base_url} = $item;
    }
    my @unique_urls = values %unique_urls;

    my %quality_order = (
        original => [qw(_origin.flv _uhd_60.flv _hd_60.flv _hd.flv _sd.flv _ld.flv)],
        '1080p60' => [qw(_uhd_60.flv _hd_60.flv _hd.flv _sd.flv _ld.flv)],
        '720p60' => [qw(_hd_60.flv _hd.flv _sd.flv _ld.flv)],
        '720p' => [qw(_hd.flv _sd.flv _ld.flv)],
        '540p' => [qw(_sd.flv _ld.flv)],
        '360p' => [qw(_ld.flv)],
        auto => [qw(_origin.flv _uhd_60.flv _hd_60.flv _hd.flv _sd.flv _ld.flv)]
    );

    my $order = $quality_order{$quality_preference} || $quality_order{auto};
    my $best_url;
    for my $suffix (@$order) {
        for my $url_item (@unique_urls) {
            if ($url_item->{url} =~ /\Q$suffix\E/) {
                $best_url = $url_item;
                last;
            }
        }
        last if $best_url;
    }
    $best_url //= $unique_urls[0] if $quality_preference eq 'auto' || $quality_preference eq 'original';

    unless ($best_url) {
        return { success => 0, method => 'playwright', status => 'quality_unavailable',
                 reason => "Requested quality $quality_preference was not captured" };
    }

    return {
        success => 1,
        status => 'live',
        method => 'playwright',
        username => $username,
        url => $best_url->{url},
        quality => $quality_preference,
        allUrls => [map { { url => $_->{url}, quality => quality_key_from_url($_->{url}) } } @unique_urls],
        allUrlsCount => scalar(@unique_urls),
        timestamp => '2023-01-01T00:00:00Z'
    };
}

# Streamlink Fallback
sub try_streamlink {
    my ($username, $quality) = @_;
    my $script_path = File::Spec->catfile(dirname(__FILE__), 'extraction-methods', 'extract-tiktok-streamlink.sh');
    my $execution = run_fallback($script_path, [$username, $quality, '--json']);
    return parse_fallback_result('streamlink', $username, $execution);
}

# yt-dlp Fallback
sub try_yt_dlp {
    my ($username, $quality) = @_;
    my $script_path = File::Spec->catfile(dirname(__FILE__), 'extraction-methods', 'extract-tiktok-yt-dlp.sh');
    my %format_map = (
        original => 'hls-origin/hls-pull/hls-uhd_60/hls-hd_60/hls-hd/hls-sd/hls-ld/flv-origin/flv-hd/flv-ld',
        '1080p60' => 'hls-uhd_60/hls-hd_60/hls-hd/hls-sd/hls-ld/flv-hd/flv-ld',
        '720p60' => 'hls-hd_60/hls-hd/hls-sd/hls-ld/flv-hd/flv-ld',
        '720p' => 'hls-hd/hls-sd/hls-ld/flv-hd/flv-sd/flv-ld',
        '540p' => 'hls-sd/hls-ld/flv-sd/flv-ld',
        '360p' => 'hls-ld/flv-ld',
        auto => 'hls-origin/hls-hd/hls-sd/hls-ld/hls-pull/flv-origin/flv-hd/flv-ld'
    );
    my $yt_format = $format_map{$quality} || $format_map{auto};
    my $execution = run_fallback($script_path, [$username, $yt_format, '--json']);
    return parse_fallback_result('yt-dlp', $username, $execution);
}

# Hauptfunktion
sub get_stream_url {
    my ($username, $quality_preference) = @_;
    $quality_preference //= 'auto';
    my $timestamp = '2023-01-01T00:00:00Z';

    log_message("[1/3] Trying Playwright for \@$username...");
    my $pw_result = extract_with_playwright($username, $quality_preference);
    $pw_result->{timestamp} = $timestamp;
    if ($pw_result->{success}) {
        return $pw_result;
    }
    if ($pw_result->{status} eq 'restricted' || $pw_result->{status} eq 'overloaded') {
        return $pw_result;
    }
    log_message("Playwright result: " . ($pw_result->{reason} || $pw_result->{error} || 'failed'));

    log_message("[2/3] Trying streamlink for \@$username (quality: $quality_preference)...");
    my $sl_result = try_streamlink($username, $quality_preference);
    if ($sl_result->{success}) {
        return $sl_result;
    }
    if ($sl_result->{status} eq 'restricted' || $sl_result->{status} eq 'overloaded') {
        return $sl_result;
    }
    log_message("Streamlink result: " . ($sl_result->{message} || $sl_result->{error} || 'failed'));

    log_message("[3/3] Trying yt-dlp for \@$username...");
    my $yt_result = try_yt_dlp($username, $quality_preference);
    if ($yt_result->{success}) {
        return $yt_result;
    }
    if ($yt_result->{status} eq 'restricted' || $yt_result->{status} eq 'overloaded') {
        return $yt_result;
    }
    log_message("yt-dlp result: " . ($yt_result->{message} || $yt_result->{error} || 'failed'));

    my $status = classify_final_failure([$pw_result, $sl_result, $yt_result]);
    return {
        success => 0,
        status => $status,
        username => $username,
        message => 'All extraction methods failed (Playwright, streamlink, yt-dlp).',
        playwrightReason => $pw_result->{reason} || $pw_result->{error},
        streamlinkReason => $sl_result->{message} || $sl_result->{error},
        ytdlpReason => $yt_result->{message} || $yt_result->{error},
        timestamp => $timestamp
    };
}

# CLI
if (@ARGV < 1) {
    print STDERR "Usage: perl tiktok-get-stream.pl <username> [quality: original|1080p60|720p60|720p|540p|360p|auto] [--json]\n";
    exit 1;
}

my $cli_username;
eval {
    $cli_username = normalize_username($ARGV[0]);
};
if ($@) {
    print STDERR $@;
    exit 64;
}

enforce_load_limit('playwright_streamlink_ytdlp');
if (forced_offline('playwright_streamlink_ytdlp', $cli_username)) {
    exit 1;
}

my $cli_quality = 'auto';
my $cli_json = 0;
for my $arg (@ARGV[1..$#ARGV]) {
    if ($arg eq '--json') {
        $cli_json = 1;
    } elsif (!$cli_quality || $arg !~ /^--/) {
        $cli_quality = $arg if !$cli_quality;
    }
}

unless (grep { $_ eq $cli_quality } qw(original 1080p60 720p60 720p 540p 360p auto)) {
    print STDERR "Invalid quality; expected original, 1080p60, 720p60, 720p, 540p, 360p, or auto\n";
    exit 64;
}

my $result = get_stream_url($cli_username, $cli_quality);
if ($cli_json) {
    print encode_json($result) . "\n";
} else {
    if ($result->{success}) {
        print "$result->{url}\n";
    } else {
        print STDERR "$result->{message}\n";
    }
}
exit exit_code_for_result($result);
