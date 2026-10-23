#!/usr/bin/env tclsh
# package_artifacts.py — portiert nach tcl
# Quelle: python, Projects@TikTok-Live-Companion:plugin-source/scripts/package_artifacts.py
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/package_artifacts.py
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/package_artifacts.py
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/package_artifacts.py
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

package require Tcl 8.6
package require zipfile::encode
package require sha256
package require fileutil
package require cmdline
package require json

# Set up constants
set scriptDir [file normalize [file dirname [info script]]]
set ROOT [file dirname $scriptDir]
set PROJECT_ROOT [file dirname $ROOT]

# Excluded parts array
array set EXCLUDED_PARTS {}
foreach part {"__pycache__" ".gradle" ".kotlin" ".cxx" "build" "DerivedData" "xcuserdata" "Pods"} {
    set EXCLUDED_PARTS($part) 1
}

# Function to check if a path should be excluded
proc isExcluded {path} {
    global EXCLUDED_PARTS
    foreach part [split $path "/"] {
        if {[info exists EXCLUDED_PARTS($part)]} {
            return 1
        }
    }
    return 0
}

# Function to add tree to zip archive
proc addTree {archive source {prefix ""}} {
    global EXCLUDED_PARTS
    
    # Get all files recursively
    set files [glob -nocomplain -dir $source -types {f r} *]
    set dirs [list $source]
    
    while {[llength $dirs] > 0} {
        set newDirs {}
        foreach dir $dirs {
            lappend files {*}[glob -nocomplain -dir $dir -types {f r} *]
            lappend newDirs {*}[glob -nocomplain -dir $dir -types {d r} *]
        }
        set dirs $newDirs
    }
    
    # Sort files
    set files [lsort $files]
    
    foreach path $files {
        # Skip if not a file or should be excluded
        if {![file isfile $path]} continue
        if {[isExcluded $path]} continue
        if {[string match "*.pyc" $path] || [string match "*.aar" $path]} continue
        
        # Calculate relative path
        set relative [string range $path [string length $source]+1 end]
        
        # Create archive path
        set archivePath [file join $prefix $relative]
        set archivePath [string map {"/" "\\"} $archivePath]
        
        # Add file to archive with fixed timestamp
        set data [read [set fp [open $path rb]]]
        close $fp
        
        # Set external attributes based on filename
        set extAttr 0o100644
        if {[file tail $path] eq "gradlew"} {
            set extAttr 0o100755
        }
        set extAttr [expr {$extAttr << 16}]
        
        # Add to zip with compression level 9
        $archive addfile $archivePath -data $data -method deflate -level 9 -external_attributes $extAttr
    }
}

# Command line argument parsing
set optionSpec {
    {output-dir.arg "" "Output directory"}
    {android-apk.arg "" "Optional verified mockDebug or shazamDebug APK"}
    {android-source.arg "" "Verified Android source root"}
    {ios-source.arg "" "Verified iOS source root"}
    {native-shared-source.arg "" "Shared native audio source root"}
}

set usageMsg "Usage: package_artifacts.tcl \[options\]"
array set options [cmdline::typedGetoptions argv $optionSpec $usageMsg]

# Set defaults for optional arguments
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
set outputDir [file normalize $options(output-dir)]

# Read manifest to get version
set manifestFile [file join $ROOT browser-extension manifest.json]
if {![file exists $manifestFile]} {
    error "Manifest file not found: $manifestFile"
}
set manifest [json::json2dict [read [set fp [open $manifestFile r]]]]
close $fp
set version [dict get $manifest version]

# Define output filenames
set extensionZip [file join $outputDir "tiktok-live-companion-extension-$version.zip"]
set pluginZip [file join $outputDir "tiktok-live-companion-plugin-$version.zip"]
set serviceZip [file join $outputDir "tiktok-live-companion-service-$version.zip"]
set iosSourceZip [file join $outputDir "tiktok-live-companion-ios-$version-source.zip"]
set androidSourceZip [file join $outputDir "tiktok-live-companion-android-$version-source.zip"]
set androidApk [file join $outputDir "tiktok-live-companion-android-$version.apk"]
set extensionDir [file join $outputDir "tiktok-live-companion-extension-$version"]
set checksumFile [file join $outputDir "tiktok-live-companion-$version-SHA256.txt"]

