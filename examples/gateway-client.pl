#!/usr/bin/env perl
use strict;
use warnings;
use HTTP::Tiny;

# OpenClaw Gateway Client (Perl)
sub check_gateway {
    my ($base_url) = @_;
    my $response = HTTP::Tiny->new( timeout => 5 )->get("$base_url/health");
    return $response->{status};
}

my $url = $ARGV[0] // 'http://localhost:8080';
printf "Gateway %s -> HTTP %s\n", $url, check_gateway($url);
