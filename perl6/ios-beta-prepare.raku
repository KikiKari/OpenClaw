#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "8033bdf2e1051b35dc1401181627511c6f46a6872c28fe499728b7b33335af49", "source_sha256": "2ca708f3e5a694b78eb83d1e37cf5eefe3e601ebec3e31d771a7ebd4246aa33c", "target_language": "perl6"}
# ios-beta-prepare.sh — portiert nach perl6
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/ios-beta-prepare.sh
# Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

use v6;

sub usage() {
    say q:to/EOF/;
Usage:
  OPENCLAW_PUSH_RELAY_BASE_URL=https://relay.example.com \
    scripts/ios-beta-prepare.sh --build-number 7 [--team-id TEAMID]

Prepares local beta-release inputs without touching local signing overrides:
- reads apps/ios/version.json and writes apps/ios/build/Version.xcconfig
- writes apps/ios/build/BetaRelease.xcconfig with canonical bundle IDs
- configures the beta build for relay-backed APNs registration
- regenerates apps/ios/OpenClaw.xcodeproj via xcodegen
EOF
}

my $ROOT_DIR = IO::Path.new($*PROGRAM).parent(2).absolute;
my $IOS_DIR = "$ROOT_DIR/apps/ios";
my $BUILD_DIR = "$IOS_DIR/build";
my $BETA_XCCONFIG = "$IOS_DIR/build/BetaRelease.xcconfig";
my $TEAM_HELPER = "$ROOT_DIR/scripts/ios-team-id.sh";
my $VERSION_HELPER = "$ROOT_DIR/scripts/ios-write-version-xcconfig.sh";
my $IOS_VERSION_HELPER = "$ROOT_DIR/scripts/ios-version.ts";
my $VERSION_SYNC_HELPER = "$ROOT_DIR/scripts/ios-sync-versioning.ts";

my $BUILD_NUMBER = "";
my $TEAM_ID = %*ENV<IOS_DEVELOPMENT_TEAM> // "";
my $PUSH_RELAY_BASE_URL = %*ENV<OPENCLAW_PUSH_RELAY_BASE_URL> // %*ENV<IOS_PUSH_RELAY_BASE_URL> // "";
my $PUSH_RELAY_BASE_URL_XCCONFIG = "";
my $IOS_VERSION = "";

sub prepare-build-dir() {
    if IO::Path.new($BUILD_DIR).l {
        note "Refusing to use symlinked build directory: $BUILD_DIR";
        exit 1;
    }
    
    IO::Path.new($BUILD_DIR).mkdir;
}

sub write-generated-file(Str $output-path) {
    my $path = IO::Path.new($output-path);
    if $path.e && $path.l {
        note "Refusing to overwrite symlinked file: $output-path";
        exit 1;
    }
    
    my $tmp-file = "$output-path." ~ (100000..999999).pick;
    my $fh = open($tmp-file, :w);
    $fh.print($*IN.slurp-rest);
    $fh.close;
    IO::Path.new($tmp-file).rename($output-path);
}

sub validate-push-relay-base-url(Str $value) {
    if $value ~~ /\s/ {
        note "Invalid OPENCLAW_PUSH_RELAY_BASE_URL: whitespace is not allowed.";
        exit 1;
    }
    
    if $value ~~ /[\$|\(|\)|\=]/ {
        note "Invalid OPENCLAW_PUSH_RELAY_BASE_URL: contains forbidden xcconfig characters.";
        exit 1;
    }
    
    unless $value ~~ /^ 'https://' [\w+ '.' \w+]+ [':' (\d ** 1..5)]? ['/' [\w|'.'|'_'|'~'|'!'|'&'|'*'|'+'|','|';'|':'|'@'|'%'|'/'|'-']*]? $/ {
        note "Invalid OPENCLAW_PUSH_RELAY_BASE_URL: expected https://host[:port][/path].";
        exit 1;
    }
    
    my $port = $0 // "";
    if $port.chars > 0 && +$port > 65535 {
        note "Invalid OPENCLAW_PUSH_RELAY_BASE_URL: port must be between 1 and 65535.";
        exit 1;
    }
}

