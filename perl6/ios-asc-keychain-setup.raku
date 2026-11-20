#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "8575e2506b967003fc634716bcc93c4ba41c4627f79e0be6fc2522b1794b9e99", "source_sha256": "3c82de39b963e31592918456342c499f4e6477d2ee7404f215a5685c6d02674c", "target_language": "perl6"}
# ios-asc-keychain-setup.sh — portiert nach perl6
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/ios-asc-keychain-setup.sh
# Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

use v6;

sub usage() {
    say q:to/EOF/;
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
}

sub upsert-env-line($file, $key, $value) {
    my $tmp = $*TMPDIR ~ '/' ~ (^10).map({ ('a'..'z').pick }).join('');
    
    if $file.IO.e {
        my @lines = $file.IO.lines;
        my $found = False;
        my @new-lines = @lines.map({
            if /^$key '='/ {
                $found = True;
                "$key=$value";
            } else {
                $_;
            }
        });
        unless $found {
            @new-lines.push("$key=$value");
        }
        spurt $tmp, @new-lines.join("\n") ~ "\n";
    } else {
        spurt $tmp, "$key=$value\n";
    }
    
    move $tmp, $file;
}

sub delete-env-line($file, $key) {
    my $tmp = $*TMPDIR ~ '/' ~ (^10).map({ ('a'..'z').pick }).join('');
    
    if !$file.IO.e {
        return;
    }
    
    my @lines = $file.IO.lines.grep({ !/^$key '='/ });
    spurt $tmp, @lines.join("\n") ~ "\n";
    
    move $tmp, $file;
}

my $KEY_PATH = "";
my $KEY_ID = "";
my $ISSUER_ID = "";
my $SERVICE = "openclaw-asc-key";
my $ACCOUNT = %*ENV<USER> // %*ENV<LOGNAME> // "";
my $WRITE_ENV = 0;
my $ENV_FILE = "";

my $REPO_ROOT = $*PROGRAM.parent(2).Str;
my $DEFAULT_ENV_FILE = "$REPO_ROOT/apps/ios/fastlane/.env";

while @*ARGS {
    given @*ARGS.shift {
        when '--key-path' {
            $KEY_PATH = @*ARGS.shift // "";
        }
        when '--key-id' {
            $KEY_ID = @*ARGS.shift // "";
        }
        when '--issuer-id' {
            $ISSUER_ID = @*ARGS.shift // "";
        }
        when '--service' {
            $SERVICE = @*ARGS.shift // "";
        }
        when '--account' {
            $ACCOUNT = @*ARGS.shift // "";
        }
        when '--write-env' {
            $WRITE_ENV = 1;
        }
        when '--env-file' {
            $ENV_FILE = @*ARGS.shift // "";
        }
        when '-h'|'--help' {
            usage();
            exit 0;
        }
        default {
            note "Unknown argument: $_";
            usage();
            exit 1;
        }
    }
}

if !$KEY_PATH || !$ISSUER_ID {
    note "Missing required arguments.";
    usage();
    exit 1;
}

if !$KEY_PATH.IO.e {
    note "Key file not found: $KEY_PATH";
    exit 1;
}

if !$KEY_ID {
    my $key_filename = $KEY_PATH.IO.basename;
    if $key_filename ~~ /^AuthKey_(<[\w]>+) \. p8$/ {
        $KEY_ID = $/[0].Str;
    } else {
        note "Could not infer --key-id from filename '$key_filename'. Pass --key-id explicitly.";
        exit 1;
    }
}

if !$ACCOUNT {
    note "Could not determine Keychain account. Pass --account explicitly.";
    exit 1;
}

my $KEY_CONTENT = $KEY_PATH.IO.slurp.chomp;
if !$KEY_CONTENT {
    note "Key file is empty: $KEY_PATH";
    exit 1;
}

# Simulate security command using shell since there's no direct Raku equivalent
shell("security add-generic-password -a '$ACCOUNT' -s '$SERVICE' -w '$KEY_CONTENT' -U", :out</dev/null>, :err</dev/null>);

say "Stored ASC API private key in macOS Keychain (service='$SERVICE', account='$ACCOUNT').";
say "";
say "Export these vars for Fastlane:";
say "ASC_KEY_ID=$KEY_ID";
say "ASC_ISSUER_ID=$ISSUER_ID";
say "ASC_KEYCHAIN_SERVICE=$SERVICE";
say "ASC_KEYCHAIN_ACCOUNT=$ACCOUNT";

if $WRITE_ENV == 1 {
    if !$ENV_FILE {
        $ENV_FILE = $DEFAULT_ENV_FILE;
    }
    
    my $env-dir = $ENV_FILE.IO.dirname;
    unless $env-dir.IO.e {
        shell("mkdir -p '$env-dir'");
    }
    
    unless $ENV_FILE.IO.e {
        $ENV_FILE.IO.spurt("");
    }
    
    upsert-env-line($ENV_FILE, "ASC_KEY_ID", $KEY_ID);
    upsert-env-line($ENV_FILE, "ASC_ISSUER_ID", $ISSUER_ID);
    upsert-env-line($ENV_FILE, "ASC_KEYCHAIN_SERVICE", $SERVICE);
    upsert-env-line($ENV_FILE, "ASC_KEYCHAIN_ACCOUNT", $ACCOUNT);
    # Remove file/path based keys so Keychain is used by default.
    delete-env-line($ENV_FILE, "ASC_KEY_PATH");
    delete-env-line($ENV_FILE, "ASC_KEY_CONTENT");
    delete-env-line($ENV_FILE, "APP_STORE_CONNECT_API_KEY_PATH");
    
    say "";
    say "Updated env file: $ENV_FILE";
}
