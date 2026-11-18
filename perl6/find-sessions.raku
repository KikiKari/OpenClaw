#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "62cb29a84c2876a5d36a9ed80300b40d9fcd88e4a951d442fbd9e8a6001ee994", "source_sha256": "a137d03b3b37332439a1592831d60479ff86315c7e6d6ed7da0fb799db0f13f7", "target_language": "perl6"}
# find-sessions.sh — portiert nach perl6
# Quelle: shell, OpenClaw@gateway1:skills/tmux/scripts/find-sessions.sh
# auch in: OpenClaw@gateway2:skills/tmux/scripts/find-sessions.sh
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

use v6.d;

sub usage() {
    say q:to/USAGE/;
Usage: find-sessions.sh [-L socket-name|-S socket-path|-A] [-q pattern]

List tmux sessions on a socket (default tmux socket if none provided).

Options:
  -L, --socket       tmux socket name (passed to tmux -L)
  -S, --socket-path  tmux socket path (passed to tmux -S)
  -A, --all          scan all sockets under CLAWDBOT_TMUX_SOCKET_DIR
  -q, --query        case-insensitive substring to filter session names
  -h, --help         show this help
USAGE
}

my Str $socket-name = "";
my Str $socket-path = "";
my Str $query = "";
my Bool $scan-all = False;
my Str $socket-dir = %*ENV<CLAWDBOT_TMUX_SOCKET_DIR> // (%*ENV<TMPDIR> // '/tmp') ~ '/clawdbot-tmux-sockets';

my @args = @*ARGS;
while @args {
    given @args.shift {
        when /^ '-' L? $/ | '--socket' {
            $socket-name = @args.shift // '';
        }
        when /^ '-' S? $/ | '--socket-path' {
            $socket-path = @args.shift // '';
        }
        when /^ '-' A? $/ | '--all' {
            $scan-all = True;
        }
        when /^ '-' q? $/ | '--query' {
            $query = @args.shift // '';
        }
        when /^ '-' h? $/ | '--help' {
            usage();
            exit 0;
        }
        default {
            note "Unknown option: $_";
            usage();
            exit 1;
        }
    }
}

if $scan-all && ($socket-name || $socket-path) {
    note "Cannot combine --all with -L or -S";
    exit 1;
}

if $socket-name && $socket-path {
    note "Use either -L or -S, not both";
    exit 1;
}

unless run('tmux', '--version', :out, :err).exitcode == 0 {
    note "tmux not found in PATH";
    exit 1;
}

sub list-sessions(Str $label, *@tmux-cmd) {
    my $proc = run(|@tmux-cmd, 'list-sessions', '-F', '#{session_name}	#{session_attached}	#{session_created_string}', :out, :err);
    
    unless $proc.exitcode == 0 {
        note "No tmux server found on $label";
        return 1;
    }
    
    my $sessions = $proc.out.slurp(:close);
    my @lines = $sessions.lines;
    
    if $query {
        @lines = @lines.grep({ .lc.contains($query.lc) });
    }
    
    unless @lines {
        say "No sessions found on $label";
        return 0;
    }
    
    say "Sessions on $label:";
    for @lines -> $line {
        my ($name, $attached, $created) = $line.split("\t");
        my $attached-label = $attached eq '1' ?? 'attached' !! 'detached';
        say "  - $name ($attached-label, started $created)";
    }
    
    return 0;
}

if $scan-all {
    unless $socket-dir.IO.d {
        note "Socket directory not found: $socket-dir";
        exit 1;
    }
    
    my @sockets = $socket-dir.IO.dir.grep(*.IO.f && *.IO.s).sort;
    
    unless @sockets {
        note "No sockets found under $socket-dir";
        exit 1;
    }
    
    my $exit-code = 0;
    for @sockets -> $sock {
        my $result = list-sessions("socket path '$sock'", 'tmux', '-S', $sock.Str);
        $exit-code = $result if $result != 0;
    }
    exit $exit-code;
}

my @tmux-cmd = ['tmux'];
my $socket-label = "default socket";

if $socket-name {
    @tmux-cmd.append: '-L', $socket-name;
    $socket-label = "socket name '$socket-name'";
} elsif $socket-path {
    @tmux-cmd.append: '-S', $socket-path;
    $socket-label = "socket path '$socket-path'";
}

my $exit-code = list-sessions($socket-label, |@tmux-cmd);
exit $exit-code;