sub MAIN(*@ARGS) {
    my @args = @ARGS;
    
    while @args {
        given @args[0] {
            when "--" {
                @args.shift;
            }
            when "--build-number" {
                $BUILD_NUMBER = @args[1] // "";
                @args.shift; @args.shift;
            }
            when "--team-id" {
                $TEAM_ID = @args[1] // "";
                @args.shift; @args.shift;
            }
            when "-h"|"--help" {
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
    
    if $BUILD_NUMBER eq "" {
        note "Missing required --build-number.";
        usage();
        exit 1;
    }
    
    if $TEAM_ID eq "" {
        my $proc = run("bash", $TEAM_HELPER, :env(
            IOS_ALLOW_KEYCHAIN_TEAM_FALLBACK => "1"
        ), :out);
        $TEAM_ID = $proc.out.slurp.chomp;
    }
    
    if $TEAM_ID eq "" {
        note "Could not resolve Apple Team ID. Set IOS_DEVELOPMENT_TEAM or sign into Xcode.";
        exit 1;
    }
    
    if $PUSH_RELAY_BASE_URL eq "" {
        note "Missing OPENCLAW_PUSH_RELAY_BASE_URL (or IOS_PUSH_RELAY_BASE_URL) for beta relay registration.";
        exit 1;
    }
    
    validate-push-relay-base-url($PUSH_RELAY_BASE_URL);
    
    # `.xcconfig` treats `//` as a comment opener. Break the URL with a helper setting
    # so Xcode still resolves it back to `https://...` at build time.
    $PUSH_RELAY_BASE_URL_XCCONFIG = $PUSH_RELAY_BASE_URL.subst("//", '$(OPENCLAW_URL_SLASH)$(OPENCLAW_URL_SLASH)', :g);
    
    prepare-build-dir();
    
    my $sync-proc = run("node", "--import", "tsx", $VERSION_SYNC_HELPER, "--check", :cwd($ROOT_DIR));
    $sync-proc.wait;
    
    my $version-proc = run("node", "--import", "tsx", $IOS_VERSION_HELPER, "--field", "canonicalVersion", :cwd($ROOT_DIR), :out);
    $IOS_VERSION = $version-proc.out.slurp.chomp;
    
    if $IOS_VERSION eq "" {
        note "Unable to resolve iOS version from $ROOT_DIR/apps/ios/version.json.";
        exit 1;
    }
    
    run("bash", $VERSION_HELPER, "--build-number", $BUILD_NUMBER);
    
    my $fh = IO::Handle.new;
    $fh.open($BETA_XCCONFIG, :w) or die "Cannot open $BETA_XCCONFIG";
    $fh.say(qq:to/EOF/);
// Auto-generated by scripts/ios-beta-prepare.sh.
// Local beta-release override; do not commit.
OPENCLAW_CODE_SIGN_STYLE = Automatic
OPENCLAW_DEVELOPMENT_TEAM = $TEAM_ID
OPENCLAW_IOS_SELECTED_TEAM = $TEAM_ID
OPENCLAW_APP_BUNDLE_ID = ai.openclaw.client
OPENCLAW_SHARE_BUNDLE_ID = ai.openclaw.client.share
OPENCLAW_ACTIVITY_WIDGET_BUNDLE_ID = ai.openclaw.client.activitywidget
OPENCLAW_WATCH_APP_BUNDLE_ID = ai.openclaw.client.watchkitapp
OPENCLAW_WATCH_EXTENSION_BUNDLE_ID = ai.openclaw.client.watchkitapp.extension
OPENCLAW_APP_PROFILE =
OPENCLAW_SHARE_PROFILE =
OPENCLAW_PUSH_TRANSPORT = relay
OPENCLAW_PUSH_DISTRIBUTION = official
OPENCLAW_URL_SLASH = /
OPENCLAW_PUSH_RELAY_BASE_URL = $PUSH_RELAY_BASE_URL_XCCONFIG
OPENCLAW_PUSH_APNS_ENVIRONMENT = production
EOF
    $fh.close;
    
    my $xcodegen-proc = run("xcodegen", "generate", :cwd($IOS_DIR));
    $xcodegen-proc.wait;
    
    say "Prepared iOS beta release: version=$IOS_VERSION build=$BUILD_NUMBER team=$TEAM_ID";
    say "XCODE_XCCONFIG_FILE=$BETA_XCCONFIG";
}
