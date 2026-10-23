#!/usr/bin/perl
# verify-downloads.py — portiert nach perl5
# Quelle: python, Projects@TikTok-Live-Companion:site/scripts/verify-downloads.py
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:site/scripts/verify-downloads.py
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use Getopt::Long;
use Digest::SHA qw(sha256_hex);
use JSON;
use File::Spec;
use File::Basename;
use Cwd qw(abs_path);
use HTTP::Tiny;
use Archive::Zip;

# Verify the candidate's actual HTTP downloads against committed files.

my $base_url;
my $report;
GetOptions(
    'base-url=s' => \$base_url,
    'report=s'   => \$report,
) or die "Error in command line arguments\n";

die "--base-url is required\n" unless defined $base_url;
die "--report is required\n" unless defined $report;

# Determine root directory (parent of script's directory)
my $script_dir = dirname(abs_path($0));
my $root = dirname($script_dir);

my $checksum_file = File::Spec->catfile($root, 'public', 'downloads', 'tiktok-live-companion-0.8.2-SHA256.txt');
open my $fh, '<:encoding(UTF-8)', $checksum_file or die "Cannot open $checksum_file: $!\n";
my @lines = <$fh>;
close $fh;

my @results;
my $http = HTTP::Tiny->new(timeout => 30);

for my $line (@lines) {
    chomp $line;
    next unless $line =~ /\S/;
    my ($expected, $name) = split /\s{2,}/, $line, 2;
    my $url = $base_url;
    $url =~ s|/+$||; # remove trailing slashes
    $url .= '/downloads/' . $name;

    my $response = $http->get($url);
    die "Failed to fetch $url: " . $response->{status} . " " . $response->{reason} . "\n"
        unless $response->{success};

    my $data = $response->{content};
    my $actual = sha256_hex($data);

    if ($actual ne $expected) {
        die "HTTP artifact SHA256 mismatch: $name\n";
    }

    my $local_file = File::Spec->catfile($root, 'public', 'downloads', $name);
    open my $lfh, '<:raw', $local_file or die "Cannot open local file $local_file: $!\n";
    my $local_data;
    {
        local $/;
        $local_data = <$lfh>;
    }
    close $lfh;

    if ($data ne $local_data) {
        die "HTTP artifact content mismatch: $name\n";
    }

    # Check ZIP integrity
    my $zip_data = $data;
    my $zip = Archive::Zip->new();
    my $status = $zip->readFromString(\$zip_data);
    die "Cannot read ZIP from string: $status\n" if $status != AZ_OK;

    # Test ZIP integrity by trying to extract all members
    my $corrupt = 0;
    for my $member ($zip->members()) {
        my $test_status = $member->desiredCompressionLevel();
        if (!defined $test_status) {
            $corrupt = 1;
            last;
        }
    }
    die "Corrupt archive: $name\n" if $corrupt;

    if ($name =~ /-extension-/) {
        # Check manifest.json version
        my $manifest_member = $zip->memberNamed('manifest.json');
        die "manifest.json not found in archive: $name\n" unless $manifest_member;
        
        my $manifest_content = $manifest_member->contents();
        die "Cannot extract manifest.json from archive: $name\n" unless defined $manifest_content;
        
        my $manifest = decode_json($manifest_content);
        if ($manifest->{version} ne '0.8.2') {
            die "Wrong extension version in manifest.json: " . $manifest->{version} . "\n";
        }

        # Check source files
        for my $source (qw(background.js content.js sidepanel.js sidepanel.html)) {
            my $source_member = $zip->memberNamed($source);
            die "$source not found in archive: $name\n" unless $source_member;
            
            my $source_content = $source_member->contents();
            die "Cannot extract $source from archive: $name\n" unless defined $source_content;
            
            my $source_file = File::Spec->catfile(dirname($root), 'plugin-source', 'browser-extension', $source);
            open my $sfh, '<:raw', $source_file or die "Cannot open source file $source_file: $!\n";
            my $expected_source;
            {
                local $/;
                $expected_source = <$sfh>;
            }
            close $sfh;
            
            if ($source_content ne $expected_source) {
                die "Extension source mismatch: $source\n";
            }
        }
    }

    push @results, {
        name     => $name,
        sha256   => $actual,
        bytes    => length($data),
        verified => JSON::true,
    };
}

my $output = {
    base_url  => $base_url,
    artifacts => \@results,
};

open my $rfh, '>:encoding(UTF-8)', $report or die "Cannot write to report file $report: $!\n";
print $rfh encode_json($output) . "\n";
close $rfh;

print encode_json(\@results) . "\n";
