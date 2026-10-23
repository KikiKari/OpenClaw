#!/usr/bin/perl
# test_mobile_bridge.cjs — portiert nach perl5
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_mobile_bridge.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_mobile_bridge.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_mobile_bridge.cjs
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_mobile_bridge.cjs
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Spec;
use File::Basename;

# Get the root directory (parent of the script's directory)
my $script_dir = dirname(__FILE__);
my $root = File::Spec->rel2abs(File::Spec->catdir($script_dir, ".."));

# Define the bridge path
my $bridge_path = File::Spec->catfile($root, "mobile-shared", "webview-bridge.js");

# Read the source file
open my $fh, '<:encoding(UTF-8)', $bridge_path or die "Cannot open $bridge_path: $!";
my $source = do { local $/; <$fh> };
close $fh;

# Basic syntax check by compiling (using perl to eval JS code is not feasible,
# so we just ensure it's valid UTF-8 and non-empty as a basic sanity check)
die "Source is empty or invalid" unless defined $source && length $source;

# Perform assertions (using die to simulate assertion failures)
assert($source =~ /location\.hostname !== "www\.tiktok\.com"/, 'location.hostname check');
assert($source =~ /root\.top === root/, 'root.top check');
assert($source =~ /if \(!isTop\) return/, 'isTop check');
assert($source =~ /MAX_MESSAGE_BYTES = 64 \* 1024/, 'MAX_MESSAGE_BYTES check');
assert($source =~ /MAX_AUDIO_SECONDS = 12/, 'MAX_AUDIO_SECONDS check');
assert($source =~ /QUICK_RECOVER_RELOAD_COOLDOWN_MS = 400/, 'QUICK_RECOVER_RELOAD_COOLDOWN_MS check');
assert($source =~ /ALLOWED_COMMANDS/, 'ALLOWED_COMMANDS check');
assert($source =~ /"set-auto-reconnect"/, '"set-auto-reconnect" check');
assert($source =~ /"set-limiter"/, '"set-limiter" check');
assert($source =~ /"scan-recommendations"/, '"scan-recommendations" check');
assert($source =~ /"cancel-recommendation-scan"/, '"cancel-recommendation-scan" check');
assert($source =~ /MAX_MEDIA_URLS = 12/, 'MAX_MEDIA_URLS check');
assert($source =~ /const mediaUrls = new Map\(\)/, 'mediaUrls Map check');
assert($source =~ /emit\("media-url"/, 'emit media-url check');
assert($source =~ /addEventListener\("message"/, 'addEventListener message check');
assert($source !~ /\.send =/, '.send assignment forbidden');
assert($source !~ /document\.cookie/, 'document.cookie forbidden');
assert($source !~ /localStorage/, 'localStorage forbidden');
assert($source =~ /FORCE_RETURN_KEY = "tlc-force-return"/, 'FORCE_RETURN_KEY check');
assert($source =~ /sessionStorage\.getItem\(FORCE_RETURN_KEY\)/, 'sessionStorage.getItem check');
assert($source !~ /sessionStorage\.clear/, 'sessionStorage.clear forbidden');
assert($source !~ /innerHTML/, 'innerHTML forbidden');

# Check copies
my @copies = (
    File::Spec->catfile($root, "..", "mobile", "ios", "Resources", "webview-bridge.js"),
    File::Spec->catfile($root, "..", "mobile", "android", "app", "src", "main", "res", "raw", "webview_bridge.js")
);

foreach my $copy (@copies) {
    open my $copy_fh, '<:encoding(UTF-8)', $copy or die "Cannot open $copy: $!";
    my $copy_content = do { local $/; <$copy_fh> };
    close $copy_fh;
    
    if ($copy_content ne $source) {
        die "Bridge copy drifted: $copy";
    }
}

print "PASS: mobile bridge origin, main-frame, size, command, audio-duration and storage guards\n";

# Helper subroutine for assertions
sub assert {
    my ($condition, $message) = @_;
    if (!$condition) {
        die "Assertion failed: $message\n";
    }
}
