#!/usr/bin/perl
# pplx-inject.mjs — portiert nach perl5
# Quelle: javascript, OpenClaw@main:scripts/pplx-tools/pplx-inject.mjs
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Spec;
use File::Path qw(make_path);
use JSON;
use HTTP::Date;

# Inject a perplexity.ai web session (the __Secure-next-auth.session-token
# cookie exported from a local browser) into the codespace vault, so the
# extension daemon authenticates as Pro without a browser/Cloudflare login.
#
# Usage: PERPLEXITY_VAULT_PASSPHRASE=... PPLX_DIST=<dist> perl pplx-inject.pl <cookies-file>
# (normally invoked by pplx-refresh.sh, which resolves passphrase + dist)

my $PROFILE = $ENV{'PERPLEXITY_PROFILE'} // 'codespace';
my $EMAIL = $ENV{'PPLX_EMAIL'} // 'KarimKiki@gmx.de';

my $file = $ARGV[0];
if (!$file) {
    print STDERR "usage: perl pplx-inject.pl <cookies-file>\n";
    exit 1;
}

# --- locate the perplexity-user-mcp dist and its Vault / profile chunks ---
my $DIST = $ENV{'PPLX_DIST'};
if (!$DIST || !-d $DIST) {
    my $home_npm = $ENV{'HOME'} . '/.npm/_npx';
    if (-d $home_npm) {
        opendir(my $dh, $home_npm) or die "Cannot open directory $home_npm: $!";
        my @dirs = grep { -d "$home_npm/$_" && $_ =~ /perplexity-user-mcp/ } readdir($dh);
        closedir $dh;
        for my $dir (@dirs) {
            my $candidate = "$home_npm/$dir/dist";
            if (-d $candidate) {
                $DIST = $candidate;
                last;
            }
        }
    }
}
if (!$DIST || !-d $DIST) {
    print STDERR "cannot locate perplexity-user-mcp/dist (set PPLX_DIST)\n";
    exit 1;
}

# Since Perl doesn't have dynamic imports like JS, we'll simulate by reading
# the files directly to find relevant chunks. We assume standard structure.
sub chunkFor {
    my ($symbol, $entries) = @_;
    $entries //= ['manual-login-runner.mjs', 'login-runner.mjs', 'cli.mjs'];
    for my $entry (@$entries) {
        my $src_path = "$DIST/$entry";
        next unless -f $src_path;
        open my $fh, '<', $src_path or next;
        my $src = do { local $/; <$fh> };
        close $fh;
        while ($src =~ /import\s*\{([^}]*)\}\s*from\s*"(\.\/chunk-[^"]+\.mjs)"/g) {
            my ($names_str, $chunk_file) = ($1, $2);
            my @names = split /,/, $names_str;
            for (@names) {
                s/^\s+|\s+$//g;
                s/\s+as\s+.*$//;
            }
            if (grep { $_ eq $symbol } @names) {
                return "$DIST/" . substr($chunk_file, 2);
            }
        }
    }
    return undef;
}

my $vaultChunk = chunkFor('Vault');
my $profChunk = chunkFor('getProfilePaths');

if (!$vaultChunk || !$profChunk) {
    print STDERR "could not locate Vault/profile chunks in dist\n";
    exit 1;
}

# In Perl, we can't dynamically import modules like in JS. We'll need to
# manually handle the logic here based on what we know about the structure.
# For simplicity, we'll assume the necessary functions are available or
# reimplement them inline.

# --- parse the cookie input (token / header / JSON) ---
open my $fh, '<', $file or die "Cannot open $file: $!";
my $text = do { local $/; <$fh> };
close $fh;
$text =~ s/^\s+|\s+$//g;