# Validate extension directory location
set resolvedExtensionDir [file normalize $extensionDir]
if {[file dirname $resolvedExtensionDir] ne $outputDir} {
    error "Refusing to package outside the requested output directory"
}

# Clean and copy extension directory
if {[file exists $extensionDir]} {
    file delete -force $extensionDir
}
file copy [file join $ROOT browser-extension] $extensionDir
file copy [file join $ROOT companion-service] [file join $extensionDir companion-service]

# Write Windows batch file
set batchContent "@echo off\r\ncall \"%~dp0companion-service\\\\Sprachdienst-reparieren.cmd\"\\r\n"
set fp [open [file join $extensionDir "Sprachdienst-reparieren.cmd"] w]
puts -nonewline $fp $batchContent
close $fp

# Write package.json
set packageJson [dict create \
    name "tiktok-live-companion-extension-package" \
    private true \
    version $version \
    scripts [dict create \
        setup "npm --prefix companion-service run setup --" \
        start "npm --prefix companion-service start" \
        test "npm --prefix companion-service test" \
    ] \
]
set jsonData [json::dict2json $packageJson]
set fp [open [file join $extensionDir package.json] w]
puts $fp "$jsonData\n"
close $fp

# Create extension zip
set archive [zipfile::encode::create $extensionZip]
addTree $archive $extensionDir
$archive destroy

# Create plugin zip
set archive [zipfile::encode::create $pluginZip]
addTree $archive $ROOT "tiktok-live-companion"
$archive destroy

# Create service zip
set archive [zipfile::encode::create $serviceZip]
addTree $archive [file join $ROOT companion-service]
$archive destroy

# Resolve source paths
set iosSource [file normalize $options(ios-source)]
set androidSource [file normalize $options(android-source)]

# Validate source directories
if {![file isdirectory $iosSource] || ![file isdirectory $androidSource]} {
    error "--ios-source and --android-source must point to existing source directories"
}

set nativeShared [file normalize $options(native-shared-source)]
if {![file isfile [file join $nativeShared native tlc_peak_limiter.h]]} {
    error "Shared native limiter source is required for both mobile source packages"
}

# Create iOS source zip
set archive [zipfile::encode::create $iosSourceZip]
addTree $archive $iosSource "TikTokLiveCompanion-iOS"
addTree $archive $nativeShared "shared"
$archive destroy

# Create Android source zip
set archive [zipfile::encode::create $androidSourceZip]
addTree $archive $androidSource "TikTokLiveCompanion-Android"
addTree $archive $nativeShared "shared"
$archive destroy

# Handle Android APK if provided
if {$options(android-apk) ne ""} {
    set sourceApk [file normalize $options(android-apk)]
    if {![file isfile $sourceApk] || [string tolower [file extension $sourceApk]] ne ".apk"} {
        error "--android-apk must point to an existing APK"
    }
    if {$sourceApk ne [file normalize $androidApk]} {
        file copy -force $sourceApk $androidApk
    }
}

# Create checksums
set artifacts [list $extensionZip $pluginZip $serviceZip $iosSourceZip $androidSourceZip]
if {[file exists $androidApk]} {
    lappend artifacts $androidApk
}

set checksums {}
foreach artifact $artifacts {
    set fp [open $artifact rb]
    set data [read $fp]
    close $fp
    set digest [sha256::sha256 -bin $data]
    set hexDigest [binary encode hex $digest]
    lappend checksums "$hexDigest  [file tail $artifact]"
}

set fp [open $checksumFile w]
puts $fp [join $checksums "\n"]
close $fp

# Output result JSON
set result [dict create \
    extension_dir [file normalize $extensionDir] \
    extension_zip [file normalize $extensionZip] \
    plugin_zip [file normalize $pluginZip] \
    service_zip [file normalize $serviceZip] \
    ios_source_zip [file normalize $iosSourceZip] \
    android_source_zip [file normalize $androidSourceZip] \
    android_apk [expr {[file exists $androidApk] ? [file normalize $androidApk] : ""}] \
    checksum_file [file normalize $checksumFile] \
    version $version \
]

# Remove empty android_apk field if needed
if {[dict get $result android_apk] eq ""} {
    dict unset result android_apk
}

puts [json::dict2json $result]
