#!/usr/bin/perl
# test_mobile_projects.py — portiert nach perl5
# Quelle: python, Projects@TikTok-Live-Companion:plugin-source/scripts/test_mobile_projects.py
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_mobile_projects.py
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_mobile_projects.py
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use utf8;
use File::Spec;
use File::Find;
use JSON;

# Helper function to mimic Python's Path.resolve().parents[n]
sub resolve_parents {
    my ($path, $levels_up) = @_;
    my @parts = split('/', $path);
    splice(@parts, -$levels_up) if $levels_up > 0;
    return join('/', @parts);
}

# Get the root directory (equivalent to Path(__file__).resolve().parents[2])
my $script_path = __FILE__;
my $script_dir = dirname($script_path);
my $ROOT = resolve_parents(File::Spec->rel2abs($script_path), 2);

my $IOS = "$ROOT/mobile/ios";
my $ANDROID = "$ROOT/mobile/android";
my $SHARED = "$ROOT/plugin-source/mobile-shared/webview-bridge.js";

# Mimic Python's require function
sub require_condition {
    my ($condition, $message) = @_;
    if (!$condition) {
        die "AssertionError: $message\n";
    }
}

# Check if a file exists
sub file_exists {
    my ($file) = @_;
    return -f $file;
}

# Read file content
sub read_file {
    my ($file) = @_;
    open(my $fh, '<:encoding(UTF-8)', $file) or die "Could not open '$file': $!\n";
    local $/;
    my $content = <$fh>;
    close($fh);
    return $content;
}

# Read binary file content
sub read_binary_file {
    my ($file) = @_;
    open(my $fh, '<', $file) or die "Could not open '$file': $!\n";
    binmode($fh);
    local $/;
    my $content = <$fh>;
    close($fh);
    return $content;
}

# List files matching pattern in directory
sub glob_files {
    my ($dir, $pattern) = @_;
    opendir(my $dh, $dir) or return ();
    my @files = grep { /$pattern/ } readdir($dh);
    closedir($dh);
    return @files;
}

# Find all files recursively matching a pattern
sub find_files_recursive {
    my ($root, $pattern) = @_;
    my @found_files;
    find(sub {
        push @found_files, $File::Find::name if /$pattern/;
    }, $root);
    return @found_files;
}

# Android checks
if (-d $ANDROID) {
    my $manifest = read_file("$ANDROID/app/src/main/AndroidManifest.xml");
    my $gradle = read_file("$ANDROID/app/build.gradle.kts");
    my $android_webview = read_file("$ANDROID/app/src/main/java/app/tiktoklivecompanion/CompanionWebView.kt");

    require_condition(index($gradle, 'minSdk = 21') != -1 && index($gradle, 'versionName = "0.8.0"') != -1, "Android version contract");
    require_condition(index($manifest, 'usesCleartextTraffic="false"') != -1, "Android cleartext must be disabled");
    require_condition(index($android_webview, "addJavascriptInterface") == -1, "insecure Android JavaScript interface");
    require_condition(index($android_webview, "addWebMessageListener") != -1 && index($android_webview, "ALLOWED_ORIGIN") != -1, "origin-restricted Android bridge");

    # Check for .aar files
    my @aar_files = glob_files("$ANDROID/app/libs", '\.aar$');
    require_condition(!@aar_files, "ShazamKit AAR must not be committed");

    # Compare shared file with Android resource
    my $shared_content = read_binary_file($SHARED);
    my $android_bridge_content = read_binary_file("$ANDROID/app/src/main/res/raw/webview_bridge.js");
    require_condition($shared_content eq $android_bridge_content, "Android bridge copy drift");
}

# iOS checks
if (-d $IOS) {
    my $ios_webview = read_file("$IOS/TikTokLiveCompanion/CompanionWebView.swift");
    my $pbx = read_file("$IOS/TikTokLiveCompanion.xcodeproj/project.pbxproj");

    require_condition(index($ios_webview, "forMainFrameOnly: false") != -1 && index($ios_webview, "securityOrigin.host == \"www.tiktok.com\"") != -1, "origin-restricted iOS subframe bridge");
    require_condition(index($pbx, "MARKETING_VERSION = 0.8.0") != -1 && index($pbx, "IPHONEOS_DEPLOYMENT_TARGET = 15.0") != -1, "iOS version contract");

    # Check source and test memberships
    my @required_names = (
        "StreamNameNormalizer.swift in Sources",
        "StreamNameNormalizerTests.swift in Sources", 
        "MobileUIStructureTests.swift in Sources"
    );
    for my $name (@required_names) {
        require_condition(index($pbx, $name) != -1, "iOS source and XCTest membership");
    }

    # Compare shared file with iOS resource
    my $shared_content = read_binary_file($SHARED);
    my $ios_bridge_content = read_binary_file("$IOS/Resources/webview-bridge.js");
    require_condition($shared_content eq $ios_bridge_content, "iOS bridge copy drift");

    # Parse Info.plist (basic parsing assuming simple structure)
    my $info_plist = read_file("$IOS/TikTokLiveCompanion/Info.plist");
    require_condition(index($info_plist, "<key>CFBundleShortVersionString</key>") != -1 && index($info_plist, "<string>0.8.0</string>") != -1, "iOS plist version");
}

# Check for Apple private keys
my @p8_files = find_files_recursive($ROOT, '\.p8$');
require_condition(!@p8_files, "Apple private key must not be committed");

# Schema validation
my $schema_json = read_file("$ROOT/plugin-source/mobile-shared/recognition-result.schema.json");
my $schema = decode_json($schema_json);

# Validate enum values
my $source_enum = $schema->{properties}->{source}->{enum};
my $valid_enum = @$source_enum == 2 && 
                 $source_enum->[0] eq "microphone" && 
                 $source_enum->[1] eq "webview";

require_condition($valid_enum, "recognition source schema");

print "PASS: available mobile platform versions, bridge boundaries, policies, schema, source sync and secret exclusions\n";

# Helper function to get directory name
sub dirname {
    my ($path) = @_;
    $path =~ s/\/[^\/]*$//;
    return $path;
}
