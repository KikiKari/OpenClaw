#!/usr/bin/env perl
# abstraction-provenance: {"artifact_sha256": "41731cecfea2e1a7d4999f48ff06ed83503527cd26174312e230118b35eadb09", "source_sha256": "cff712785adbfe2fa94661b7b8457fbc21ec0b21bc3bc77e5cfa7018f473e486", "target_language": "perl5"}
# build_icon.sh — portiert nach perl5
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/build_icon.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Spec;
use File::Basename;
use File::Path qw(make_path);
use Cwd qw(abs_path);

# Render the macOS .icon bundle to a padded .icns like Trimmy's pipeline.
# Defaults target the OpenClaw assets so you can just run the script from repo root.

my $script_dir = dirname(__FILE__);
my $root_dir = abs_path(File::Spec->catdir($script_dir, '..'));

my $icon_file = $ARGV[0] // File::Spec->catfile($root_dir, 'apps', 'macos', 'Icon.icon');
my $basename = $ARGV[1] // 'OpenClaw';
my $out_root = $ARGV[2] // File::Spec->catfile($root_dir, 'apps', 'macos', 'build', 'icon');
$ENV{XCODE_APP} //= '/Applications/Xcode.app';
# Where the final .icns should live; override DEST_ICNS to change.
my $dest_icns = $ENV{DEST_ICNS} // File::Spec->catfile($root_dir, 'apps', 'macos', 'Sources', 'OpenClaw', 'Resources', 'OpenClaw.icns');

my $xcode_app = $ENV{XCODE_APP};
my $ictool = File::Spec->catfile($xcode_app, 'Contents', 'Applications', 'Icon Composer.app', 'Contents', 'Executables', 'ictool');
if (!-x $ictool) {
    $ictool = File::Spec->catfile($xcode_app, 'Contents', 'Applications', 'Icon Composer.app', 'Contents', 'Executables', 'icontool');
}
if (!-x $ictool) {
    warn "ictool/icontool not found. Set XCODE_APP if Xcode is elsewhere.\n";
    exit 1;
}

my $iconset_dir = File::Spec->catdir($out_root, "${basename}.iconset");
my $tmp_dir = File::Spec->catdir($out_root, 'tmp');
make_path($iconset_dir, $tmp_dir);

my $master_art = File::Spec->catfile($tmp_dir, 'icon_art_824.png');
my $master_1024 = File::Spec->catfile($tmp_dir, 'icon_1024.png');

# Render inner art (no margin) with macOS Default appearance
system($ictool, $icon_file,
    '--export-preview', 'macOS Default', '824', '824', '1', '-45', $master_art) == 0
    or die "Failed to execute ictool: $?";

# Pad to 1024x1024 with transparent border
system('sips', '--padToHeightWidth', '1024', '1024', $master_art, '--out', $master_1024, '>/dev/null') == 0
    or die "Failed to execute sips: $?";

# Generate required sizes
my @sizes = (16, 32, 64, 128, 256, 512, 1024);
for my $sz (@sizes) {
    my $out = File::Spec->catfile($iconset_dir, "icon_${sz}x${sz}.png");
    system('sips', '-z', $sz, $sz, $master_1024, '--out', $out, '>/dev/null') == 0
        or die "Failed to execute sips: $?";
    if ($sz != 1024) {
        my $dbl = $sz * 2;
        my $out2 = File::Spec->catfile($iconset_dir, "icon_${sz}x${sz}\@2x.png");
        system('sips', '-z', $dbl, $dbl, $master_1024, '--out', $out2, '>/dev/null') == 0
            or die "Failed to execute sips: $?";
    }
}

# 512x512@2x already covered by 1024; ensure it exists
system('cp', $master_1024, File::Spec->catfile($iconset_dir, 'icon_512x512@2x.png')) == 0
    or die "Failed to copy file: $?";

system('iconutil', '-c', 'icns', $iconset_dir, '-o', File::Spec->catfile($out_root, "${basename}.icns")) == 0
    or die "Failed to execute iconutil: $?";

my ($dest_icns_dir) = $dest_icns =~ m{^(.*)/[^/]+$};
make_path($dest_icns_dir);

system('cp', File::Spec->catfile($out_root, "${basename}.icns"), $dest_icns) == 0
    or die "Failed to copy file: $?";

print "Icon.icns generated at $dest_icns\n";
