#!/usr/bin/env perl
# abstraction-provenance: {"artifact_sha256": "8a4ee38874ce9be4d2575113004d008bb469ec34f37cec0a58049fda53796883", "source_sha256": "1b01ca0f5943b16d3905faf557953600ee54f15ecf1dc18c1461585eba94d376", "target_language": "perl5"}
# abstractions-manager-cron.sh — portiert nach perl5
# Quelle: shell, OpenClaw@gateway1:scripts/abstractions-manager-cron.sh
# Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use Fcntl qw(:flock);
use IPC::Open3;
use Symbol 'gensym';

$ENV{PATH} = "/home/openclaw/.local/bin:/usr/local/bin:/usr/bin:/bin";

# Lade Umgebungsvariablen aus .env Datei
my $env_file = "/home/openclaw/.openclaw/.env";
if (-f $env_file) {
    open my $fh, '<', $env_file or die "Kann $env_file nicht öffnen: $!";
    while (my $line = <$fh>) {
        chomp $line;
        next if $line =~ /^\s*#/;  # Überspringe Kommentare
        next if $line =~ /^\s*$/;  # Überspringe leere Zeilen
        if ($line =~ /^([^=]+)=(.*)$/) {
            my ($key, $value) = ($1, $2);
            # Entferne führende und abschließende Anführungszeichen falls vorhanden
            $value =~ s/^["'](.*)["']$/$1/;
            $ENV{$key} = $value;
        }
    }
    close $fh;
}

# Prüfe ob OPENROUTER_API_KEY gesetzt ist
die "OPENROUTER_API_KEY fehlt\n" unless defined $ENV{OPENROUTER_API_KEY};

# Setze GITHUB_TOKEN falls noch nicht gesetzt
$ENV{GITHUB_TOKEN} //= $ENV{GH_TOKEN} // $ENV{GH_ACCESS_TOKEN} // '';

# Versuche Lock-Datei zu öffnen
my $lockfile = "/home/openclaw/.openclaw/locks/abstractions-manager.lock";
open my $lock_fh, '>', $lockfile or die "Kann Lock-Datei $lockfile nicht öffnen: $!";

# Versuche exclusive lock zu erhalten, non-blocking
unless (flock($lock_fh, LOCK_EX | LOCK_NB)) {
    die "Kann Lock nicht erhalten, ein anderer Prozess läuft bereits\n";
}

# Führe Python-Skript aus
my $python_script = "/home/openclaw/.openclaw/workspace/skills/script-abstractions-manager/scripts/ABSTRACTIONS_MANAGER.py";
my @args = ($^X, "-S", "python3", $python_script, @ARGV);

# Öffne stderr für Fehlerausgabe
my $stderr = gensym;
my $pid = open3(undef, undef, $stderr, @args);

# Warte auf Prozessende und prüfe Exit-Status
waitpid($pid, 0);
my $exit_status = $?;

# Schließe Lock-Datei (wird automatisch beim Skriptende geschlossen)
close $lock_fh;

# Beende mit dem gleichen Exit-Status wie das Python-Skript
exit($exit_status >> 8);
