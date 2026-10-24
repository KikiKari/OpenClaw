#!/usr/bin/perl
# websearch-research.sh — portiert nach perl5
# Quelle: shell, OpenClaw@gateway2:scripts/websearch-research.sh
# Erzeugt: 2026-10-24 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use LWP::UserAgent;
use HTTP::Request::Common;
use JSON;
use POSIX qw(strftime);

# Web Search Script: Deep Research für Incidents
# Verwendung: ./websearch-research.pl "Beschreibung des Problems"

my $query = $ARGV[0];
my $output_dir = $ARGV[1] || "./research";

if (!$query) {
    print "Verwendung: $0 \"Problem Beschreibung\" [OUTPUT_DIR]\n";
    exit 1;
}

# Erstelle das Ausgabeverzeichnis
mkdir $output_dir unless -d $output_dir;

# Erstelle den Dateinamen mit Zeitstempel
my $timestamp = strftime("%Y%m%d_%H%M%S", localtime);
my $output_file = "$output_dir/incident_$timestamp.md";

open(my $fh, '>', $output_file) or die "Kann Datei $output_file nicht öffnen: $!";

# Schreibe Header
print $fh "# Incident Research\n";
print $fh "Datum: " . strftime("%Y-%m-%d %H:%M:%S", localtime) . "\n";
print $fh "Query: $query\n\n";

# 1. EXA für schnelle Recherche
print $fh "## 1. Schnelle Recherche (EXA)\n";

my $ua = LWP::UserAgent->new;
$ua->timeout(30);

my $exa_request = POST 'https://openrouter.ai/api/v1/chat/completions',
    Content_Type => 'application/json',
    Authorization => "Bearer $ENV{OPENROUTER_API_KEY}",
    Content => encode_json({
        model => "openai/gpt-5.4-mini",
        messages => [{ role => "user", content => $query }],
        plugins => [{ id => "web", engine => "exa", max_results => 5 }]
    });

my $exa_response = $ua->request($exa_request);
my $exa_content = "Keine Ergebnisse";

if ($exa_response->is_success) {
    my $json_data = decode_json($exa_response->decoded_content);
    if (exists $json_data->{choices}[0]{message}{content}) {
        $exa_content = $json_data->{choices}[0]{message}{content};
    }
}

print $fh "$exa_content\n\n";
print $fh "---\n\n";

# 2. Verifizierte Quellen (Perplexity)
print $fh "## 2. Verifizierte Fakten (Perplexity)\n";

my $perplexity_request = POST 'https://openrouter.ai/api/v1/chat/completions',
    Content_Type => 'application/json',
    Authorization => "Bearer $ENV{OPENROUTER_API_KEY}",
    Content => encode_json({
        model => "perplexity/sonar:online",
        messages => [{ role => "user", content => "$query troubleshooting" }]
    });

my $perplexity_response = $ua->request($perplexity_request);
my $perplexity_content = "Keine Ergebnisse";

if ($perplexity_response->is_success) {
    my $json_data = decode_json($perplexity_response->decoded_content);
    if (exists $json_data->{choices}[0]{message}{content}) {
        $perplexity_content = $json_data->{choices}[0]{message}{content};
    }
}

print $fh "$perplexity_content\n\n";
close $fh;

print "Gespeichert in: $output_file\n";
