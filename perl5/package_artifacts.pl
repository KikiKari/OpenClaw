#!/usr/bin/perl
# package_artifacts.py — portiert nach perl5
# Quelle: python, Projects@TikTok-Live-Companion:plugin-source/scripts/package_artifacts.py
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/package_artifacts.py
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/package_artifacts.py
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

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

my $ROOT = do {
    my @parts = split '/', __FILE__;
    pop @parts;
    pop @parts;
    join('/', @parts);
};

my $PROJECT_ROOT = do {
    my @parts = split '/', $ROOT;
    pop @parts;
    join('/', @parts);
};

my %EXCLUDED_PARTS = map { $_ => 1 } ("__pycache__", ".gradle", ".kotlin", "build", "DerivedData", "xcuserdata");

sub add_tree {
    my ($archive, $source, $prefix) = @_;
    $prefix //= "";
    
    my @files;
    find(sub {
        return unless -f $_;
        my $rel_path = substr($File::Find::name, length($source) + 1);
        my @parts = split '/', $rel_path;
        
        # Check excluded parts
        my $excluded = 0;
        for my $part (@parts) {
            if ($EXCLUDED_PARTS{$part}) {
                $excluded = 1;
                last;
            }
        }
        
        # Check file extensions
        my ($ext) = ($_ =~ /(\.[^.]+)$/);
        if (!$excluded && $ext && ($ext eq '.pyc' || $ext eq '.aar')) {
            $excluded = 1;
        }
        
        push @files, $File::Find::name unless $excluded;
    }, $source);
    
    @files = sort @files;
    
    for my $file (@files) {
        my $relative = substr($file, length($source) + 1);
        my $archive_path = $prefix ? "$prefix/$relative" : $relative;
        $archive_path =~ s|\\|/|g;  # Normalize path separators
        
        my $member = $archive->addFile($file, $archive_path);
        if ($member) {
            $member->desiredCompressionMethod(COMPRESSION_DEFLATED);
            $member->unixFileAttributes(0100644);
        }
    }
}

# Parse arguments
my $output_dir;
my $android_apk;
my $android_source = "$PROJECT_ROOT/mobile/android";
my $ios_source = "$PROJECT_ROOT/mobile/ios";

GetOptions(
    "output-dir=s" => \$output_dir,
    "android-apk=s" => \$android_apk,
    "android-source=s" => \$android_source,
    "ios-source=s" => \$ios_source,
) or die "Invalid options\n";

die "--output-dir is required\n" unless $output_dir;

# Create output directory
make_path($output_dir) unless -d $output_dir;

# Resolve paths
$output_dir = File::Spec->rel2abs($output_dir);
$android_source = File::Spec->rel2abs($android_source);
$ios_source = File::Spec->rel2abs($ios_source);
$android_apk = File::Spec->rel2abs($android_apk) if $android_apk;

# Read manifest
my $manifest_content;
{
    open my $fh, '<:encoding(UTF-8)', "$ROOT/browser-extension/manifest.json" or die "Cannot read manifest.json: $!";
    local $/;
    $manifest_content = <$fh>;
    close $fh;
}
my $manifest = decode_json($manifest_content);
my $version = $manifest->{version};

# Define output files
my $extension_zip = "$output_dir/tiktok-live-companion-extension-$version.zip";
my $plugin_zip = "$output_dir/tiktok-live-companion-plugin-$version.zip";
my $service_zip = "$output_dir/tiktok-live-companion-service-$version.zip";
my $ios_source_zip = "$output_dir/tiktok-live-companion-ios-$version-source.zip";
my $android_source_zip = "$output_dir/tiktok-live-companion-android-$version-source.zip";
my $android_apk_out = "$output_dir/tiktok-live-companion-android-$version.apk";
my $extension_dir = "$output_dir/tiktok-live-companion-extension-$version";
my $checksum_file = "$output_dir/tiktok-live-companion-$version-SHA256.txt";

# Validate extension directory location
my $resolved_extension_dir = File::Spec->rel2abs($extension_dir);
my ($volume, $directories, $file) = File::Spec->splitpath($resolved_extension_dir);
my @dirs = grep { $_ ne '' } File::Spec->splitdir($directories);
pop @dirs;  # Remove the last directory (the extension dir name)
my $parent_dir = File::Spec->catpath($volume, File::Spec->catdir(@dirs), '');
if ($parent_dir ne $output_dir) {
    die "Refusing to package outside the requested output directory\n";
}

# Clean and copy extension directory
remove_tree($extension_dir) if -d $extension_dir;
make_path("$extension_dir/companion-service");

