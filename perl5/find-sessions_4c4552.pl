#!/usr/bin/env perl
# abstraction-provenance: {"artifact_sha256": "2c5e99d161382309f2e5bf1bda14dc998e567bc7f5ee91b34b594a95d570b2c3", "source_sha256": "4c4552ce0adb2754080969f00b761c1c118766771e0595b8c9b416ee0842fbae", "target_language": "perl5"}
# find-sessions.sh — portiert nach perl5
# Quelle: shell, workspace@local:skills/github-clones/openclaw/skills/tmux/scripts/find-sessions.sh
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use Getopt::Long qw(GetOptions);
use Pod::Usage qw(pod2usage);

my $socket_name = "";
my $socket_path = "";
my $query = "";
my $scan_all = 0;
my $help = 0;

my $socket_dir = $ENV{OPENCLAW_TMUX_SOCKET_DIR} // ($ENV{TMPDIR} // "/tmp") . "/openclaw-tmux-sockets";

GetOptions(
    "L|socket=s" => \$socket_name,
    "S|socket-path=s" => \$socket_path,
    "A|all" => \$scan_all,
    "q|query=s" => \$query,
    "h|help" => \$help,
) or pod2usage(2);

if ($help) {
    pod2usage(1);
}

if ($scan_all && ($socket_name ne "" || $socket_path ne "")) {
    print STDERR "Cannot combine --all with -L or -S\n";
    exit 1;
}

if ($socket_name ne "" && $socket_path ne "") {
    print STDERR "Use either -L or -S, not both\n";
    exit 1;
}

# Check if tmux is available
my $tmux_found = 0;
for my $path (split /:/, $ENV{PATH}) {
    if (-x "$path/tmux") {
        $tmux_found = 1;
        last;
    }
}
if (!$tmux_found) {
    print STDERR "tmux not found in PATH\n";
    exit 1;
}

sub list_sessions {
    my ($label, @tmux_args) = @_;
    my @cmd = ("tmux", @tmux_args, "list-sessions", "-F", '#{session_name}\t#{session_attached}\t#{session_created_string}');
    
    # Capture output and errors
    my $output = "";
    my $error = "";
    my $pid = open(my $fh, "-|", @cmd);
    if (!defined $pid) {
        print STDERR "Failed to run tmux command\n";
        return 1;
    }

    while (my $line = <$fh>) {
        $output .= $line;
    }
    close($fh);
    my $exit_status = $?;

    if ($exit_status != 0) {
        print STDERR "No tmux server found on $label\n";
        return 1;
    }

    chomp $output;
    my @lines = split /\n/, $output;

    # Filter by query if provided
    if ($query ne "") {
        @lines = grep { lc($_) =~ lc($query) } @lines;
    }

    if (@lines == 0) {
        print "No sessions found on $label\n";
        return 0;
    }

    print "Sessions on $label:\n";
    for my $line (@lines) {
        chomp $line;
        my ($name, $attached, $created) = split /\t/, $line;
        my $attached_label = ($attached eq "1") ? "attached" : "detached";
        printf '  - %s (%s, started %s)%s', $name, $attached_label, $created, "\n";
    }
    return 0;
}

if ($scan_all) {
    if (!-d $socket_dir) {
        print STDERR "Socket directory not found: $socket_dir\n";
        exit 1;
    }

    opendir(my $dh, $socket_dir) or die "Could not open directory '$socket_dir': $!";
    my @sockets = map { "$socket_dir/$_" } grep { -S "$socket_dir/$_" } readdir($dh);
    closedir($dh);

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

# Remove the first element ("tmux") before passing the rest as arguments
shift @tmux_cmd;
list_sessions($socket_label, @tmux_cmd);

__END__

=head1 NAME

find-sessions.pl - List tmux sessions on a socket

=head1 SYNOPSIS

find-sessions.pl [options]

 Options:
   -L, --socket       tmux socket name (passed to tmux -L)
   -S, --socket-path  tmux socket path (passed to tmux -S)
   -A, --all          scan all sockets under OPENCLAW_TMUX_SOCKET_DIR
   -q, --query        case-insensitive substring to filter session names
   -h, --help         show this help

=head1 DESCRIPTION

List tmux sessions on a socket (default tmux socket if none provided).

=cut
