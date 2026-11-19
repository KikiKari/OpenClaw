#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "1cc4460035f7c6690a5082d91a4d343f54f1a32a0a37f9c9cb1bc142ed7cdf95", "source_sha256": "b0b2d14634c78d492d814989a9bf887ffef50ac058176565e0d55191bb8ac787", "target_language": "perl5"}
# serve_compare_transfer.sh — portiert nach perl5
# Quelle: shell, OpenClaw@gateway2:scripts/serve_compare_transfer.sh
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Find;
use File::Spec;
use Cwd 'abs_path';

my $COMPARE_DIR = "/home/openclaw/.openclaw/workspace/vscode/compare";
my $TRANSFER_DIR = "/home/openclaw/.openclaw/workspace/vscode/compare/transfer";
my $HOST_IP = "89.58.15.220";
my $PORT = "80";
my $SELF_PATH = abs_path($0);

# Finde alle Dateien im Vergleichsverzeichnis
my @files;
find(sub {
    return if -d $_;  # Überspringe Verzeichnisse
    return if $File::Find::name eq $SELF_PATH;  # Überspringe das Skript selbst
    push @files, $File::Find::name;
}, $COMPARE_DIR);

# Sortiere die Dateien
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

# Wechsle ins Vergleichsverzeichnis und starte den HTTP-Server
chdir $COMPARE_DIR or die "Konnte nicht in das Verzeichnis $COMPARE_DIR wechseln: $!";

# Starte den Python HTTP-Server
exec("python3", "-m", "http.server", $PORT, "--bind", "0.0.0.0");