# Copy browser-extension contents
opendir(my $dh, "$ROOT/browser-extension") or die "Cannot open directory: $!";
my @entries = readdir($dh);
closedir($dh);
for my $entry (@entries) {
    next if $entry eq '.' || $entry eq '..';
    my $src = "$ROOT/browser-extension/$entry";
    my $dst = "$extension_dir/$entry";
    if (-d $src) {
        system("cp", "-r", $src, $dst) == 0 or die "Copy failed: $!";
    } else {
        copy($src, $dst) or die "Copy failed: $!";
    }
}

# Copy companion-service contents
opendir($dh, "$ROOT/companion-service") or die "Cannot open directory: $!";
@entries = readdir($dh);
closedir($dh);
for my $entry (@entries) {
    next if $entry eq '.' || $entry eq '..';
    my $src = "$ROOT/companion-service/$entry";
    my $dst = "$extension_dir/companion-service/$entry";
    if (-d $src) {
        system("cp", "-r", $src, $dst) == 0 or die "Copy failed: $!";
    } else {
        copy($src, $dst) or die "Copy failed: $!";
    }
}

# Write Windows batch file
{
    open my $fh, '>:encoding(UTF-8)', "$extension_dir/Sprachdienst-reparieren.cmd" or die "Cannot write batch file: $!";
    print $fh '@echo off' . "\r\n" . 'call "%~dp0companion-service\Sprachdienst-reparieren.cmd"' . "\r\n";
    close $fh;
}

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
{
    open my $fh, '>:encoding(UTF-8)', "$extension_dir/package.json" or die "Cannot write package.json: $!";
    print $fh to_json($package_json, { utf8 => 1, pretty => 1 }) . "\n";
    close $fh;
}

# Create extension zip
{
    my $zip = Archive::Zip->new();
    add_tree($zip, $extension_dir);
    die "Write error\n" unless $zip->writeToFileNamed($extension_zip) == AZ_OK;
}

# Create plugin zip
{
    my $zip = Archive::Zip->new();
    add_tree($zip, $ROOT, "tiktok-live-companion");
    die "Write error\n" unless $zip->writeToFileNamed($plugin_zip) == AZ_OK;
}

# Create service zip
{
    my $zip = Archive::Zip->new();
    add_tree($zip, "$ROOT/companion-service");
    die "Write error\n" unless $zip->writeToFileNamed($service_zip) == AZ_OK;
}

# Validate source directories
die "--ios-source and --android-source must point to existing source directories\n" 
    unless (-d $ios_source && -d $android_source);

# Create iOS source zip
{
    my $zip = Archive::Zip->new();
    add_tree($zip, $ios_source, "TikTokLiveCompanion-iOS");
    die "Write error\n" unless $zip->writeToFileNamed($ios_source_zip) == AZ_OK;
}

# Create Android source zip
{
    my $zip = Archive::Zip->new();
    add_tree($zip, $android_source, "TikTokLiveCompanion-Android");
    die "Write error\n" unless $zip->writeToFileNamed($android_source_zip) == AZ_OK;
}

# Handle Android APK
if ($android_apk) {
    die "--android-apk must point to an existing APK\n" 
        unless (-f $android_apk && $android_apk =~ /\.apk$/i);
    
    if (File::Spec->rel2abs($android_apk) ne File::Spec->rel2abs($android_apk_out)) {
        copy($android_apk, $android_apk_out) or die "Failed to copy APK: $!";
    }
}

# Calculate checksums
my @artifacts = ($extension_zip, $plugin_zip, $service_zip, $ios_source_zip, $android_source_zip);
push @artifacts, $android_apk_out if -f $android_apk_out;

my @checksums;
for my $artifact (@artifacts) {
    open my $fh, '<', $artifact or die "Cannot read $artifact: $!";
    binmode $fh;
    my $digest = sha256_hex(do { local $/; <$fh> });
    close $fh;
    my ($name) = ($artifact =~ /([^\/\\]+)$/);
    push @checksums, "$digest  $name";
}

{
    open my $fh, '>:encoding(UTF-8)', $checksum_file or die "Cannot write checksum file: $!";
    print $fh join("\n", @checksums) . "\n";
    close $fh;
}

# Output result JSON
my $result = {
    extension_dir => File::Spec->rel2abs($extension_dir),
    extension_zip => File::Spec->rel2abs($extension_zip),
    plugin_zip => File::Spec->rel2abs($plugin_zip),
    service_zip => File::Spec->rel2abs($service_zip),
    ios_source_zip => File::Spec->rel2abs($ios_source_zip),
    android_source_zip => File::Spec->rel2abs($android_source_zip),
    android_apk => (-f $android_apk_out) ? File::Spec->rel2abs($android_apk_out) : undef,
    checksum_file => File::Spec->rel2abs($checksum_file),
    version => $version
};

print encode_json($result) . "\n";
