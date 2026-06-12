#!/usr/bin/env raku
# OpenClaw log analyzer — parses gateway access logs

my regex log-line {
    $<timestamp> = [\d**4 "-" \d**2 "-" \d**2 "T" \d**2 ":" \d**2 ":" \d**2]
    \s+ $<level>  = [INFO | WARN | ERROR]
    \s+ $<node>   = [\S+]
    \s+ $<msg>    = [.+]
}

my %stats = (INFO => 0, WARN => 0, ERROR => 0);

for $*IN.lines -> $line {
    if $line ~~ &log-line {
        %stats{$/<level>}++;
        say "⚠ {$/<timestamp>} [{$/<node>}] {$/<msg>}" if $/<level> eq "ERROR";
    }
}

say "\n--- Summary ---";
say "$_: %stats{$_}" for %stats.keys.sort;