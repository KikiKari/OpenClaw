#!/usr/bin/perl
# post-nodes-report.js — portiert nach perl5
# Quelle: javascript, OpenClaw@gateway1:scripts/post-nodes-report.js
# auch in: OpenClaw@gateway2:scripts/post-nodes-report.js
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use utf8;
use File::Spec;
use File::Slurp qw(read_file write_file);
use IPC::Run3 qw(run3);

# Pfade
my $dashboard_path = File::Spec->catfile(File::Spec->updir(), 'dashboards', 'nodes-overview.md');
my $report_log = File::Spec->catfile(File::Spec->updir(), 'logs', 'nodes-report.log');

# Farbcodes
my %C = (
  green => "\e[32m",
  yellow => "\e[33m",
  red => "\e[31m",
  reset => "\e[0m"
);

sub post_report {
  my $content;
  eval {
    $content = read_file($dashboard_path, binmode => ':utf8');
  };
  if ($@) {
    print STDERR "$C{red}❌ Fehler beim Lesen der Dashboard-Datei:$C{reset} $@\n";
    return;
  }

  # Nachricht über OpenClaw message senden
  my $escaped_content = $content;
  $escaped_content =~ s/\n/\\n/g;
  $escaped_content =~ s/"/\\"/g;
  my $message_cmd = "openclaw message send --target=main --message \"$escaped_content\"";

  my ($stdout, $stderr);
  my @cmd = ('sh', '-c', $message_cmd);
  run3(\@cmd, \undef, \$stdout, \$stderr);

  if ($?) {
    print STDERR "$C{red}❌ Fehler beim Senden der Nachricht:$C{reset} $stderr\n";
    eval {
      my $timestamp = localtime();
      write_file($report_log, { append => 1 }, "[$timestamp] Failed to post: $stderr\n");
    };
  } else {
    print "$C{green}✅ Report erfolgreich im 'main'-Channel gepostet.$C{reset}\n";
    eval {
      my $timestamp = localtime();
      write_file($report_log, { append => 1 }, "[$timestamp] Report posted.\n");
    };
  }
}

# Hauptausführung
print "$C{yellow}📤 Sende Nodes-Übersicht in 'main'...$C{reset}\n";
post_report();
