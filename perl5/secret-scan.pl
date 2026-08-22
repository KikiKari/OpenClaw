#!/usr/bin/perl
# secret-scan.mjs — portiert nach perl5
# Quelle: javascript, Onboarding@main:scripts/secret-scan.mjs
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Find;
use File::Spec;
use Cwd qw(abs_path);

# Wurzelverzeichnis bestimmen
my $root = abs_path(File::Spec->catdir(__FILE__, '..', '..'));

# Verzeichnisse und Dateien, die übersprungen werden sollen
my %skipped = map { $_ => 1 } (
    "node_modules",
    ".next",
    ".git",
    ".pytest_cache",
    "__pycache__",
    "media-production/raw",
    "media-production/private"
);

# Muster für geheime Schlüssel
my @patterns = (
    qr/sk-(?:proj|svcacct|ant|or-v1|admin)-[A-Za-z0-9_-]{20,}/,
    qr/(?:nvapi|lin_api|ntn|vcp)_[A-Za-z0-9_-]{20,}/,
    qr/ELEVENLABS_API_KEY\s*=\s*["']?[A-Za-z0-9]{20,}/,
    qr/WAVESPEED_API_KEY\s*=\s*["']?[A-Za-z0-9]{20,}/,
);

# Funde sammeln
my %findings;

# Callback-Funktion für File::Find
sub scan_file {
    my $file = $_;
    my $full_path = $File::Find::name;
    my $relative_path = File::Spec->abs2rel($full_path, $root);

    # Prüfen, ob die Datei übersprungen werden soll
    foreach my $skip (keys %skipped) {
        if ($relative_path eq $skip || $relative_path =~ /^$skip\//) {
            $File::Find::prune = 1; # Verzeichnis überspringen
            return;
        }
    }

    # .env-Dateien prüfen
    if ($file eq '.env' || ($file =~ /^\.env\./ && $file ne '.env.example')) {
        $findings{$relative_path} = 1;
        return;
    }

    # Dateigröße prüfen (< 2 MB)
    if (-f $full_path && -s $full_path < 2_000_000) {
        open(my $fh, '<', $full_path) or return;
        my $content = do { local $/; <$fh> };
        close($fh);

        # Auf Muster prüfen
        foreach my $pattern (@patterns) {
            if ($content =~ /$pattern/) {
                $findings{$relative_path} = 1;
                last;
            }
        }
    }
}

# Verzeichnis durchsuchen
find(\&scan_file, $root);

# Ergebnisse auswerten
if (%findings) {
    my @unique_findings = keys %findings;
    print STDERR "Secret-Scan fehlgeschlagen: " . join(", ", @unique_findings) . "\n";
    exit(1);
}

print "Secret-Scan bestanden.\n";
