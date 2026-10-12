#!/usr/bin/env tclsh8.6
# package_artifacts.py — portiert nach tcl
# Quelle: python, Projects@TikTok-Live-Companion:plugin-source/scripts/package_artifacts.py
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/package_artifacts.py
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/package_artifacts.py
# auch in: Projects@codex/0pe-177-peak-protection:plugin-source/scripts/package_artifacts.py
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

package require Tcl 8.6
package require zipfile::encode
package require sha256
package require fileutil
package require json
package require cmdline

# Global variables
set ROOT [file normalize [file dirname [info script]]]
set PROJECT_ROOT [file dirname $ROOT]
array set EXCLUDED_PARTS [list __pycache__ {} .gradle {} .kotlin {} .cxx {} build {} DerivedData {} xcuserdata {} Pods {}]

# Function to add directory tree to zip archive
proc add_tree {archive source prefix} {
    global EXCLUDED_PARTS
    
    # Get all files recursively
    set files [lsort [glob -nocomplain -dir $source -types f - recurse *]]
    
    foreach filepath $files {
        # Check if file should be excluded
        set exclude 0
        set relpath [fileutil::stripPath $source $filepath]
        
        # Check path parts
        foreach part [file split $relpath] {
            if {[info exists EXCLUDED_PARTS($part)]} {
                set exclude 1
                break
            }
        }
        
        # Check file extension
        if {!$exclude && [string match *.pyc [file extension $filepath]]} {
            set exclude 1
        }
        if {!$exclude && [string match *.aar [file extension $filepath]]} {
            set exclude 1
        }
        
        if {$exclude} continue
        
        # Calculate archive path
        set archive_path [file join $prefix $relpath]
        set archive_path [string map {\\ /} $archive_path] ;# Convert Windows path separators
        
        # Read file content
        set fh [open $filepath rb]
        set content [read $fh]
        close $fh
        
        # Set file permissions
        set mode 0o100644
        if {[file tail $filepath] eq "gradlew"} {
            set mode 0o100755
        }
        
        # Add to archive with fixed timestamp
        $archive addFile $archive_path -data $content -method deflate -level 9 -mtime {1980 1 1 0 0 0} -unix_mode $mode
    }
}

# Parse command line arguments
set optionSpec {
    {output-dir.arg "" "Output directory"}
    {android-apk.arg "" "Optional verified mockDebug or shazamDebug APK"}
    {android-source.arg "" "Verified Android source root"}
    {ios-source.arg "" "Verified iOS source root"}
    {native-shared-source.arg "" "Shared native audio source root"}
}

set usage "Usage: [file tail $argv0] \[options\]"
array set options [cmdline::typedGetoptions argv $optionSpec $usage]

# Set defaults for optional parameters
if {$options(android-source) eq ""} {
    set options(android-source) [file join $PROJECT_ROOT mobile android]
}
if {$options(ios-source) eq ""} {
    set options(ios-source) [file join $PROJECT_ROOT mobile ios]
}
if {$options(native-shared-source) eq ""} {
    set options(native-shared-source) [file join $PROJECT_ROOT mobile shared]
}

# Validate required arguments
if {$options(output-dir) eq ""} {
    puts stderr "Error: --output-dir is required"
    exit 1
}

# Create output directory
file mkdir $options(output-dir)
set output_dir [file normalize $options(output-dir)]

# Read manifest to get version
set manifest_file [file join $ROOT browser-extension manifest.json]
set manifest_fh [open $manifest_file r]
set manifest_content [read $manifest_fh]
close $manifest_fh
set manifest [json::json2dict $manifest_content]
set version [dict get $manifest version]

# Define output filenames
set extension_zip [file join $output_dir "tiktok-live-companion-extension-$version.zip"]
set plugin_zip [file join $output_dir "tiktok-live-companion-plugin-$version.zip"]
set service_zip [file join $output_dir "tiktok-live-companion-service-$version.zip"]
set ios_source_zip [file join $output_dir "tiktok-live-companion-ios-$version-source.zip"]
set android_source_zip [file join $output_dir "tiktok-live-companion-android-$version-source.zip"]
set android_apk [file join $output_dir "tiktok-live-companion-android-$version.apk"]
set extension_dir [file join $output_dir "tiktok-live-companion-extension-$version"]
set checksum_file [file join $output_dir "tiktok-live-companion-$version-SHA256.txt"]

