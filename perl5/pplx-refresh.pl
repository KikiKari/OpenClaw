#!/usr/bin/env perl
# pplx-refresh.sh — portiert nach perl5
# Quelle: shell, OpenClaw@main:scripts/pplx-tools/pplx-refresh.sh
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use File::Spec;
use JSON;

# Refresh the codespace Perplexity session from a locally-exported cookie.
#
# Usage:
#   ./pplx-refresh.pl [cookie-file]
#
# cookie-file defaults to ~/pplx-cookies.txt. Put your local browser's
# __Secure-next-auth.session-token value (raw), or the whole Cookie header,
# or a JSON cookie export, into that file first.
#
# Steps: ensure daemon browser -> read daemon passphrase -> inject into vault
#        -> trigger reinit -> verify authenticated.

my $here = dirname(abs_path($0));
my $cfg = $ENV{PERPLEXITY_CONFIG_DIR} // "$ENV{HOME}/.perplexity-mcp";
my $profile = $ENV{PERPLEXITY_PROFILE} // "codespace";
my $cookie_file = $ARGV[0] // "$ENV{HOME}/pplx-cookies.txt";

unless (-s $cookie_file) {
    print STDERR "✗ Cookie file empty/missing: $cookie_file\n";
    print STDERR "  Export __Secure-next-auth.session-token from your local browser\n";
    print STDERR "  (DevTools → Application → Cookies → www.perplexity.ai) into that file.\n";
    exit 1;
}

# 1. ensure the extension daemon has a usable browser (idempotent)
system("bash", "$here/pplx-setup.sh");
die "Failed to run pplx-setup.sh" if $? != 0;

# 2. daemon pid + vault passphrase (never guessed — read from the live daemon)
my $lock = "$cfg/daemon.lock";
unless (-f $lock) {
    print STDERR "✗ no daemon.lock at $lock — is the extension running?\n";
    exit 1;
}

open my $fh, '<', $lock or die "Cannot open $lock: $!";
my $json_text = do { local $/; <$fh> };
close $fh;
my $data = decode_json($json_text);
my $pid = $data->{pid};

unless (kill 0, $pid) {
    print STDERR "✗ daemon pid $pid not running\n";
    exit 1;
}

# Read environment variables of process
my $environ_path = "/proc/$pid/environ";
open $fh, '<', $environ_path or die "Cannot open $environ_path: $!";
{
    local $/;
    $json_text = <$fh>;
}
close $fh;

my @env_vars = split /\0/, $json_text;
my $pass = '';
for my $var (@env_vars) {
    if ($var =~ /^PERPLEXITY_VAULT_PASSPHRASE=(.*)$/) {
        $pass = $1;
        last;
    }
}

unless ($pass) {
    print STDERR "✗ no PERPLEXITY_VAULT_PASSPHRASE in daemon env\n";
    exit 1;
}

# 3. locate the perplexity-user-mcp dist (populate npx cache if needed)
my $dist = '';
my @dirs = glob("$ENV{HOME}/.npm/_npx/*/perplexity-user-mcp/dist");
if (@dirs) {
    $dist = $dirs[0];
} else {
    system("npx", "-y", "perplexity-user-mcp", "--version");
    @dirs = glob("$ENV{HOME}/.npm/_npx/*/perplexity-user-mcp/dist");
    $dist = $dirs[0] if @dirs;
}

# 4. inject
$ENV{PERPLEXITY_VAULT_PASSPHRASE} = $pass;
$ENV{PERPLEXITY_CONFIG_DIR} = $cfg;
$ENV{PERPLEXITY_PROFILE} = $profile;
$ENV{PPLX_DIST} = $dist;

system("node", "$here/pplx-inject.mjs", $cookie_file);
die "Failed to run pplx-inject.mjs" if $? != 0;

# 5. trigger daemon reinit
my $reinit_file = "$cfg/profiles/$profile/.reinit";
open $fh, '>', $reinit_file or die "Cannot write to $reinit_file: $!";
print $fh time(), "\n";
close $fh;
print "→ reinit triggered, waiting for daemon...\n";

# 6. verify
my $stat = "$cfg/profiles/$profile/daemon-status.json";
for my $i (1..20) {
    sleep(1.5);
    my $auth = '';
    my $tier = '';
    if (-f $stat) {
        open $fh, '<', $stat or next;
        {
            local $/;
            $json_text = <$fh>;
        }
        close $fh;
        eval {
            my $status_data = decode_json($json_text);
            $auth = $status_data->{authenticated} // '';
            $tier = $status_data->{tier} // '';
        };
        if ($@) {
            warn "JSON parse error: $@\n";
        }
    }
    if ($auth eq 'True') {
        print "✅ authenticated — tier: $tier\n";
        exit 0;
    }
}
print STDERR "⚠️  not authenticated yet. Check: tail -20 $cfg/daemon.log\n";
exit 1;
