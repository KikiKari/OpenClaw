#!/usr/bin/env perl
use strict;
use warnings;
binmode(STDOUT, ':encoding(UTF-8)');

# OpenClaw log analyzer (Perl) — parses gateway access logs from stdin
my %counts = (INFO => 0, WARN => 0, ERROR => 0);

while (my $line = <STDIN>) {
    if ($line =~ /^(\S+)\s+(INFO|WARN|ERROR)\s+(\S+)\s+(.+)$/) {
        my ($ts, $level, $node, $msg) = ($1, $2, $3, $4);
        $counts{$level}++;
        print "\x{26a0} $ts [$node] $msg\n" if $level eq 'ERROR';
    }
}

print "\n--- Summary ---\n";
print "$_: $counts{$_}\n" for qw(ERROR INFO WARN);
