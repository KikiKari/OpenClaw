#!/usr/bin/perl
# serve_compare_transfer.sh — portiert nach perl5
# Quelle: shell, OpenClaw@gateway1:scripts/serve_compare_transfer.sh
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Find;
use File::Basename;
use Cwd 'abs_path';
use HTTP::Daemon;
use HTTP::Status;
use URI::Escape;

# Konfiguration
my $COMPARE_DIR = "/home/openclaw/.openclaw/workspace/vscode/compare";
my $TRANSFER_DIR = "/home/openclaw/.openclaw/workspace/vscode/compare/transfer";
my $HOST_IP = "152.53.145.65";
my $PORT = "80";

# Eigenen Pfad ermitteln
my $SELF_PATH = abs_path($0);

# Sammle alle Dateien im Compare-Verzeichnis (ohne Unterverzeichnisse)
my @files;
opendir(my $dir, $COMPARE_DIR) or die "Kann Verzeichnis $COMPARE_DIR nicht öffnen: $!";
while (readdir $dir) {
    my $file = "$COMPARE_DIR/$_";
    # Überspringe eigene Datei und nur reguläre Dateien berücksichtigen
    if (-f $file && $file ne $SELF_PATH) {
        push @files, $file;
    }
}
closedir $dir;

# Sortiere die Dateien alphabetisch
@files = sort @files;

if (@files == 0) {
    print "Keine Dateien in $COMPARE_DIR gefunden.\n";
    exit 1;
}

print "\n";
print "Bereitgestellte Dateien aus $COMPARE_DIR:\n";
for my $src (@files) {
    my $basename = basename($src);
    print "- $basename\n";
}

print "\n";
print "Copy/Paste auf anderem Gateway (Download nach $TRANSFER_DIR):\n";
for my $src (@files) {
    my $file = basename($src);
    print "curl -fL --retry 3 --connect-timeout 10 -o $TRANSFER_DIR/$file http://$HOST_IP:$PORT/$file\n";
}

print "\n";
print "Server auf Port $PORT aktiv. Beenden mit STRG+C.\n";
print "\n";

# Starte HTTP-Server
chdir($COMPARE_DIR) or die "Kann nicht in Verzeichnis $COMPARE_DIR wechseln: $!";

my $d = HTTP::Daemon->new(
    LocalAddr => '0.0.0.0',
    LocalPort => $PORT,
    ReuseAddr => 1,
) or die "Kann keinen HTTP-Daemon starten: $!";

print "Server läuft auf ", $d->url, "\n";

while (my $c = $d->accept) {
    while (my $r = $c->get_request) {
        if ($r->method eq 'GET') {
            my $file = uri_unescape($r->uri->path);
            $file =~ s|^/||;  # Entferne führenden Slash
            
            my $full_path = "$COMPARE_DIR/$file";
            
            if (-f $full_path) {
                open(my $fh, '<', $full_path) or do {
                    $c->send_error(RC_FORBIDDEN);
                    next;
                };
                
                my $content_type = 'application/octet-stream';
                if ($full_path =~ /\.txt$/i) {
                    $content_type = 'text/plain';
                } elsif ($full_path =~ /\.(html|htm)$/i) {
                    $content_type = 'text/html';
                } elsif ($full_path =~ /\.css$/i) {
                    $content_type = 'text/css';
                } elsif ($full_path =~ /\.(js)$/i) {
                    $content_type = 'application/javascript';
                } elsif ($full_path =~ /\.(json)$/i) {
                    $content_type = 'application/json';
                } elsif ($full_path =~ /\.(xml)$/i) {
                    $content_type = 'application/xml';
                }
                
                my $response = HTTP::Response->new(200);
                $response->header('Content-Type' => $content_type);
                
                # Lies die Datei binär
                local $/;
                my $content = <$fh>;
                close $fh;
                
                $response->content($content);
                $c->send_response($response);
            } else {
                $c->send_error(RC_NOT_FOUND);
            }
        } else {
            $c->send_error(RC_FORBIDDEN);
        }
    }
    $c->close;
    undef($c);
}