# Validate extension directory location
set resolved_extension_dir [file normalize $extension_dir]
if {[file dirname $resolved_extension_dir] ne $output_dir} {
    error "Refusing to package outside the requested output directory"
}

# Clean and recreate extension directory
if {[file exists $extension_dir]} {
    file delete -force $extension_dir
}

# Copy browser extension
file copy -force [file join $ROOT browser-extension] $extension_dir

# Copy companion service
file copy -force [file join $ROOT companion-service] [file join $extension_dir companion-service]

# Write Windows batch file
set batch_fh [open [file join $extension_dir "Sprachdienst-reparieren.cmd"] w]
puts $batch_fh "@echo off\r"
puts $batch_fh {call "%~dp0companion-service\Sprachdienst-reparieren.cmd"}
puts $batch_fh ""
close $batch_fh

# Write package.json
set package_json [dict create \
    name "tiktok-live-companion-extension-package" \
    private true \
    version $version \
    scripts [dict create \
        setup "npm --prefix companion-service run setup --" \
        start "npm --prefix companion-service start" \
        test "npm --prefix companion-service test" \
    ] \
]

set package_fh [open [file join $extension_dir package.json] w]
puts $package_fh [json::dict2json $package_json]
close $package_fh

# Create extension zip
set ext_zip [zipfile::encode::open $extension_zip]
add_tree $ext_zip $extension_dir ""
$ext_zip close

# Create plugin zip
set plugin_zip_obj [zipfile::encode::open $plugin_zip]
add_tree $plugin_zip_obj $ROOT "tiktok-live-companion"
$plugin_zip_obj close

# Create service zip
set service_zip_obj [zipfile::encode::open $service_zip]
add_tree $service_zip_obj [file join $ROOT companion-service] ""
$service_zip_obj close

# Resolve source paths
set ios_source [file normalize $options(ios-source)]
set android_source [file normalize $options(android-source)]

# Validate source directories
if {![file isdirectory $ios_source] || ![file isdirectory $android_source]} {
    error "--ios-source and --android-source must point to existing source directories"
}

set native_shared [file normalize $options(native-shared-source)]
if {![file isfile [file join $native_shared native tlc_peak_limiter.h]]} {
    error "Shared native limiter source is required for both mobile source packages"
}

# Create iOS source zip
set ios_zip_obj [zipfile::encode::open $ios_source_zip]
add_tree $ios_zip_obj $ios_source "TikTokLiveCompanion-iOS"
add_tree $ios_zip_obj $native_shared "shared"
$ios_zip_obj close

# Create Android source zip
set android_zip_obj [zipfile::encode::open $android_source_zip]
add_tree $android_zip_obj $android_source "TikTokLiveCompanion-Android"
add_tree $android_zip_obj $native_shared "shared"
$android_zip_obj close

# Handle Android APK if provided
if {$options(android-apk) ne ""} {
    set source_apk [file normalize $options(android-apk)]
    if {![file isfile $source_apk] || [string tolower [file extension $source_apk]] ne ".apk"} {
        error "--android-apk must point to an existing APK"
    }
    if {$source_apk ne [file normalize $android_apk]} {
        file copy -force $source_apk $android_apk
    }
}

# Create checksums
set artifacts [list $extension_zip $plugin_zip $service_zip $ios_source_zip $android_source_zip]
if {[file exists $android_apk]} {
    lappend artifacts $android_apk
}

set checksums {}
foreach artifact $artifacts {
    set fh [open $artifact rb]
    set content [read $fh]
    close $fh
    set digest [sha256::sha256 -bin $content]
    set hex_digest [binary encode hex $digest]
    lappend checksums "$hex_digest  [file tail $artifact]"
}

set checksum_fh [open $checksum_file w]
puts $checksum_fh [join $checksums "\n"]
puts $checksum_fh ""
close $checksum_fh

# Output result JSON
set result_dict [dict create \
    extension_dir [file normalize $extension_dir] \
    extension_zip [file normalize $extension_zip] \
    plugin_zip [file normalize $plugin_zip] \
    service_zip [file normalize $service_zip] \
    ios_source_zip [file normalize $ios_source_zip] \
    android_source_zip [file normalize $android_source_zip] \
    checksum_file [file normalize $checksum_file] \
    version $version \
]

if {[file exists $android_apk]} {
    dict set result_dict android_apk [file normalize $android_apk]
} else {
    dict set result_dict android_apk null
}

puts [json::dict2json $result_dict]
