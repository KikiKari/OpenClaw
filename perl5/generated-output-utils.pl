#!/usr/bin/env perl
# abstraction-provenance: {"artifact_sha256": "94ad83df9e86d70bf49ca53886721bd202f69dc4debf2873c58a47daf3460b81", "source_sha256": "3c225928c07272d97d9f90c9c2134a117467308ab5be4a60ac9e89701f38b3e9", "target_language": "perl5"}
# generated-output-utils.mjs — portiert nach perl5
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/generated-output-utils.mjs
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use utf8;
use File::Spec::Functions qw(rel2abs catfile);
use File::Basename qw(dirname);
use Cwd qw(cwd abs_path);
use File::Find qw(find);
use File::Path qw(make_path);

# Hilfsfunktion zum Lesen einer Datei, falls sie existiert
sub read_if_exists {
    my ($file_path) = @_;
    if (-f $file_path) {
        open my $fh, '<:encoding(UTF-8)', $file_path or die "Cannot open $file_path: $!";
        local $/;
        my $content = <$fh>;
        close $fh;
        return $content;
    }
    return undef;
}

# Hilfsfunktion zum Schreiben einer Textdatei, falls sich der Inhalt geändert hat
sub write_text_file_if_changed {
    my ($output_path, $next_content) = @_;

    my $current_content = read_if_exists($output_path);
    if (defined $current_content && $current_content eq $next_content) {
        return 0; # Keine Änderung
    }

    # Stelle sicher, dass das Verzeichnis existiert
    my $dir = dirname($output_path);
    make_path($dir) unless -d $dir;

    open my $fh, '>:encoding(UTF-8)', $output_path or die "Cannot write to $output_path: $!";
    print $fh $next_content;
    close $fh;

    return 1; # Datei wurde geschrieben
}

# Funktion zum Schreiben der generierten Ausgabe
sub write_generated_output {
    my ($params) = @_;

    my $repo_root = $params->{repoRoot};
    my $output_path = $params->{outputPath};
    my $next_content = $params->{next};
    my $check = $params->{check} // 0;

    # Konvertiere relativen Pfad zu absolutem Pfad
    my $absolute_output_path = rel2abs($output_path, $repo_root);

    my $current_content = read_if_exists($absolute_output_path);
    my $changed = (!defined $current_content || $current_content ne $next_content);

    if ($check) {
        return {
            changed => $changed,
            wrote => 0,
            outputPath => $absolute_output_path,
        };
    }

    my $wrote = write_text_file_if_changed($absolute_output_path, $next_content);

    return {
        changed => $changed,
        wrote => $wrote,
        outputPath => $absolute_output_path,
    };
}

# CLI-Funktion zur Berichterstattung über generierte Ausgaben
sub report_generated_output_cli {
    my ($params) = @_;

    my $script_name = $0;
    my $import_meta_url = $params->{importMetaUrl};

    # Prüfe, ob dieses Skript direkt aufgerufen wurde
    if (defined $import_meta_url && $import_meta_url ne $script_name) {
        return;
    }

    my @argv = @ARGV;
    my $check = grep { $_ eq '--check' } @argv;

    my $result = $params->{run}->({ check => $check });

    return unless $result->{changed};

    my $output_path = $result->{outputPath};
    my $cwd = cwd();
    my $relative_output_path = abs_path($output_path);
    $relative_output_path =~ s/^\Q$cwd\E//;
    $relative_output_path =~ s/^\/+//;

    if ($check) {
        warn "[$params->{label}] stale generated output at $relative_output_path\n";
        exit 1;
    }

    print "[$params->{label}] wrote $relative_output_path\n";
}

1; # Modul erfolgreich geladen
