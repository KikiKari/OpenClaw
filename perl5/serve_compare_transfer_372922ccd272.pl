#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "723cbdf2bbb95aaaf459e306b1d80a4830f014ba86d1d014438cd804893105c8", "source_sha256": "d5eb18db536b690023fd61c3dfa4d99f899ec602247f48fb044c53baebb78556", "target_language": "perl5"}
# serve_compare_transfer.sh — portiert nach perl5
# Quelle: shell, OpenClaw@gateway1:scripts/serve_compare_transfer.sh
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Find;
use File::Spec;
use Cwd 'abs_path';
use File::Basename;

my $COMPARE_DIR = "/home/openclaw/.openclaw/workspace/vscode/compare";
my $TRANSFER_DIR = "/home/openclaw/.openclaw/workspace/vscode/compare/transfer";
my $HOST_IP = "152.53.145.65";
my $PORT = "80";
my $SELF_PATH = abs_path($0);

# Sammle Dateien im Compare-Verzeichnis (maximale Tiefe 1, keine Unterverzeichnisse)
my @FILES;
opendir(my $dh, $COMPARE_DIR) or die "Kann Verzeichnis $COMPARE_DIR nicht öffnen: $!";
while (readdir $dh) {
    my $file = $_;
    next if $file =~ /^\.\.?$/; # Überspringe . und ..
    my $full_path = File::Spec->catfile($COMPARE_DIR, $file);
    # Nur reguläre Dateien, aber nicht dieses Skript selbst
    if (-f $full_path && $full_path ne $SELF_PATH) {
        push @FILES, $full_path;
    }
}
closedir $dh;

# Sortiere die Dateien alphabetisch
@FILES = sort @FILES;

if (@FILES == 0) {
    print "Keine Dateien in ${COMPARE_DIR} gefunden.\n";
    exit 1;
}

print "\n";
print "Bereitgestellte Dateien aus ${COMPARE_DIR}:\n";
for my $src (@FILES) {
    my $basename = basename($src);
    print "- $basename\n";
}

print "\n";
print "Copy/Paste auf anderem Gateway (Download nach ${TRANSFER_DIR}):\n";
for my $src (@FILES) {
    my $file = basename($src);
    print "curl -fL --retry 3 --connect-timeout 10 -o ${TRANSFER_DIR}/${file} http://${HOST_IP}:${PORT}/${file}\n";
}

print "\n";
print "Server auf Port ${PORT} aktiv. Beenden mit STRG+C.\n";
print "\n";

# Wechsle ins Compare-Verzeichnis und starte den HTTP-Server
chdir($COMPARE_DIR) or die "Kann nicht in Verzeichnis $COMPARE_DIR wechseln: $!";

# Starte den Python HTTP-Server wie im Original
exec("python3", "-m", "http.server", $PORT, "--bind", "0.0.0.0");
