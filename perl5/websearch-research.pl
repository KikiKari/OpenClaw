#!/usr/bin/perl
# websearch-research.sh — portiert nach perl5
# Quelle: shell, OpenClaw@gateway1:scripts/websearch-research.sh
# Erzeugt: 2026-10-24 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use LWP::UserAgent;
use HTTP::Request::Common;
use JSON;
use POSIX qw(strftime);

# Web Search Script: Deep Research fuer Incidents
# Verwendung: ./websearch-research.pl "Beschreibung des Problems"

my $query = $ARGV[0];
my $output_dir = $ARGV[1] // "./research";

if (!$query) {
    print "Verwendung: $0 \"Problem Beschreibung\" [OUTPUT_DIR]\n";
    exit 1;
}

# Erstelle das Ausgabeverzeichnis falls es nicht existiert
mkdir $output_dir unless -d $output_dir;

# Erstelle den Dateinamen mit Zeitstempel
my $timestamp = strftime "%Y%m%d_%H%M%S", localtime;
my $output_file = "$output_dir/incident_$timestamp.md";

# Oeffne die Ausgabedatei zum Schreiben
open(my $fh, '>', $output_file) or die "Kann Datei '$output_file' nicht oeffnen: $!";

print $fh "# Incident Research\n";
print $fh "Datum: " . strftime("%Y-%m-%d %H:%M:%S", localtime) . "\n";
print $fh "Query: $query\n\n";

# 1. EXA fuer schnelle Recherche
print $fh "## 1. Schnelle Recherche (EXA)\n";

my $ua = LWP::UserAgent->new;
$ua->timeout(30);

my $api_key = $ENV{'OPENROUTER_API_KEY'};
if (!$api_key) {
    die "OPENROUTER_API_KEY Umgebungsvariable muss gesetzt sein\n";
}

my $data_exa = {
    model => "openai/gpt-5.6-terra",
    messages => [{ role => "user", content => $query }],
    plugins => [{ id => "web", engine => "exa", max_results => 5 }]
};

my $req_exa = POST "https://openrouter.ai/api/v1/chat/completions",
    Content_Type => 'application/json',
    Authorization => "Bearer $api_key",
    Content => encode_json($data_exa);

my $res_exa = $ua->request($req_exa);

if ($res_exa->is_success) {
    my $json_data = decode_json($res_exa->decoded_content);
    my $content = $json_data->{choices}[0]{message}{content} // "Keine Ergebnisse";
    print $fh "$content\n\n";
} else {
    print $fh "Fehler bei der Anfrage: " . $res_exa->status_line . "\n\n";
}

print $fh "---\n\n";

# 2. Verifizierte Quellen (Perplexity)
print $fh "## 2. Verifizierte Fakten (Perplexity)\n";

my $data_perplexity = {
    model => "perplexity/sonar:online",
    messages => [{ role => "user", content => "$query troubleshooting" }]
};

my $req_perplexity = POST "https://openrouter.ai/api/v1/chat/completions",
    Content_Type => 'application/json',
    Authorization => "Bearer $api_key",
    Content => encode_json($data_perplexity);

my $res_perplexity = $ua->request($req_perplexity);

if ($res_perplexity->is_success) {
    my $json_data = decode_json($res_perplexity->decoded_content);
    my $content = $json_data->{choices}[0]{message}{content} // "Keine Ergebnisse";
    print $fh "$content\n\n";
} else {
    print $fh "Fehler bei der Anfrage: " . $res_perplexity->status_line . "\n\n";
}

close $fh;

print "Gespeichert in: $output_file\n";
