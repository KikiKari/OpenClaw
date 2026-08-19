#!/usr/bin/env perl
# openclaw-audit.sh — portiert nach perl5
# Quelle: shell, OpenClaw@gateway1:scripts/openclaw-audit.sh
# auch in: OpenClaw@gateway2:scripts/openclaw-audit.sh
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use Cwd qw(abs_path);
use File::Basename;
use POSIX qw(strftime);

my $script_dir = dirname(abs_path($0));
my $date_stamp = strftime("%Y-%m-%d", localtime);
my $out = "${script_dir}/openclaw-audit-${date_stamp}.log";

my @oc = ('openclaw', '--no-color');

open(my $fh, '>', $out) or die "Could not open file '$out': $!";

print $fh "================================================================\n";
print $fh "OpenClaw audit run\n";
print $fh "Started:  " . strftime("%Y-%m-%dT%H:%M:%S%z", localtime) . "\n";
print $fh "Host:     " . (`hostname` // '') . "\n";
print $fh "User:     " . ($ENV{'USER'} // '') . "\n";
my $version = `openclaw --version 2>/dev/null`;
chomp $version if defined $version;
print $fh "Version:  " . ($version || 'unknown') . "\n";
print $fh "Output:   ${out}\n";
print $fh "================================================================\n";

close $fh;

sub run_cmd {
    my ($title, @cmd) = @_;
    open(my $fh, '>>', $out) or die "Could not open file '$out': $!";
    
    print $fh "\n";
    print $fh "----------------------------------------------------------------\n";
    print $fh "### ${title}\n";
    print $fh "### \$ " . join(' ', @cmd) . "\n";
    print $fh "### " . strftime("%Y-%m-%dT%H:%M:%S%z", localtime) . "\n";
    print $fh "----------------------------------------------------------------\n";
    
    my $output = `@cmd 2>&1`;
    print $fh $output;
    my $rc = $? >> 8;
    print $fh "[exit: ${rc}]\n";
    
    close $fh;
}

run_cmd("tasks audit --severity error", @oc, 'tasks', 'audit', '--severity', 'error');
run_cmd("secrets audit", @oc, 'secrets', 'audit');
run_cmd("security audit", @oc, 'security', 'audit');
run_cmd("plugins doctor", @oc, 'plugins', 'doctor');
run_cmd("plugins deps", @oc, 'plugins', 'deps');
run_cmd("plugins registry", @oc, 'plugins', 'registry');
run_cmd("skills check", @oc, 'skills', 'check');
run_cmd("hooks check", @oc, 'hooks', 'check');
run_cmd("gateway status --deep", @oc, 'gateway', 'status', '--deep');
run_cmd("channels status --probe", @oc, 'channels', 'status', '--probe');
run_cmd("memory status --deep", @oc, 'memory', 'status', '--deep');
run_cmd("sessions --all-agents", @oc, 'sessions', '--all-agents');
run_cmd("tasks list", @oc, 'tasks', 'list');
run_cmd("cron list", @oc, 'cron', 'list');

open(my $fh, '>>', $out) or die "Could not open file '$out': $!";
print $fh "\n";
print $fh "================================================================\n";
print $fh "Audit complete: " . strftime("%Y-%m-%dT%H:%M:%S%z", localtime) . "\n";
print $fh "================================================================\n";
close $fh;

print "Audit complete. Output: ${out}\n";
