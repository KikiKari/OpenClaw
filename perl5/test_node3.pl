#!/usr/bin/perl
# test_node3.sh — portiert nach perl5
# Quelle: shell, OpenClaw@gateway1:scripts/test_node3.sh
# auch in: OpenClaw@gateway2:scripts/test_node3.sh
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use Env qw(@PATH);
use IPC::Run3;

# Test Node 3 Connection
$ENV{OPENCLAW_ALLOW_INSECURE_PRIVATE_WS} = 1;
print "Starting node connection test...\n";

my @cmd = ('/usr/local/bin/openclaw', 'node', 'run', '--host', '152.53.145.65', '--port', '18789');
my ($stdin, $stdout, $stderr);

eval {
    local $SIG{ALRM} = sub { die "timeout\n" };
    alarm(15);
    run3(\@cmd, \$stdin, \$stdout, \$stderr);
    alarm(0);
};

if ($@) {
    if ($@ eq "timeout\n") {
        print "Command timed out\n";
        exit 1;
    } else {
        die $@;
    }
}

print $stdout if defined $stdout;
print $stderr if defined $stderr;

print "Exit code: " . ($? >> 8) . "\n";
