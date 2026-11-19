#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "92a2241923810fb8e7a900edc87d596a3f80afe46d8ce606630a8fef79b3fcb7", "source_sha256": "04afaeaf031d1de3a9c71606dba8c1d6ea78b3b575d8ecf94af9256d4dc3886d", "target_language": "perl5"}
# post-nodes-report.js — portiert nach perl5
# Quelle: javascript, OpenClaw@gateway1:scripts/post-nodes-report.js
# auch in: OpenClaw@gateway2:scripts/post-nodes-report.js
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Spec;
use File::Basename;
use POSIX qw(strftime);

# Pfade
my $script_dir = dirname(__FILE__);
my $DASHBOARD_PATH = File::Spec->catfile($script_dir, '../dashboards/nodes-overview.md');
my $REPORT_LOG = File::Spec->catfile($script_dir, '../logs/nodes-report.log');

# Farbcodes
my %C = (
    green  => "\e[32m",
    yellow => "\e[33m",
    red    => "\e[31m",
    reset  => "\e[0m"
);

sub post_report {
    my $content;
    eval {
        open my $fh, '<:encoding(UTF-8)', $DASHBOARD_PATH or die "Kann Datei nicht öffnen: $!";
        local $/;
        $content = <$fh>;
        close $fh;
    };
    if ($@) {
        print STDERR "${C{red}}❌ Fehler beim Lesen der Dashboard-Datei:${C{reset}} $@\n";
        return;
    }

    # Nachricht über OpenClaw senden
    # JSON escapen und newlines umwandeln
    my $escaped_content = $content;
    $escaped_content =~ s/\\/\\\\/g;
    $escaped_content =~ s/"/\\"/g;
    $escaped_content =~ s/\n/\\n/g;
    $escaped_content =~ s/\r/\\r/g;
    $escaped_content =~ s/\$/\\\$/g;  # Dollarzeichen escapen für Shell

    my $message_cmd = qq(openclaw message send --target=main --message "\$(echo "$escaped_content" | sed 's/\\\\n/\\\\\\\\n/g')");

    my $exit_code = system($message_cmd);
    if ($exit_code == 0) {
        print "${C{green}}✅ Report erfolgreich im 'main'-Channel gepostet.${C{reset}}\n";
        log_message("Report posted.");
    } else {
        my $error_msg = "Fehler beim Ausführen des Befehls: exit code $exit_code";
        print STDERR "${C{red}}❌ Fehler beim Senden der Nachricht:${C{reset}} $error_msg\n";
        log_message("Failed to post: $error_msg");
    }
}

sub log_message {
    my ($msg) = @_;
    my $timestamp = strftime "%Y-%m-%dT%H:%M:%SZ", gmtime;
    eval {
        open my $log_fh, '>>', $REPORT_LOG or die "Kann Logdatei nicht öffnen: $!";
        print $log_fh "[$timestamp] $msg\n";
        close $log_fh;
    };
    if ($@) {
        print STDERR "Fehler beim Schreiben ins Log: $@\n";
    }
}

# Hauptausführung
print "${C{yellow}}📤 Sende Nodes-Übersicht in 'main'...${C{reset}}\n";
post_report();
