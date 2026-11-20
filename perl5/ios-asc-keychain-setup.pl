#!/usr/bin/env perl
# abstraction-provenance: {"artifact_sha256": "a6a5967e7a73d7d9c453b0f700c8b48cc1b971c1f2a36925278f5ae202767f3a", "source_sha256": "3c82de39b963e31592918456342c499f4e6477d2ee7404f215a5685c6d02674c", "target_language": "perl5"}
# ios-asc-keychain-setup.sh — portiert nach perl5
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/ios-asc-keychain-setup.sh
# Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Basename;
use File::Path qw(make_path);
use File::Temp qw(tempfile);

sub usage {
    print <<'EOF';
Usage:
  scripts/ios-asc-keychain-setup.sh --key-path /path/to/AuthKey_XXXXXX.p8 --issuer-id <issuer-uuid> [options]

Required:
  --key-path <path>      Path to App Store Connect API key (.p8)
  --issuer-id <uuid>     App Store Connect issuer ID

Optional:
  --key-id <id>          API key ID (auto-detected from AuthKey_<id>.p8 if omitted)
  --service <name>       Keychain service name (default: openclaw-asc-key)
  --account <name>       Keychain account name (default: $USER or $LOGNAME)
  --write-env            Upsert non-secret env vars into apps/ios/fastlane/.env
  --env-file <path>      Override env file path used with --write-env
  -h, --help             Show this help

Example:
  scripts/ios-asc-keychain-setup.sh \
    --key-path "$HOME/keys/AuthKey_ABC1234567.p8" \
    --issuer-id "00000000-1111-2222-3333-444444444444" \
    --write-env
EOF
    exit 0;
}

sub upsert_env_line {
    my ($file, $key, $value) = @_;
    my ($fh, $tmp) = tempfile();

    if (-f $file) {
        open my $in, '<', $file or die "Cannot open $file: $!";
        my $updated = 0;
        while (my $line = <$in>) {
            chomp $line;
            if ($line =~ /^$key=/) {
                print $fh "$key=$value\n";
                $updated = 1;
            } else {
                print $fh "$line\n";
            }
        }
        close $in;
        print $fh "$key=$value\n" unless $updated;
    } else {
        print $fh "$key=$value\n";
    }
    close $fh;
    rename $tmp, $file or die "Cannot rename $tmp to $file: $!";
}

sub delete_env_line {
    my ($file, $key) = @_;
    return unless -f $file;
    my ($fh, $tmp) = tempfile();
    open my $in, '<', $file or die "Cannot open $file: $!";
    while (my $line = <$in>) {
        chomp $line;
        print $fh "$line\n" unless $line =~ /^$key=/;
    }
    close $in;
    close $fh;
    rename $tmp, $file or die "Cannot rename $tmp to $file: $!";
}

my $KEY_PATH = "";
my $KEY_ID = "";
my $ISSUER_ID = "";
my $SERVICE = "openclaw-asc-key";
my $ACCOUNT = $ENV{USER} || $ENV{LOGNAME} || "";
my $WRITE_ENV = 0;
my $ENV_FILE = "";

my $script_dir = dirname($0);
my $REPO_ROOT = dirname($script_dir);
my $DEFAULT_ENV_FILE = "$REPO_ROOT/apps/ios/fastlane/.env";

while (@ARGV) {
    my $arg = shift @ARGV;
    if ($arg eq "--key-path") {
        $KEY_PATH = shift @ARGV;
    } elsif ($arg eq "--key-id") {
        $KEY_ID = shift @ARGV;
    } elsif ($arg eq "--issuer-id") {
        $ISSUER_ID = shift @ARGV;
    } elsif ($arg eq "--service") {
        $SERVICE = shift @ARGV;
    } elsif ($arg eq "--account") {
        $ACCOUNT = shift @ARGV;
    } elsif ($arg eq "--write-env") {
        $WRITE_ENV = 1;
    } elsif ($arg eq "--env-file") {
        $ENV_FILE = shift @ARGV;
    } elsif ($arg eq "-h" || $arg eq "--help") {
        usage();
    } else {
        warn "Unknown argument: $arg\n";
        usage();
        exit 1;
    }
}

if (!$KEY_PATH || !$ISSUER_ID) {
    warn "Missing required arguments.\n";
    usage();
    exit 1;
}

if (!-f $KEY_PATH) {
    warn "Key file not found: $KEY_PATH\n";
    exit 1;
}

if (!$KEY_ID) {
    my $key_filename = basename($KEY_PATH);
    if ($key_filename =~ /^AuthKey_([A-Za-z0-9]+)\.p8$/) {
        $KEY_ID = $1;
    } else {
        warn "Could not infer --key-id from filename '$key_filename'. Pass --key-id explicitly.\n";
        exit 1;
    }
}

if (!$ACCOUNT) {
    warn "Could not determine Keychain account. Pass --account explicitly.\n";
    exit 1;
}

open my $fh, '<', $KEY_PATH or die "Cannot open $KEY_PATH: $!";
my $KEY_CONTENT = do { local $/; <$fh> };
close $fh;

if (!$KEY_CONTENT) {
    warn "Key file is empty: $KEY_PATH\n";
    exit 1;
}

# Store in keychain using security command
system("security", "add-generic-password", "-a", $ACCOUNT, "-s", $SERVICE, "-w", $KEY_CONTENT, "-U") == 0
    or die "Failed to store key in keychain: $?";

print "Stored ASC API private key in macOS Keychain (service='$SERVICE', account='$ACCOUNT').\n";
print "\n";
print "Export these vars for Fastlane:\n";
print "ASC_KEY_ID=$KEY_ID\n";
print "ASC_ISSUER_ID=$ISSUER_ID\n";
print "ASC_KEYCHAIN_SERVICE=$SERVICE\n";
print "ASC_KEYCHAIN_ACCOUNT=$ACCOUNT\n";

if ($WRITE_ENV) {
    if (!$ENV_FILE) {
        $ENV_FILE = $DEFAULT_ENV_FILE;
    }

    my $env_dir = dirname($ENV_FILE);
    make_path($env_dir) unless -d $env_dir;
    open my $touch_fh, '>>', $ENV_FILE or die "Cannot touch $ENV_FILE: $!";
    close $touch_fh;

    upsert_env_line($ENV_FILE, "ASC_KEY_ID", $KEY_ID);
    upsert_env_line($ENV_FILE, "ASC_ISSUER_ID", $ISSUER_ID);
    upsert_env_line($ENV_FILE, "ASC_KEYCHAIN_SERVICE", $SERVICE);
    upsert_env_line($ENV_FILE, "ASC_KEYCHAIN_ACCOUNT", $ACCOUNT);
    # Remove file/path based keys so Keychain is used by default.
    delete_env_line($ENV_FILE, "ASC_KEY_PATH");
    delete_env_line($ENV_FILE, "ASC_KEY_CONTENT");
    delete_env_line($ENV_FILE, "APP_STORE_CONNECT_API_KEY_PATH");

    print "\n";
    print "Updated env file: $ENV_FILE\n";
}
