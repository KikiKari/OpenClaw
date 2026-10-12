#!/usr/bin/perl
# package_artifacts.py — portiert nach perl5
# Quelle: python, Projects@TikTok-Live-Companion:plugin-source/scripts/package_artifacts.py
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/package_artifacts.py
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/package_artifacts.py
# auch in: Projects@codex/0pe-177-peak-protection:plugin-source/scripts/package_artifacts.py
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use Getopt::Long;
use File::Spec;
use File::Basename;
use File::Path qw(make_path remove_tree);
use File::Copy qw(copy);
use JSON;
use Digest::SHA qw(sha256_hex);
use Archive::Zip qw(:ERROR_CODES :CONSTANTS);

my $ROOT = dirname(dirname(__FILE__));
my $PROJECT_ROOT = dirname($ROOT);
my %EXCLUDED_PARTS = map { $_ => 1 } ("__pycache__", ".gradle", ".kotlin", ".cxx", "build", "DerivedData", "xcuserdata", "Pods");

sub add_tree {
    my ($archive, $source, $prefix) = @_;
    $prefix //= "";
    
    opendir(my $dh, $source) or die "Cannot open directory $source: $!";
    my @entries = readdir($dh);
    closedir($dh);
    
    for my $entry (@entries) {
        next if $entry eq '.' || $entry eq '..';
        my $path = File::Spec->catfile($source, $entry);
        
        if (-d $path) {
            add_tree($archive, $path, "$prefix$entry/");
        } elsif (-f $path) {
            # Check if any part of the path is excluded
            my @parts = split('/', substr($path, length($source)));
            my $excluded = 0;
            for my $part (@parts) {
                if (exists $EXCLUDED_PARTS{$part}) {
                    $excluded = 1;
                    last;
                }
            }
            
            my $suffix = ($path =~ /\.([^.]+)$/)[0] // '';
            if (!$excluded && $suffix ne 'pyc' && $suffix ne 'aar') {
                my $relative = File::Spec->abs2rel($path, $source);
                my $archive_path = "$prefix$relative";
                $archive_path =~ s/\\/\//g;  # Normalize path separators
                
                my $member = $archive->addFile($path, $archive_path);
                $member->desiredCompressionMethod(COMPRESSION_DEFLATED);
                $member->desiredCompressionLevel(9);
                
                # Set permissions
                if ($entry eq 'gradlew') {
                    $member->unixFileAttributes(0100755);
                } else {
                    $member->unixFileAttributes(0100644);
                }
            }
        }
    }
}

# Parse arguments
my $output_dir;
my $android_apk;
my $android_source_default = File::Spec->catdir($PROJECT_ROOT, "mobile", "android");
my $ios_source_default = File::Spec->catdir($PROJECT_ROOT, "mobile", "ios");
my $native_shared_default = File::Spec->catdir($PROJECT_ROOT, "mobile", "shared");

my $android_source = $android_source_default;
my $ios_source = $ios_source_default;
my $native_shared_source = $native_shared_default;

GetOptions(
    "output-dir=s" => \$output_dir,
    "android-apk=s" => \$android_apk,
    "android-source=s" => \$android_source,
    "ios-source=s" => \$ios_source,
    "native-shared-source=s" => \$native_shared_source
) or die "Invalid options";

die "--output-dir is required" unless defined $output_dir;

# Create output directory
make_path($output_dir) unless -d $output_dir;

# Read manifest to get version
my $manifest_path = File::Spec->catfile($ROOT, "browser-extension", "manifest.json");
open my $fh, '<', $manifest_path or die "Cannot read $manifest_path: $!";
my $json_text = do { local $/; <$fh> };
close $fh;
my $manifest = decode_json($json_text);
my $version = $manifest->{version};

# Define output files
my $extension_zip = File::Spec->catfile($output_dir, "tiktok-live-companion-extension-$version.zip");
my $plugin_zip = File::Spec->catfile($output_dir, "tiktok-live-companion-plugin-$version.zip");
my $service_zip = File::Spec->catfile($output_dir, "tiktok-live-companion-service-$version.zip");
my $ios_source_zip = File::Spec->catfile($output_dir, "tiktok-live-companion-ios-$version-source.zip");
my $android_source_zip = File::Spec->catfile($output_dir, "tiktok-live-companion-android-$version-source.zip");
my $android_apk_out = File::Spec->catfile($output_dir, "tiktok-live-companion-android-$version.apk");
my $extension_dir = File::Spec->catdir($output_dir, "tiktok-live-companion-extension-$version");
my $checksum_file = File::Spec->catfile($output_dir, "tiktok-live-companion-$version-SHA256.txt");

# Validate extension directory location
my $resolved_extension_dir = $extension_dir;
my $resolved_output_dir = $output_dir;
die "Refusing to package outside the requested output directory" 
    unless dirname($resolved_extension_dir) eq $resolved_output_dir;

# Clean up existing extension directory
remove_tree($extension_dir) if -d $extension_dir;

# Copy browser-extension and companion-service
copytree(File::Spec->catfile($ROOT, "browser-extension"), $extension_dir);
copytree(File::Spec->catfile($ROOT, "companion-service"), File::Spec->catdir($extension_dir, "companion-service"));

# Write Windows batch file
my $batch_file = File::Spec->catfile($extension_dir, "Sprachdienst-reparieren.cmd");
open my $batch_fh, '>', $batch_file or die "Cannot write $batch_file: $!";
print $batch_fh '@echo off' . "\r\n";
print $batch_fh 'call "%~dp0companion-service\\Sprachdienst-reparieren.cmd"' . "\r\n";
close $batch_fh;

