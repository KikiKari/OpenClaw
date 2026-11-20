#!/usr/bin/env perl
# abstraction-provenance: {"artifact_sha256": "1b13e1553ca77b89638865aaab3f54b087cc17818b73e559970f2591d6381315", "source_sha256": "c5da3d5a6d1b96d5dbfcceb3eeaaf1082185c08fa2edcbc7b87c36871484ccf2", "target_language": "perl5"}
# docker-e2e-logs.sh — portiert nach perl5
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/lib/docker-e2e-logs.sh
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Temp qw(tempfile);

sub run_logged {
    my ($label, @command) = @_;
    
    # Erstelle temporäre Logdatei
    my ($fh, $log_file) = tempfile(
        "openclaw-${label}-XXXXXX.log",
        DIR => $ENV{TMPDIR} // '/tmp',
        UNLINK => 0
    );
    
    # Schließe den Dateihandle, da wir nur den Dateinamen brauchen
    close($fh);
    
    # Öffne die Datei zum Schreiben
    open(my $log_fh, '>', $log_file) or die "Cannot open $log_file: $!";
    
    # Führe den Befehl aus und leite Ausgabe um
    my $pid = fork();
    unless ($pid) {
        # Kindprozess
        open(STDOUT, '>&', $log_fh);
        open(STDERR, '>&', $log_fh);
        exec(@command) or die "Cannot exec: $!";
    }
    
    # Vaterprozess wartet auf das Kind
    waitpid($pid, 0);
    my $exit_code = $?;
    
    close($log_fh);
    
    if ($exit_code != 0) {
        # Gib den Log-Inhalt aus
        open(my $read_fh, '<', $log_file) or die "Cannot open $log_file: $!";
        print while <$read_fh>;
        close($read_fh);
        unlink($log_file);
        return 0;
    }
    
    unlink($log_file);
    return 1;
}
