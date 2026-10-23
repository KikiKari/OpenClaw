#!/usr/bin/perl
# package_artifacts.py — portiert nach perl5
# Quelle: python, Projects@TikTok-Live-Companion:plugin-source/scripts/package_artifacts.py
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/package_artifacts.py
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/package_artifacts.py
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/package_artifacts.py
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use Getopt::Long;
use JSON;
use File::Path qw(make_path remove_tree);
use File::Copy qw(copy);
use File::Spec;
use File::Find;
use Digest::SHA qw(sha256_hex);
use Archive::Zip qw(:CONSTANTS :ERROR_CODES);

my $ROOT = do { my @p = File::Spec->splitdir(__FILE__); pop @p; pop @p; File::Spec->catdir(@p) };
my $PROJECT_ROOT = do { my @p = File::Spec->splitdir($ROOT); pop @p; File::Spec->catdir(@p) };

my %EXCLUDED_PARTS = map { $_ => 1 } ("__pycache__", ".gradle", ".kotlin", ".cxx", "build", "DerivedData", "xcuserdata", "Pods");

sub add_tree {
    my ($archive, $source, $prefix) = @_;
    $prefix //= "";

    find(sub {
        return unless -f $_;
        my $rel_path = File::Spec->abs2rel($File::Find::name, $source);
        my @parts = split('/', $rel_path);
        return if grep { $EXCLUDED_PARTS{$_} } @parts;
        return if /\.(?:pyc|aar)$/;

        my $archive_path = $prefix ? "$prefix/$rel_path" : $rel_path;
        $archive_path =~ s/\\/\//g;

        my $member = $archive->addFile($File::Find::name, $archive_path);
        if ($member) {
            $member->desiredCompressionMethod(COMPRESSION_DEFLATED);
            $member->desiredCompressionLevel(9);
            my @stat = stat($_);
            my ($mode) = $stat[2] & 07777;
            if ($_ eq 'gradlew') {
                $mode = 0755;
            } else {
                $mode = 0644;
            }
            $member->unixFileAttributes($mode);
        }
    }, $source);
}

my ($output_dir, $android_apk, $android_source_opt, $ios_source_opt, $native_shared_source);
GetOptions(
    "output-dir=s" => \$output_dir,
    "android-apk=s" => \$android_apk,
    "android-source=s" => \$android_source_opt,
    "ios-source=s" => \$ios_source_opt,
    "native-shared-source=s" => \$native_shared_source,
) or die "Invalid options";

die "--output-dir is required" unless $output_dir;

make_path($output_dir) unless -d $output_dir;

my $manifest_path = File::Spec->catfile($ROOT, "browser-extension", "manifest.json");
open(my $fh, '<', $manifest_path) or die "Cannot read manifest.json: $!";
my $json_text = do { local $/; <$fh> };
close($fh);
my $manifest = decode_json($json_text);
my $version = $manifest->{version};

my $extension_zip = File::Spec->catfile($output_dir, "tiktok-live-companion-extension-$version.zip");
my $plugin_zip = File::Spec->catfile($output_dir, "tiktok-live-companion-plugin-$version.zip");
my $service_zip = File::Spec->catfile($output_dir, "tiktok-live-companion-service-$version.zip");
my $ios_source_zip = File::Spec->catfile($output_dir, "tiktok-live-companion-ios-$version-source.zip");
my $android_source_zip = File::Spec->catfile($output_dir, "tiktok-live-companion-android-$version-source.zip");
my $android_apk_out = File::Spec->catfile($output_dir, "tiktok-live-companion-android-$version.apk");
my $extension_dir = File::Spec->catdir($output_dir, "tiktok-live-companion-extension-$version");
my $checksum_file = File::Spec->catfile($output_dir, "tiktok-live-companion-$version-SHA256.txt");

my $resolved_extension_dir = $extension_dir;
if ((File::Spec->splitdir($resolved_extension_dir))[0] ne (File::Spec->splitdir($output_dir))[0]) {
    die "Refusing to package outside the requested output directory";
}

remove_tree($extension_dir) if -d $extension_dir;

sub copy_dir_recursive {
    my ($src, $dst) = @_;
    make_path($dst) unless -d $dst;
    opendir(my $dh, $src) or die "Cannot open dir $src: $!";
    my @entries = readdir($dh);
    closedir($dh);
    for my $entry (@entries) {
        next if $entry eq '.' || $entry eq '..';
        my $src_path = File::Spec->catfile($src, $entry);
        my $dst_path = File::Spec->catfile($dst, $entry);
        if (-d $src_path) {
            copy_dir_recursive($src_path, $dst_path);
        } else {
            copy($src_path, $dst_path) or die "Copy failed: $!";
        }
    }
}

