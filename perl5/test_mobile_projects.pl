#!/usr/bin/perl
# test_mobile_projects.py — portiert nach perl5
# Quelle: python, Projects@TikTok-Live-Companion:plugin-source/scripts/test_mobile_projects.py
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_mobile_projects.py
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_mobile_projects.py
# auch in: Projects@codex/0pe-177-peak-protection:plugin-source/scripts/test_mobile_projects.py
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use utf8;
use File::Spec;
use File::Find;
use JSON;
use Cwd qw(realpath);
use File::Basename;

binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my $SCRIPT_DIR = dirname(__FILE__);
my @PATH_PARTS = split('/', realpath($SCRIPT_DIR));
splice(@PATH_PARTS, -2);
my $ROOT = join('/', @PATH_PARTS);
my $IOS = "$ROOT/mobile/ios";
my $ANDROID = "$ROOT/mobile/android";
my $SHARED = "$ROOT/plugin-source/mobile-shared/webview-bridge.js";

sub require_condition {
    my ($condition, $message) = @_;
    if (!$condition) {
        die "AssertionError: $message\n";
    }
}

if (-d $ANDROID) {
    my $manifest_path = "$ANDROID/app/src/main/AndroidManifest.xml";
    my $gradle_path = "$ANDROID/app/build.gradle.kts";
    my $android_webview_path = "$ANDROID/app/src/main/java/app/tiktoklivecompanion/CompanionWebView.kt";
    
    open(my $fh_manifest, '<:encoding(UTF-8)', $manifest_path) or die "Cannot read $manifest_path: $!";
    my $manifest = do { local $/; <$fh_manifest> };
    close($fh_manifest);
    
    open(my $fh_gradle, '<:encoding(UTF-8)', $gradle_path) or die "Cannot read $gradle_path: $!";
    my $gradle = do { local $/; <$fh_gradle> };
    close($fh_gradle);
    
    open(my $fh_android_webview, '<:encoding(UTF-8)', $android_webview_path) or die "Cannot read $android_webview_path: $!";
    my $android_webview = do { local $/; <$fh_android_webview> };
    close($fh_android_webview);
    
    require_condition(
        ($gradle =~ /minSdk = 21/ && $gradle =~ /versionName = "0\.8\.2"/),
        "Android version contract"
    );
    
    require_condition(
        $manifest =~ /usesCleartextTraffic="false"/,
        "Android cleartext must be disabled"
    );
    
    require_condition(
        $android_webview !~ /addJavascriptInterface/,
        "insecure Android JavaScript interface"
    );
    
    require_condition(
        ($android_webview =~ /addWebMessageListener/ && $android_webview =~ /ALLOWED_ORIGIN/),
        "origin-restricted Android bridge"
    );
    
    opendir(my $dh, "$ANDROID/app/libs") or die "Cannot open directory: $!";
    my @aar_files = grep { /\.aar$/ } readdir($dh);
    closedir($dh);
    require_condition(
        scalar(@aar_files) == 0,
        "ShazamKit AAR must not be committed"
    );
    
    open(my $fh_shared, '<', $SHARED) or die "Cannot read $SHARED: $!";
    my $shared_content = do { local $/; <$fh_shared> };
    close($fh_shared);
    
    open(my $fh_android_bridge, '<', "$ANDROID/app/src/main/res/raw/webview_bridge.js") or die "Cannot read Android bridge file: $!";
    my $android_bridge_content = do { local $/; <$fh_android_bridge> };
    close($fh_android_bridge);
    
    require_condition(
        $shared_content eq $android_bridge_content,
        "Android bridge copy drift"
    );
}

if (-d $IOS) {
    my $ios_webview_path = "$IOS/TikTokLiveCompanion/CompanionWebView.swift";
    my $pbx_path = "$IOS/TikTokLiveCompanion.xcodeproj/project.pbxproj";
    
    open(my $fh_ios_webview, '<:encoding(UTF-8)', $ios_webview_path) or die "Cannot read $ios_webview_path: $!";
    my $ios_webview = do { local $/; <$fh_ios_webview> };
    close($fh_ios_webview);
    
    open(my $fh_pbx, '<:encoding(UTF-8)', $pbx_path) or die "Cannot read $pbx_path: $!";
    my $pbx = do { local $/; <$fh_pbx> };
    close($fh_pbx);
    
    require_condition(
        ($ios_webview =~ /forMainFrameOnly: false/ && $ios_webview =~ /securityOrigin\.host == "www\.tiktok\.com"/),
        "origin-restricted iOS subframe bridge"
    );
    
    require_condition(
        ($pbx =~ /MARKETING_VERSION = 0\.8\.2/ && $pbx =~ /IPHONEOS_DEPLOYMENT_TARGET = 15\.0/),
        "iOS version contract"
    );
    
    require_condition(
        ($pbx =~ /StreamNameNormalizer\.swift in Sources/ && 
         $pbx =~ /StreamNameNormalizerTests\.swift in Sources/ && 
         $pbx =~ /MobileUIStructureTests\.swift in Sources/),
        "iOS source and XCTest membership"
    );
    
    open(my $fh_shared_ios, '<', $SHARED) or die "Cannot read $SHARED: $!";
    my $shared_content_ios = do { local $/; <$fh_shared_ios> };
    close($fh_shared_ios);
    
    open(my $fh_ios_bridge, '<', "$IOS/Resources/webview-bridge.js") or die "Cannot read iOS bridge file: $!";
    my $ios_bridge_content = do { local $/; <$fh_ios_bridge> };
    close($fh_ios_bridge);
    
    require_condition(
        $shared_content_ios eq $ios_bridge_content,
        "iOS bridge copy drift"
    );
    
    my $info_plist_path = "$IOS/TikTokLiveCompanion/Info.plist";
    # Simple parsing of plist values without full XML parser
    open(my $fh_info, '<:encoding(UTF-8)', $info_plist_path) or die "Cannot read $info_plist_path: $!";
    my $info_content = do { local $/; <$fh_info> };
    close($fh_info);
    
    require_condition(
        $info_content =~ /<key>CFBundleShortVersionString<\/key>\s*<string>0\.8\.2<\/string>/,
        "iOS plist version"
    );
}

# Check for .p8 files recursively
my @p8_files;
find(sub {
    push @p8_files, $File::Find::name if /\.p8$/;
}, $ROOT);

require_condition(
    scalar(@p8_files) == 0,
    "Apple private key must not be committed"
);

# Read and check schema
my $schema_path = "$ROOT/plugin-source/mobile-shared/recognition-result.schema.json";
open(my $fh_schema, '<:encoding(UTF-8)', $schema_path) or die "Cannot read $schema_path: $!";
my $schema_json = do { local $/; <$fh_schema> };
close($fh_schema);

my $schema = decode_json($schema_json);
my $source_enum = $schema->{properties}->{source}->{enum};

require_condition(
    @$source_enum == 2 && 
    ((grep { $_ eq "microphone" } @$source_enum) && (grep { $_ eq "webview" } @$source_enum)),
    "recognition source schema"
);

print "PASS: available mobile platform versions, bridge boundaries, policies, schema, source sync and secret exclusions\n";
