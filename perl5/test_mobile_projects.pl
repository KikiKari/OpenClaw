#!/usr/bin/perl
# test_mobile_projects.py — portiert nach perl5
# Quelle: python, Projects@TikTok-Live-Companion:plugin-source/scripts/test_mobile_projects.py
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_mobile_projects.py
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_mobile_projects.py
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_mobile_projects.py
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Spec;
use Cwd qw(realpath);
use JSON;

# Helper function to mimic Python's Path.resolve().parents[2]
sub get_root {
    my $script_path = realpath(__FILE__);
    my @parts = File::Spec->splitdir($script_path);
    # Remove last three components (test_mobile_projects.py)
    splice(@parts, -3);
    return File::Spec->catdir(@parts);
}

my $ROOT = get_root();
my $IOS = File::Spec->catdir($ROOT, "mobile", "ios");
my $ANDROID = File::Spec->catdir($ROOT, "mobile", "android");
my $SHARED = File::Spec->catfile($ROOT, "plugin-source", "mobile-shared", "webview-bridge.js");

sub require_condition {
    my ($condition, $message) = @_;
    if (!$condition) {
        die "AssertionError: $message\n";
    }
}

sub read_file {
    my ($file_path) = @_;
    open my $fh, '<:encoding(UTF-8)', $file_path or die "Cannot open $file_path: $!";
    local $/; # Enable 'slurp' mode
    my $content = <$fh>;
    close $fh;
    return $content;
}

sub read_binary_file {
    my ($file_path) = @_;
    open my $fh, '<:raw', $file_path or die "Cannot open $file_path: $!";
    local $/;
    my $content = <$fh>;
    close $fh;
    return $content;
}

sub file_exists {
    my ($file_path) = @_;
    return -f $file_path;
}

sub glob_files {
    my ($pattern) = @_;
    my @files = glob($pattern);
    return @files;
}

if (-d $ANDROID) {
    my $manifest_path = File::Spec->catfile($ANDROID, "app", "src", "main", "AndroidManifest.xml");
    my $gradle_path = File::Spec->catfile($ANDROID, "app", "build.gradle.kts");
    my $android_webview_path = File::Spec->catfile($ANDROID, "app", "src", "main", "java", "app", "tiktoklivecompanion", "CompanionWebView.kt");
    
    my $manifest = read_file($manifest_path);
    my $gradle = read_file($gradle_path);
    my $android_webview = read_file($android_webview_path);

    require_condition(index($gradle, 'minSdk = 21') != -1 && index($gradle, 'versionName = "0.8.2"') != -1, "Android version contract");
    require_condition(index($manifest, 'usesCleartextTraffic="false"') != -1, "Android cleartext must be disabled");
    require_condition(index($android_webview, "addJavascriptInterface") == -1, "insecure Android JavaScript interface");
    require_condition(index($android_webview, "addWebMessageListener") != -1 && index($android_webview, "ALLOWED_ORIGIN") != -1, "origin-restricted Android bridge");

    my $libs_dir = File::Spec->catdir($ANDROID, "app", "libs");
    my @aar_files = glob_files(File::Spec->catfile($libs_dir, "*.aar"));
    require_condition(!@aar_files, "ShazamKit AAR must not be committed");

    my $android_bridge_copy = File::Spec->catfile($ANDROID, "app", "src", "main", "res", "raw", "webview_bridge.js");
    require_condition(read_binary_file($SHARED) eq read_binary_file($android_bridge_copy), "Android bridge copy drift");
}

if (-d $IOS) {
    my $ios_webview_path = File::Spec->catfile($IOS, "TikTokLiveCompanion", "CompanionWebView.swift");
    my $pbx_path = File::Spec->catfile($IOS, "TikTokLiveCompanion.xcodeproj", "project.pbxproj");
    my $info_plist_path = File::Spec->catfile($IOS, "TikTokLiveCompanion", "Info.plist");

    my $ios_webview = read_file($ios_webview_path);
    my $pbx = read_file($pbx_path);

    require_condition(index($ios_webview, "forMainFrameOnly: false") != -1 && index($ios_webview, "securityOrigin.host == \"www.tiktok.com\"") != -1, "origin-restricted iOS subframe bridge");
    require_condition(index($pbx, "MARKETING_VERSION = 0.8.2") != -1 && index($pbx, "IPHONEOS_DEPLOYMENT_TARGET = 15.0") != -1, "iOS version contract");

    my @required_names = ("StreamNameNormalizer.swift in Sources", "StreamNameNormalizerTests.swift in Sources", "MobileUIStructureTests.swift in Sources");
    my $all_found = 1;
    foreach my $name (@required_names) {
        if (index($pbx, $name) == -1) {
            $all_found = 0;
            last;
        }
    }
    require_condition($all_found, "iOS source and XCTest membership");

    my $ios_bridge_copy = File::Spec->catfile($IOS, "Resources", "webview-bridge.js");
    require_condition(read_binary_file($SHARED) eq read_binary_file($ios_bridge_copy), "iOS bridge copy drift");

    # Read Info.plist using system call to plutil (macOS only)
    my $plist_json = `plutil -convert json -o - "$info_plist_path"`;
    my $json = JSON->new;
    my $info = $json->decode($plist_json);
    require_condition($info->{"CFBundleShortVersionString"} eq "0.8.2", "iOS plist version");
}

# Check for .p8 files recursively
my @p8_files = `find "$ROOT" -type f -name "*.p8"`;
chomp @p8_files;
require_condition(!@p8_files, "Apple private key must not be committed");

# Check recognition result schema
my $schema_path = File::Spec->catfile($ROOT, "plugin-source", "mobile-shared", "recognition-result.schema.json");
my $schema_content = read_file($schema_path);
my $schema = decode_json($schema_content);
my $source_enum = $schema->{properties}->{source}->{enum};
my $is_valid = @$source_enum == 2 &&
               ((grep { $_ eq "microphone" } @$source_enum) == 1) &&
               ((grep { $_ eq "webview" } @$source_enum) == 1);
require_condition($is_valid, "recognition source schema");

print "PASS: available mobile platform versions, bridge boundaries, policies, schema, source sync and secret exclusions\n";
