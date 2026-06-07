#!/usr/bin/env perl
use strict;
use warnings;
use IO::Socket::INET;

# OpenClaw TCP port probe (Perl) — checks gateway nodes
sub probe {
    my ($host, $port) = @_;
    my $sock = IO::Socket::INET->new(
        PeerHost => $host,
        PeerPort => $port,
        Proto    => 'tcp',
        Timeout  => 3,
    );
    if ($sock) {
        close($sock);
        return 1;
    }
    return 0;
}

my @nodes = ( [ 'localhost', 8080 ], [ 'localhost', 8081 ] );
for my $n (@nodes) {
    my ( $host, $port ) = @$n;
    printf "%s %s:%d\n", probe( $host, $port ) ? 'OK  ' : 'FAIL', $host, $port;
}
