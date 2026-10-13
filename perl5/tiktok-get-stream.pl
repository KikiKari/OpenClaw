#!/usr/bin/perl
# tiktok-get-stream.js — portiert nach perl5
# Quelle: javascript, OpenClaw@gateway1:skills/tiktok-live/scripts/tiktok-get-stream.js
# Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use utf8;
use JSON;
use File::Spec;
use Config;
use POSIX qw(uname);

# TikTok Stream URL Extractor
# Führt zuerst den profilgebundenen Status-Checker aus.
# Nur bei bestätigtem Live-Status werden FLV-Netzwerk-URLs erfasst.
# Offline wird keine Stream-URL ausgegeben.

my $rawUsername = $ARGV[0];
if (!$rawUsername) {
    print STDERR "Usage: perl tiktok-get-stream.pl <username>\n";
    exit 1;
}
my $username = $rawUsername;
$username =~ s/^@+//;
if (!$username) {
    print STDERR "Username must not be empty\n";
    exit 1;
}

sub reject_busy_node {
    my $limit = $ENV{'TIKTOK_MAX_LOAD_PER_CPU'};
    if (!defined($limit) || !looks_like_number($limit) || $limit <= 0) {
        return;
    }

    my $cpu_count = get_cpu_count();
    $cpu_count = ($cpu_count > 1) ? $cpu_count : 1;
    my $normalized_load = get_normalized_load($cpu_count);
    if ($normalized_load > $limit) {
        my $formatted_load = sprintf("%.2f", $normalized_load);
        print STDERR "NODE_BUSY normalizedLoad=$formatted_load limit=$limit\n";
        exit 75;
    }
}

sub get_cpu_count {
    if ($^O eq 'linux' || $^O eq 'darwin') {
        open(my $fh, '<', '/proc/cpuinfo') and do {
            my $count = grep { /processor\s+:/ } <$fh>;
            close($fh);
            return $count if $count > 0;
        };
    }
    return 1;
}

sub get_normalized_load {
    my ($cpu_count) = @_;
    if ($^O eq 'linux' || $^O eq 'darwin') {
        open(my $fh, '<', '/proc/loadavg') and do {
            my $line = <$fh>;
            close($fh);
            if ($line && $line =~ /^([\d.]+)/) {
                return $1 / $cpu_count;
            }
        };
    }
    return 0;
}

sub looks_like_number {
    my $value = shift;
    return defined($value) && $value =~ /^[+-]?\d+\.?\d*$/;
}

reject_busy_node();

sub verify_live_status {
    my ($username) = @_;
    my $script_dir = dirname($0);
    my $checker_path = File::Spec->catfile($script_dir, 'tiktok-check-profile.pl');
    if (!-f $checker_path) {
        $checker_path = File::Spec->catfile($script_dir, 'tiktok-check-profile.js');
    }
    
    my @cmd = ($^X, $checker_path, $username);
    local $ENV{PATH} = $ENV{PATH};
    
    my $pid = open(my $pipe, '-|', @cmd) or die "Cannot fork: $!";
    my $output = do { local $/; <$pipe> };
    close($pipe);
    my $exit_code = $? >> 8;
    
    if ($exit_code == 0 && $output) {
        eval {
            my $result = decode_json($output);
            return $result->{isLive} // 0;
        };
    } elsif ($output) {
        eval {
            my $result = decode_json($output);
            return $result->{isLive} // 0;
        };
    }
    return 0;
}

sub dirname {
    my ($path) = @_;
    $path =~ s/[^\/]+$//;
    $path =~ s/\/$//;
    return '.' if !$path;
    return $path;
}

