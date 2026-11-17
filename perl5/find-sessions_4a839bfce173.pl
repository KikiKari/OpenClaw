#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "83fdd2835f3141da77a9aa3bbe1c2b35a1ca2313275d4b0c5b08387929c34ecb", "source_sha256": "a137d03b3b37332439a1592831d60479ff86315c7e6d6ed7da0fb799db0f13f7", "target_language": "perl5"}
# find-sessions.sh — portiert nach perl5
# Quelle: shell, OpenClaw@gateway1:skills/tmux/scripts/find-sessions.sh
# auch in: OpenClaw@gateway2:skills/tmux/scripts/find-sessions.sh
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;

my $usage = sub {
    print <<'USAGE';
Usage: find-sessions.sh [-L socket-name|-S socket-path|-A] [-q pattern]

List tmux sessions on a socket (default tmux socket if none provided).

Options:
  -L, --socket       tmux socket name (passed to tmux -L)
  -S, --socket-path  tmux socket path (passed to tmux -S)
  -A, --all          scan all sockets under CLAWDBOT_TMUX_SOCKET_DIR
  -q, --query        case-insensitive substring to filter session names
  -h, --help         show this help
USAGE
};

my $socket_name = "";
my $socket_path = "";
my $query = "";
my $scan_all = 0;
my $help = 0;

my $socket_dir = $ENV{CLAWDBOT_TMUX_SOCKET_DIR} // ($ENV{TMPDIR} // "/tmp") . "/clawdbot-tmux-sockets";

GetOptions(
    "L|socket=s" => \$socket_name,
    "S|socket-path=s" => \$socket_path,
    "A|all" => \$scan_all,
    "q|query=s" => \$query,
    "h|help" => \$help,
) or do {
    &$usage();
    exit 1;
};

if ($help) {
    &$usage();
    exit 0;
}

if ($scan_all && ($socket_name ne "" || $socket_path ne "")) {
    print STDERR "Cannot combine --all with -L or -S\n";
    exit 1;
}

if ($socket_name ne "" && $socket_path ne "") {
    print STDERR "Use either -L or -S, not both\n";
    exit 1;
}

unless (`which tmux`) {
    print STDERR "tmux not found in PATH\n";
    exit 1;
}

sub list_sessions {
    my ($label, @tmux_args) = @_;
    my @tmux_cmd = ("tmux", @tmux_args);

    my $sessions_output = `@tmux_cmd list-sessions -F '\#{session_name}\\t\\#{session_attached}\\t\\#{session_created_string}' 2>/dev/null`;
    my $exit_status = $?;

    if ($exit_status != 0) {
        print STDERR "No tmux server found on $label\n";
        return 1;
    }

    my @sessions = split /\n/, $sessions_output;
    chomp @sessions;

    if ($query ne "") {
        @sessions = grep { lc($_) =~ lc($query) } @sessions;
    }

    if (@sessions == 0) {
        print "No sessions found on $label\n";
        return 0;
    }

    print "Sessions on $label:\n";
    for my $session (@sessions) {
        my ($name, $attached, $created) = split /\t/, $session;
        my $attached_label = ($attached eq "1") ? "attached" : "detached";
        printf '  - %s (%s, started %s)'."\n", $name, $attached_label, $created;
    }
    return 0;
}

if ($scan_all) {
    unless (-d $socket_dir) {
        print STDERR "Socket directory not found: $socket_dir\n";
        exit 1;
    }

    opendir(my $dh, $socket_dir) or die "Could not open directory '$socket_dir': $!";
    my @sockets = map { "$socket_dir/$_" } grep { -S "$socket_dir/$_" } readdir($dh);
    closedir $dh;

    if (@sockets == 0) {
        print STDERR "No sockets found under $socket_dir\n";
        exit 1;
    }

    my $exit_code = 0;
    for my $sock (@sockets) {
        my $result = list_sessions("socket path '$sock'", "-S", $sock);
        $exit_code = $result if $result != 0;
    }
    exit $exit_code;
}

my @tmux_cmd = ("tmux");
my $socket_label = "default socket";

if ($socket_name ne "") {
    push @tmux_cmd, ("-L", $socket_name);
    $socket_label = "socket name '$socket_name'";
} elsif ($socket_path ne "") {
    push @tmux_cmd, ("-S", $socket_path);
    $socket_label = "socket path '$socket_path'";
}

list_sessions($socket_label, splice(@tmux_cmd, 1));
