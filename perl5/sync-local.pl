#!/usr/bin/perl
# sync-local.ps1 — portiert nach perl5
# Quelle: powershell, Onboarding@main:scripts/sync-local.ps1
# Erzeugt: 2026-08-21 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Basename;
use Cwd qw(abs_path);
use Time::Piece;
use IPC::Run3;

my $branch = "claude/onboarding-persistent-sandbox-vjfmcx";
my $interval_seconds = 20;
my $compose_file = "docker-compose.dev.yml";
my $once = 0;

# Parameterverarbeitung (rudimentär, da Getopt::Long nicht verwendet)
for my $i (0 .. $#ARGV) {
    if ($ARGV[$i] eq "-Branch" && $i+1 <= $#ARGV) {
        $branch = $ARGV[$i+1];
        $i++;
    } elsif ($ARGV[$i] eq "-IntervalSeconds" && $i+1 <= $#ARGV) {
        $interval_seconds = int($ARGV[$i+1]);
        $i++;
    } elsif ($ARGV[$i] eq "-ComposeFile" && $i+1 <= $#ARGV) {
        $compose_file = $ARGV[$i+1];
        $i++;
    } elsif ($ARGV[$i] eq "-Once") {
        $once = 1;
    }
}

my $repo_root = dirname(dirname(abs_path($0)));
chdir $repo_root or die "Konnte nicht in Repo-Root wechseln: $!";

sub log_msg {
    my ($msg) = @_;
    my $timestamp = localtime->strftime("%H:%M:%S");
    print "[$timestamp] $msg\n";
}

sub invoke_compose {
    my (@compose_args) = @_;
    my @cmd = ("docker", "compose", "-f", $compose_file, @compose_args);
    system(@cmd);
    if ($? != 0) {
        log_msg("WARNUNG: docker compose " . join(" ", @compose_args) . " fehlgeschlagen (Exit $?)");
    }
}

# Sicherstellen, dass der Ziel-Branch ausgecheckt ist.
my $current_output = `git rev-parse --abbrev-ref HEAD`;
chomp(my $current = $current_output);
if ($current ne $branch) {
    log_msg("Wechsle von '$current' auf '$branch' …");
    system("git", "fetch", "origin", $branch);
    open(my $fh, "-|", "git", "switch", $branch, "2>/dev/null") or die "fork: $!";
    close $fh;
    if ($? != 0) {
        system("git", "switch", "-c", $branch, "--track", "origin/$branch");
    }
    if ($? != 0) {
        die "Branch '$branch' konnte nicht ausgecheckt werden.";
    }
}

log_msg("Sync aktiv: origin/$branch -> $repo_root (Intervall ${interval_seconds}s, Compose: $compose_file)");

while (1) {
    system("git", "fetch", "origin", $branch, "--quiet");
    if ($? != 0) {
        log_msg("Fetch fehlgeschlagen (Netzwerk?) — nächster Versuch in ${interval_seconds}s");
    } else {
        chomp(my $local = `git rev-parse HEAD`);
        chomp(my $remote = `git rev-parse origin/$branch`);

        if ($local ne $remote) {
            system("git", "merge-base", "--is-ancestor", $local, $remote);
            if ($? != 0) {
                log_msg("ACHTUNG: Lokaler Stand ist von origin/$branch abgewichen (lokale Commits?). Kein automatischer Merge — bitte manuell auflösen.");
            } else {
                my $changed_files = `git diff --name-only $local..$remote`;
                my @changed = split /\r?\n/, $changed_files;
                system("git", "merge", "--ff-only", $remote, "--quiet");
                my $local_short = substr($local, 0, 7);
                my $remote_short = substr($remote, 0, 7);
                log_msg("Aktualisiert $local_short -> $remote_short (" . scalar(@changed) . " Datei(en))");

                my @frontend_deps = grep { $_ eq "package.json" || $_ eq "package-lock.json" } @changed;
                my @backend_image = grep { /^backend\/(Dockerfile|requirements.*\.txt)$/ } @changed;
                my @compose_changed = grep { $_ eq $compose_file } @changed;

                if (@compose_changed) {
                    log_msg("Compose-Datei geändert — erzeuge Dev-Stack neu …");
                    invoke_compose("up", "-d");
                }
                if (@backend_image) {
                    log_msg("Backend-Dependencies/Dockerfile geändert — baue nur das Backend neu …");
                    invoke_compose("up", "-d", "--build", "backend");
                }
                if (@frontend_deps) {
                    log_msg("Frontend-Dependencies geändert — starte Frontend neu (npm install läuft im Container) …");
                    invoke_compose("restart", "frontend");
                }
                if (!@compose_changed && !@backend_image && !@frontend_deps) {
                    log_msg("Nur Quellcode/Assets — Hot-Reload übernimmt, kein Build nötig.");
                }
            }
        }
    }

    if ($once) { last; }
    sleep($interval_seconds);
}
