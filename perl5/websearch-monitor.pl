#!/usr/bin/perl
# websearch-monitor.sh — portiert nach perl5
# Quelle: shell, OpenClaw@gateway1:scripts/websearch-monitor.sh
# auch in: OpenClaw@gateway2:scripts/websearch-monitor.sh
# Erzeugt: 2026-10-24 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use JSON;
use LWP::UserAgent;
use HTTP::Request;

# Web Search Script: Server-Monitoring mit Tavily
# Verwendung: ./websearch-monitor.pl [TOPIC]

my $topic = $ARGV[0] // "Linux kernel security updates";

# Security-News prüfen
print "Prüfe: $topic\n";

# Versuche zuerst Tavily CLI
if (which("tvly")) {
    my $command = "tvly search \"$topic\" --topic news --time-range week --max-results 5 --include-answer advanced 2>/dev/null";
    my $output = `$command`;
    if ($output) {
        eval {
            my $json = decode_json($output);
            print $json->{answer} // "Keine Zusammenfassung verfügbar";
            print "\n";
        };
        if ($@) {
            print "Keine Zusammenfassung verfügbar\n";
        }
    } else {
        print "Keine Ergebnisse von Tavily\n";
    }
} else {
    # Fallback zu einfacher Web-Suche
    my $ua = LWP::UserAgent->new;
    my $query = $topic;
    $query =~ s/ /+/g;
    my $url = "http://localhost:8888/search?q=$query&format=json";
    
    my $req = HTTP::Request->new(GET => $url);
    my $res = $ua->request($req);
    
    if ($res->is_success) {
        my $content = $res->decoded_content;
        eval {
            my $json = decode_json($content);
            my @results = @{$json->{results}};
            for my $i (0..2) {
                last if $i >= @results;
                print $results[$i]{title} . "\n";
                print $results[$i]{url} . "\n";
            }
        };
        if ($@) {
            print "SearXNG nicht verfügbar\n";
        }
    } else {
        print "SearXNG nicht verfügbar\n";
    }
}

sub which {
    my $command = shift;
    my @paths = split(':', $ENV{PATH});
    foreach my $path (@paths) {
        return 1 if -x "$path/$command";
    }
    return 0;
}
