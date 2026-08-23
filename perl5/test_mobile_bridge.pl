#!/usr/bin/perl
# test_mobile_bridge.cjs — portiert nach perl5
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_mobile_bridge.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_mobile_bridge.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_mobile_bridge.cjs
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Spec;
use File::Slurp qw(read_file);
use JavaScript::V8;

# Helper to resolve paths similar to path.resolve
sub resolve_path {
    my @parts = @_;
    return File::Spec->rel2abs(File::Spec->catfile(@parts));
}

# Get the directory of the script (similar to __dirname)
my $script_dir = dirname($0);
my $root = resolve_path($script_dir, "..");
my $bridge_path = File::Spec->catfile($root, "mobile-shared", "webview-bridge.js");

# Read the bridge file
my $source = read_file($bridge_path);

# Create a V8 context and compile the script
my $context = JavaScript::V8::Context->new();
$context->eval($source); # This will throw if syntax error

# Assertions: Check that certain strings are present or absent
my @must_include = (
    q{location.hostname !== "www.tiktok.com"},
    q{root.top === root},
    q{if (!isTop) return},
    q{MAX_MESSAGE_BYTES = 64 * 1024},
    q{MAX_AUDIO_SECONDS = 12},
    q{QUICK_RECOVER_RELOAD_COOLDOWN_MS = 400},
    q{ALLOWED_COMMANDS},
    q{"set-auto-reconnect"},
    q{"set-limiter"},
    q{"scan-recommendations"},
    q{"cancel-recommendation-scan"},
    q{MAX_MEDIA_URLS = 12},
    q{const mediaUrls = new Map()},
    q{emit("media-url"},
    q{addEventListener("message"},
    q{FORCE_RETURN_KEY = "tlc-force-return"},
    q{sessionStorage.getItem(FORCE_RETURN_KEY)},
);

my @must_not_include = (
    q{.send =},
    q{document.cookie},
    q{localStorage},
    q{sessionStorage.clear},
    q{innerHTML},
);

# Run inclusion checks
foreach my $text (@must_include) {
    die "FAIL: Expected to find '$text' in source" unless $source =~ /\Q$text\E/;
}

# Run exclusion checks
foreach my $text (@must_not_include) {
    die "FAIL: Not expected to find '$text' in source" if $source =~ /\Q$text\E/;
}

# Check copies
my @copies = (
    File::Spec->catfile($root, "..", "mobile", "ios", "Resources", "webview-bridge.js"),
    File::Spec->catfile($root, "..", "mobile", "android", "app", "src", "main", "res", "raw", "webview_bridge.js"),
);

foreach my $copy (@copies) {
    my $content = read_file($copy);
    die "FAIL: Bridge copy drifted: $copy" unless $content eq $source;
}

print "PASS: mobile bridge origin, main-frame, size, command, audio-duration and storage guards\n";

# Helper function to mimic dirname in Perl
sub dirname {
    my $path = shift;
    my ($volume, $directories, $file) = File::Spec->splitpath($path);
    return File::Spec->catdir($volume, $directories);
}