copy_dir_recursive(File::Spec->catdir($ROOT, "browser-extension"), $extension_dir);
copy_dir_recursive(File::Spec->catdir($ROOT, "companion-service"), File::Spec->catdir($extension_dir, "companion-service"));

{
    open(my $fh, '>:encoding(utf8)', File::Spec->catfile($extension_dir, "Sprachdienst-reparieren.cmd")) or die $!;
    print $fh '@echo off' . "\r\n" . 'call "%~dp0companion-service\Sprachdienst-reparieren.cmd"' . "\r\n";
    close($fh);
}

my $package_json_data = {
    name => "tiktok-live-companion-extension-package",
    private => JSON::true,
    version => $version,
    scripts => {
        setup => "npm --prefix companion-service run setup --",
        start => "npm --prefix companion-service start",
        test => "npm --prefix companion-service test"
    }
};

{
    open(my $fh, '>:encoding(utf8)', File::Spec->catfile($extension_dir, "package.json")) or die $!;
    print $fh to_json($package_json_data, { utf8 => 1, pretty => 1 }) . "\n";
    close($fh);
}

{
    my $zip = Archive::Zip->new();
    add_tree($zip, $extension_dir);
    die "Error writing $extension_zip" unless $zip->writeToFileNamed($extension_zip) == AZ_OK;
}

{
    my $zip = Archive::Zip->new();
    add_tree($zip, $ROOT, "tiktok-live-companion");
    die "Error writing $plugin_zip" unless $zip->writeToFileNamed($plugin_zip) == AZ_OK;
}

{
    my $zip = Archive::Zip->new();
    add_tree($zip, File::Spec->catdir($ROOT, "companion-service"));
    die "Error writing $service_zip" unless $zip->writeToFileNamed($service_zip) == AZ_OK;
}

my $ios_source = $ios_source_opt // File::Spec->catdir($PROJECT_ROOT, "mobile", "ios");
my $android_source = $android_source_opt // File::Spec->catdir($PROJECT_ROOT, "mobile", "android");
my $native_shared = $native_shared_source // File::Spec->catdir($PROJECT_ROOT, "mobile", "shared");

die "--ios-source and --android-source must point to existing source directories" unless -d $ios_source && -d $android_source;

my $limiter_header = File::Spec->catfile($native_shared, "native", "tlc_peak_limiter.h");
die "Shared native limiter source is required for both mobile source packages" unless -f $limiter_header;

{
    my $zip = Archive::Zip->new();
    add_tree($zip, $ios_source, "TikTokLiveCompanion-iOS");
    add_tree($zip, $native_shared, "shared");
    die "Error writing $ios_source_zip" unless $zip->writeToFileNamed($ios_source_zip) == AZ_OK;
}

{
    my $zip = Archive::Zip->new();
    add_tree($zip, $android_source, "TikTokLiveCompanion-Android");
    add_tree($zip, $native_shared, "shared");
    die "Error writing $android_source_zip" unless $zip->writeToFileNamed($android_source_zip) == AZ_OK;
}

if ($android_apk) {
    die "--android-apk must point to an existing APK" unless -f $android_apk && $android_apk =~ /\.apk$/i;
    unless (File::Spec->rel2abs($android_apk) eq File::Spec->rel2abs($android_apk_out)) {
        copy($android_apk, $android_apk_out) or die "Failed to copy APK: $!";
    }
}

my @artifacts = ($extension_zip, $plugin_zip, $service_zip, $ios_source_zip, $android_source_zip);
push @artifacts, $android_apk_out if -f $android_apk_out;

my @checksums;
for my $artifact (@artifacts) {
    open(my $fh, '<', $artifact) or die "Cannot read $artifact: $!";
    binmode($fh);
    my $digest = sha256_hex(do { local $/; <$fh> });
    close($fh);
    my ($vol, $dirs, $file) = File::Spec->splitpath($artifact);
    push @checksums, "$digest  $file";
}

{
    open(my $fh, '>:encoding(utf8)', $checksum_file) or die $!;
    print $fh join("\n", @checksums) . "\n";
    close($fh);
}

my %result = (
    extension_dir => File::Spec->rel2abs($extension_dir),
    extension_zip => File::Spec->rel2abs($extension_zip),
    plugin_zip => File::Spec->rel2abs($plugin_zip),
    service_zip => File::Spec->rel2abs($service_zip),
    ios_source_zip => File::Spec->rel2abs($ios_source_zip),
    android_source_zip => File::Spec->rel2abs($android_source_zip),
    android_apk => (-f $android_apk_out ? File::Spec->rel2abs($android_apk_out) : undef),
    checksum_file => File::Spec->rel2abs($checksum_file),
    version => $version
);

print encode_json(\%result) . "\n";
