#!/usr/bin/env perl
# find-sessions.sh — portiert nach perl5
# Quelle: shell, OpenClaw@gateway1:skills/tmux/scripts/find-sessions.sh
# auch in: OpenClaw@gateway2:skills/tmux/scripts/find-sessions.sh
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use Getopt::Long qw(GetOptions);
use Pod::Usage qw(pod2usage);

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
) or pod2usage(2);

pod2usage(1) if $help;

if ($scan_all && ($socket_name ne "" || $socket_path ne "")) {
    print STDERR "Cannot combine --all with -L or -S\n";
    exit 1;
}

if ($socket_name ne "" && $socket_path ne "") {
    print STDERR "Use either -L or -S, not both\n";
    exit 1;
}

unless (`which tmux 2>/dev/null`) {
    print STDERR "tmux not found in PATH\n";
    exit 1;
}

sub list_sessions {
    my ($label, @tmux_args) = @_;
    my @cmd = ("tmux", @tmux_args, "list-sessions", "-F", '#{session_name}\t#{session_attached}\t#{session_created_string}');
    my $sessions = `@cmd 2>/dev/null`;

    unless (defined $sessions) {
        print STDERR "No tmux server found on $label\n";
        return 1;
    }

    if ($query ne "") {
        my @lines = split /\n/, $sessions;
        @lines = grep { lc($_) =~ lc($query) } @lines;
        $sessions = join("\n", @lines) . "\n";
    }

    if ($sessions eq "") {
        print "No sessions found on $label\n";
        return 0;
    }

    print "Sessions on $label:\n";
    for my $line (split /\n/, $sessions) {
        chomp $line;
        my ($name, $attached, $created) = split /\t/, $line;
        my $attached_label = ($attached == 1) ? "attached" : "detached";
        printf '  - %s (%s, started %s)%s', $name, $attached_label, $created, "\n";
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
    push @tmux_cmd, "-L", $socket_name;
    $socket_label = "socket name '$socket_name'";
} elsif ($socket_path ne "") {
    push @tmux_cmd, "-S", $socket_path;
    $socket_label = "socket path '$socket_path'";
}

shift @tmux_cmd; # remove "tmux"
list_sessions($socket_label, @tmux_cmd);

__END__

=head1 NAME

find-sessions.pl - List tmux sessions on a socket

=head1 SYNOPSIS

find-sessions.pl [options]

 Options:
   -L, --socket       tmux socket name (passed to tmux -L)
   -S, --socket-path  tmux socket path (passed to tmux -S)
   -A, --all          scan all sockets under CLAWDBOT_TMUX_SOCKET_DIR
   -q, --query        case-insensitive substring to filter session names
   -h, --help         show this help

=head1 DESCRIPTION

List tmux sessions on a socket (default tmux socket if none provided).

=cut