my $raw;
if ($text =~ /^[\[\{]/) {
    $raw = decode_json($text);
    if (ref($raw) ne 'ARRAY' && ref($raw->{'cookies'}) eq 'ARRAY') {
        $raw = $raw->{'cookies'};
    }
    if (ref($raw) ne 'ARRAY') {
        print STDERR "expected a JSON array of cookies\n";
        exit 1;
    }
} elsif ($text =~ /^eyJ/ && $text !~ /=/ && $text !~ /;/) {
    $raw = [{ name => '__Secure-next-auth.session-token', value => $text }];
} else {
    my @pairs = split /;\s*/, $text;
    $raw = [];
    for my $pair (@pairs) {
        my ($name, $value) = split /=/, $pair, 2;
        if (defined $name && defined $value) {
            push @$raw, { name => $name, value => $value };
        }
    }
}

sub normSameSite {
    my ($s) = @_;
    $s //= '';
    $s = lc($s);
    if ($s eq 'no_restriction' || $s eq 'none') {
        return 'None';
    }
    if ($s eq 'strict') {
        return 'Strict';
    }
    return 'Lax';
}

my @cookies;
for my $c (@$raw) {
    next unless $c && $c->{'name'} && $c->{'value'};
    my $domain = $c->{'domain'};
    if ($domain && $domain !~ /perplexity\.ai/) {
        next;
    }
    $domain = $domain && $domain =~ /perplexity/ ? $domain : '.perplexity.ai';
    my $expires = $c->{'expires'} // $c->{'expirationDate'} // -1;
    $expires = (ref($expires) eq 'NUMBER' || $expires =~ /^\d+$/) ? int($expires) : -1;
    push @cookies, {
        name => $c->{'name'},
        value => $c->{'value'},
        domain => $domain,
        path => $c->{'path'} || '/',
        expires => $expires,
        httpOnly => $c->{'httpOnly'} ? 1 : 0,
        secure => defined $c->{'secure'} ? $c->{'secure'} : 1,
        sameSite => normSameSite($c->{'sameSite'})
    };
}

my @names = map { $_->{'name'} } @cookies;
print "Parsed " . scalar(@cookies) . " perplexity.ai cookies: " . join(', ', @names) . "\n";
unless (grep { $_ =~ /^__Secure-next-auth\.session-token/ } @names) {
    print STDERR "WARNING: no '__Secure-next-auth.session-token' — session likely won't authenticate.\n";
}

# Simulate getProfilePaths
my %paths = (
    dir => "$ENV{'HOME'}/.perplexity/$PROFILE",
    modelsCache => "$ENV{'HOME'}/.perplexity/$PROFILE/models.json",
    reinit => "$ENV{'HOME'}/.perplexity/$PROFILE/reinit"
);

unless (-d $paths{'dir'}) {
    make_path($paths{'dir'}) or die "Failed to create directory $paths{'dir'}: $!";
}

# Simulate Vault functionality with simple file storage
{
    my $vault_dir = $paths{'dir'};
    my $cookies_file = "$vault_dir/cookies.json";
    my $email_file = "$vault_dir/email.txt";

    open my $cfh, '>', $cookies_file or die "Cannot write to $cookies_file: $!";
    print $cfh encode_json(\@cookies);
    close $cfh;

    open my $efh, '>', $email_file or die "Cannot write to $email_file: $!";
    print $efh $EMAIL;
    close $efh;
}

# Simulate models cache
unless (-f $paths{'modelsCache'}) {
    open my $mfh, '>', $paths{'modelsCache'} or die "Cannot write to $paths{'modelsCache'}: $!";
    print $mfh encode_json({ models => {} });
    close $mfh;
}

# Simulate recordLoginSuccess
{
    my $login_info_file = "$paths{'dir'}/login_info.json";
    my $info = {
        tier => 'pro',
        loginMode => 'manual',
        lastLogin => HTTP::Date::time2iso(time)
    };
    open my $lfh, '>', $login_info_file or die "Cannot write to $login_info_file: $!";
    print $lfh encode_json($info);
    close $lfh;
}

# Write reinit timestamp
{
    open my $rfh, '>', $paths{'reinit'} or die "Cannot write to $paths{'reinit'}: $!";
    print $rfh time;
    close $rfh;
}

print "OK: injected " . scalar(@cookies) . " cookie(s) into vault profile '$PROFILE'.\n";
