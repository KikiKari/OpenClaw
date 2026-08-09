#!/usr/bin/env perl
use strict;
use warnings;

# OpenClaw gateway router — upstream node selection (port of nginx-gateway)
my @nodes = ( 'gateway1.openclaw.internal', 'gateway2.openclaw.internal' );
my $target = $nodes[ int( rand(@nodes) ) ];
print "OpenClaw routing to: $target\n";
