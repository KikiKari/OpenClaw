#!/usr/bin/env perl
# abstraction-provenance: {"artifact_sha256": "fe40e145fd9f570996ab665b634a3867c3adfd3cb5411b07d280b653ae68a06d", "source_sha256": "1b01ca0f5943b16d3905faf557953600ee54f15ecf1dc18c1461585eba94d376", "target_language": "perl5"}
# abstractions-manager-cron.sh — portiert nach perl5
# Quelle: shell, OpenClaw@gateway1:scripts/abstractions-manager-cron.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use Fcntl qw(:flock);
use IPC::Open3;
use Symbol 'gensym';

$ENV{PATH} = "/home/openclaw/.local/bin:/usr/local/bin:/usr/bin:/bin";

# Lade Umgebungsvariablen
my $env_file = "/home/openclaw/.openclaw/.env";
if (-f $env_file) {
    open my $fh, '<', $env_file or die "Kann $env_file nicht öffnen: $!";
    while (my $line = <$fh>) {
        chomp $line;
        next if $line =~ /^\s*#/;  # Kommentare ignorieren
        next if $line =~ /^\s*$/;  # Leere Zeilen ignorieren
        if ($line =~ /^([^=]+)=(.*)$/) {
            my ($key, $value) = ($1, $2);
            # Entferne führende und abschließende Anführungszeichen
            $value =~ s/^["']//;
            $value =~ s/["']$//;
            $ENV{$key} = $value;
        }
    }
    close $fh;
}

# Prüfe ob OPENROUTER_API_KEY gesetzt ist
die "OPENROUTER_API_KEY fehlt" unless exists $ENV{OPENROUTER_API_KEY};

# Setze GITHUB_TOKEN
$ENV{GITHUB_TOKEN} = $ENV{GITHUB_TOKEN} || $ENV{GH_TOKEN} || $ENV{GH_ACCESS_TOKEN} || "";

# Lock-Datei
my $lockfile = "/home/openclaw/.openclaw/locks/abstractions-manager.lock";
my $lockfh;
unless (open($lockfh, '>', $lockfile)) {
    die "Kann Lock-Datei $lockfile nicht öffnen: $!";
}

# Versuche Lock zu erhalten (non-blocking)
unless (flock($lockfh, LOCK_EX | LOCK_NB)) {
    print STDERR "Konnte Lock nicht erhalten, ein anderer Prozess läuft bereits\n";
    exit 1;
}

# Python-Skript ausführen
my $python_script = "/home/openclaw/.openclaw/workspace/skills/script-abstractions-manager/scripts/ABSTRACTIONS_MANAGER.py";
my @cmd = ('/usr/bin/python3', $python_script, @ARGV);

# Führe das Kommando aus und leite Ein-/Ausgabe durch
my ($stdin, $stdout, $stderr);
$stderr = gensym;
my $pid = open3($stdin, $stdout, $stderr, @cmd);

# Schließe stdin
close $stdin;

# Lese stdout und stderr
my $output = do { local $/; <$stdout> };
my $errors = do { local $/; <$stderr> };

# Warte auf Beendigung
waitpid($pid, 0);
my $exit_code = $? >> 8;

# Gebe Ausgaben weiter
print $output if defined $output;
print STDERR $errors if defined $errors;

# Beende mit demselben Exit-Code wie das Python-Skript
exit $exit_code;