# Write package.json
my $package_json = {
    name => "tiktok-live-companion-extension-package",
    private => JSON::true,
    version => $version,
    scripts => {
        setup => "npm --prefix companion-service run setup --",
        start => "npm --prefix companion-service start",
        test => "npm --prefix companion-service test"
    }
};
my $package_json_text = to_json($package_json, { utf8 => 1, pretty => 1 }) . "\n";
my $package_file = File::Spec->catfile($extension_dir, "package.json");
open my $pkg_fh, '>:encoding(UTF-8)', $package_file or die "Cannot write $package_file: $!";
print $pkg_fh $package_json_text;
close $pkg_fh;

# Create extension zip
{
    my $zip = Archive::Zip->new();
    add_tree($zip, $extension_dir);
    die "Error writing $extension_zip: " . $zip->writeToFileNamed($extension_zip) 
        if $zip->writeToFileNamed($extension_zip) != AZ_OK;
}

# Create plugin zip
{
    my $zip = Archive::Zip->new();
    add_tree($zip, $ROOT, "tiktok-live-companion/");
    die "Error writing $plugin_zip: " . $zip->writeToFileNamed($plugin_zip) 
        if $zip->writeToFileNamed($plugin_zip) != AZ_OK;
}

# Create service zip
{
    my $zip = Archive::Zip->new();
    add_tree($zip, File::Spec->catdir($ROOT, "companion-service"));
    die "Error writing $service_zip: " . $zip->writeToFileNamed($service_zip) 
        if $zip->writeToFileNamed($service_zip) != AZ_OK;
}

# Resolve paths
$ios_source = canonpath($ios_source);
$android_source = canonpath($android_source);
die "--ios-source and --android-source must point to existing source directories" 
    unless -d $ios_source && -d $android_source;

$native_shared_source = canonpath($native_shared_source);
my $limiter_header = File::Spec->catfile($native_shared_source, "native", "tlc_peak_limiter.h");
die "Shared native limiter source is required for both mobile source packages" 
    unless -f $limiter_header;

# Create iOS source zip
{
    my $zip = Archive::Zip->new();
    add_tree($zip, $ios_source, "TikTokLiveCompanion-iOS/");
    add_tree($zip, $native_shared_source, "shared/");
    die "Error writing $ios_source_zip: " . $zip->writeToFileNamed($ios_source_zip) 
        if $zip->writeToFileNamed($ios_source_zip) != AZ_OK;
}

# Create Android source zip
{
    my $zip = Archive::Zip->new();
    add_tree($zip, $android_source, "TikTokLiveCompanion-Android/");
    add_tree($zip, $native_shared_source, "shared/");
    die "Error writing $android_source_zip: " . $zip->writeToFileNamed($android_source_zip) 
        if $zip->writeToFileNamed($android_source_zip) != AZ_OK;
}

# Handle Android APK if provided
if (defined $android_apk) {
    my $source_apk = canonpath($android_apk);
    die "--android-apk must point to an existing APK" 
        unless -f $source_apk && lc((split(/\./, $source_apk))[-1]) eq 'apk';
    
    if (canonpath($source_apk) ne canonpath($android_apk_out)) {
        copy($source_apk, $android_apk_out) or die "Cannot copy APK: $!";
    }
}

# Calculate checksums
my @artifacts = ($extension_zip, $plugin_zip, $service_zip, $ios_source_zip, $android_source_zip);
push @artifacts, $android_apk_out if -f $android_apk_out;

my @checksums;
for my $artifact (@artifacts) {
    open my $fh, '<:raw', $artifact or die "Cannot read $artifact: $!";
    my $content;
    {
        local $/;
        $content = <$fh>;
    }
    close $fh;
    my $digest = sha256_hex($content);
    my $basename = basename($artifact);
    push @checksums, "$digest  $basename";
}

open my $chk_fh, '>:encoding(UTF-8)', $checksum_file or die "Cannot write $checksum_file: $!";
print $chk_fh join("\n", @checksums) . "\n";
close $chk_fh;

# Output result as JSON
my $result = {
    extension_dir => canonpath($extension_dir),
    extension_zip => canonpath($extension_zip),
    plugin_zip => canonpath($plugin_zip),
    service_zip => canonpath($service_zip),
    ios_source_zip => canonpath($ios_source_zip),
    android_source_zip => canonpath($android_source_zip),
    android_apk => (-f $android_apk_out ? canonpath($android_apk_out) : undef),
    checksum_file => canonpath($checksum_file),
    version => $version
};

print encode_json($result) . "\n";

# Helper function to copy directory tree
sub copytree {
    my ($src, $dst) = @_;
    make_path($dst) unless -d $dst;
    
    opendir(my $dh, $src) or die "Cannot open directory $src: $!";
    my @entries = readdir($dh);
    closedir($dh);
    
    for my $entry (@entries) {
        next if $entry eq '.' || $entry eq '..';
        my $src_path = File::Spec->catfile($src, $entry);
        my $dst_path = File::Spec->catfile($dst, $entry);
        
        if (-d $src_path) {
            copytree($src_path, $dst_path);
        } else {
            copy($src_path, $dst_path) or die "Cannot copy $src_path to $dst_path: $!";
        }
    }
}

# Helper function to canonicalize path
sub canonpath {
    my ($path) = @_;
    return File::Spec->canonpath($path);
}