sub get_stream_url {
    my ($username) = @_;
    
    if (!verify_live_status($username)) {
        my $error_data = {
            username => $username,
            isLive => JSON::false,
            error => 'User is not currently live.',
            timestamp => get_iso_timestamp()
        };
        print STDERR encode_json($error_data) . "\n";
        return 0;
    }
    
    # Da Perl keine direkte Browser-Automatisierung wie Playwright bietet,
    # verwenden wir einen Workaround mit curl und regex-Parsing
    
    my $live_url = "https://www.tiktok.com/\@$username/live";
    my $temp_file = "/tmp/tiktok_page_$$.html";
    
    my @curl_cmd = (
        'curl', '-s', '--max-time', '60',
        '-H', 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        '-H', 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        '-H', 'Accept-Language: en-US,en;q=0.5',
        '-H', 'Accept-Encoding: gzip, deflate',
        '-H', 'Connection: keep-alive',
        $live_url
    );
    
    system(@curl_cmd . " > $temp_file") == 0 or do {
        unlink($temp_file) if -f $temp_file;
        my $error_data = {
            error => JSON::true,
            message => 'Failed to fetch TikTok live page',
            timestamp => get_iso_timestamp()
        };
        print STDERR encode_json($error_data) . "\n";
        return 0;
    };
    
    open(my $fh, '<', $temp_file) or do {
        unlink($temp_file);
        my $error_data = {
            error => JSON::true,
            message => 'Failed to read fetched page',
            timestamp => get_iso_timestamp()
        };
        print STDERR encode_json($error_data) . "\n";
        return 0;
    };
    
    my $content = do { local $/; <$fh> };
    close($fh);
    unlink($temp_file);
    
    # Extrahiere potenzielle FLV URLs mit Regex
    my @flv_urls;
    while ($content =~ m/(https?:\/\/[^\s"<>]*?\.flv[^\s"<>]*)/gi) {
        push @flv_urls, {
            url => $1,
            type => 'media',
            timestamp => get_iso_timestamp()
        };
    }
    while ($content =~ m/(https?:\/\/[^\s"<>]*?pull-flv[^\s"<>]*)/gi) {
        push @flv_urls, {
            url => $1,
            type => 'media',
            timestamp => get_iso_timestamp()
        } unless grep { $_->{url} eq $1 } @flv_urls;
    }
    
    if (@flv_urls > 0) {
        # Entferne Duplikate
        my %seen;
        my @unique_urls = grep { !$seen{$_->{url}}++ } @flv_urls;
        
        # Sortiere nach Qualität
        @unique_urls = sort {
            get_quality($b->{url}) <=> get_quality($a->{url})
        } @unique_urls;
        
        my $result = {
            username => $username,
            isLive => JSON::true,
            streamCount => scalar(@unique_urls),
            streams => \@unique_urls,
            vlcCommand => "vlc \"$unique_urls[0]->{url}\"",
            timestamp => get_iso_timestamp()
        };
        print encode_json($result) . "\n";
        return 1;
    } else {
        my $error_data = {
            username => $username,
            isLive => JSON::false,
            error => 'No stream URLs found - user may not be live',
            timestamp => get_iso_timestamp()
        };
        print STDERR encode_json($error_data) . "\n";
        return 0;
    }
}

sub get_iso_timestamp {
    my ($sec,$min,$hour,$mday,$mon,$year) = gmtime();
    return sprintf("%04d-%02d-%02dT%02d:%02d:%02dZ", $year+1900, $mon+1, $mday, $hour, $min, $sec);
}

sub get_quality {
    my ($url) = @_;
    my @suffix_ranks = (
        ['_origin.', 600],
        ['_uhd_60.', 550],
        ['_uhd.', 540],
        ['_hd_60.', 500],
        ['_hd.', 450],
        ['_sd.', 350],
        ['_ld.', 250]
    );
    
    for my $rank (@suffix_ranks) {
        my ($suffix, $value) = @$rank;
        return $value if index($url, $suffix) != -1;
    }
    
    if ($url =~ /(\d+)p/) {
        return int($1);
    }
    
    return 0;
}

my $success = get_stream_url($username);
exit($success ? 0 : 1);
