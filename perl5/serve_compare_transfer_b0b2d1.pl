#!/usr/bin/env perl
# serve_compare_transfer.sh — portiert nach perl5
# Quelle: shell, OpenClaw@gateway2:scripts/serve_compare_transfer.sh
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Find;
use File::Spec;
use Cwd 'abs_path';
use HTTP::Daemon;
use HTTP::Status qw(RC_OK RC_NOT_FOUND);
use URI::Escape qw(uri_unescape);

my $COMPARE_DIR = "/home/openclaw/.openclaw/workspace/vscode/compare";
my $TRANSFER_DIR = "/home/openclaw/.openclaw/workspace/vscode/compare/transfer";
my $HOST_IP = "89.58.15.220";
my $PORT = "80";
my $SELF_PATH = abs_path($0);

# Sammle alle Dateien im Compare-Verzeichnis außer dem Skript selbst
my @files;
opendir(my $dir, $COMPARE_DIR) or die "Kann Verzeichnis $COMPARE_DIR nicht öffnen: $!";
while (readdir($dir)) {
    my $file = File::Spec->catfile($COMPARE_DIR, $_);
    next if ($_ eq '.' || $_ eq '..');
    next if ($file eq $SELF_PATH);
    if (-f $file) {
        push @files, $file;
    }
}
closedir($dir);

# Sortiere die Dateien alphabetisch
@files = sort @files;

if (@files == 0) {
    print "Keine Dateien in ${COMPARE_DIR} gefunden.\n";
    exit 1;
}

print "\n";
print "Bereitgestellte Dateien aus ${COMPARE_DIR}:\n";
for my $src (@files) {
    my ($volume, $directories, $file) = File::Spec->splitpath($src);
    print "- $file\n";
}

print "\n";
print "Copy/Paste auf anderem Gateway (Download nach ${TRANSFER_DIR}):\n";
for my $src (@files) {
    my ($volume, $directories, $file) = File::Spec->splitpath($src);
    print "curl -fL --retry 3 --connect-timeout 10 -o ${TRANSFER_DIR}/${file} http://${HOST_IP}:${PORT}/${file}\n";
}

print "\n";
print "Server auf Port ${PORT} aktiv. Beenden mit STRG+C.\n";
print "\n";

# Starte HTTP-Server
my $d = HTTP::Daemon->new(
    LocalAddr => '0.0.0.0',
    LocalPort => $PORT,
    ReuseAddr => 1,
) or die "Kann keinen Server auf Port $PORT starten: $!";

print "HTTP-Server läuft auf Port " . $d->sockport() . "\n";

while (my $c = $d->accept()) {
    while (my $request = $c->get_request()) {
        my $path = uri_unescape($request->uri()->path());
        $path =~ s/^\/+//; # Entferne führende Schrägstriche
        
        my $full_path = File::Spec->catfile($COMPARE_DIR, $path);
        
        # Sicherheitscheck: Stelle sicher, dass die angeforderte Datei im Compare-Verzeichnis liegt
        my $abs_full_path = abs_path($full_path);
        my $abs_compare_dir = abs_path($COMPARE_DIR);
        
        if ($abs_full_path && index($abs_full_path, $abs_compare_dir) == 0 && -f $full_path) {
            open(my $fh, '<', $full_path) or do {
                $c->send_error(RC_NOT_FOUND);
                next;
            };
            
            my $response = HTTP::Response->new(RC_OK);
            $response->content_type("application/octet-stream");
            $response->header('Content-Disposition' => "attachment; filename=\"$path\"");
            
            # Lese Dateiinhalt
            local $/;
            my $content = <$fh>;
            close($fh);
            
            $response->content($content);
            $c->send_response($response);
        } else {
            $c->send_error(RC_NOT_FOUND);
        }
    }
    $c->close();
    undef($c);
}
