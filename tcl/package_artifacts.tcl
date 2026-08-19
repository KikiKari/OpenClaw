#!/usr/bin/env tclsh8.6
# package_artifacts.py — portiert nach tcl
# Quelle: python, Projects@TikTok-Live-Companion:plugin-source/scripts/package_artifacts.py
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/package_artifacts.py
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/package_artifacts.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

package require Tcl 8.6
package require zipfile::encode
package require fileutil
package require fileutil::traverse
package require json

# Global variables
set ROOT [file normalize [file dirname [file dirname [info script]]]]
set PROJECT_ROOT [file dirname $ROOT]
set EXCLUDED_PARTS [list "__pycache__" ".gradle" ".kotlin" "build" "DerivedData" "xcuserdata"]

# Function to add a tree to a zip archive
proc add_tree {archive source {prefix ""}} {
    global EXCLUDED_PARTS
    
    set files [list]
    ::fileutil::traverse::depthfirst $source {
        if {[file isfile $path]} {
            # Check if any part of the path is excluded
            set exclude false
            foreach part [file split $path] {
                if {$part in $EXCLUDED_PARTS} {
                    set exclude true
                    break
                }
            }
            
            # Check file extensions
            if {!$exclude && [file extension $path] ni {.pyc .aar}} {
                lappend files $path
            }
        }
    }
    
    # Sort files
    set files [lsort $files]
    
    foreach path $files {
        set relative [fileutil::stripPath $source $path]
        set archive_path [file join $prefix $relative]
        # Normalize path separators to forward slashes
        set archive_path [string map {\\ /} $archive_path]
        
        # Read file content
        set fh [open $path rb]
        set content [read $fh]
        close $fh
        
        # Add to zip with fixed timestamp
        $archive addFileEntry $archive_path $content \
            -method deflate \
            -level 9 \
            -time {1980 1 1 0 0 0}
    }
}

# Parse command line arguments
proc parse_args {} {
    global argv PROJECT_ROOT
    
    set options [dict create]
    dict set options output_dir ""
    dict set options android_apk ""
    dict set options android_source [file join $PROJECT_ROOT mobile android]
    dict set options ios_source [file join $PROJECT_ROOT mobile ios]
    
    for {set i 0} {$i < [llength $argv]} {incr i} {
        set arg [lindex $argv $i]
        switch -exact -- $arg {
            --output-dir {
                incr i
                dict set options output_dir [lindex $argv $i]
            }
            --android-apk {
                incr i
                dict set options android_apk [lindex $argv $i]
            }
            --android-source {
                incr i
                dict set options android_source [lindex $argv $i]
            }
            --ios-source {
                incr i
                dict set options ios_source [lindex $argv $i]
            }
            default {
                error "Unknown argument: $arg"
            }
        }
    }
    
    # Validate required arguments
    if {[dict get $options output_dir] eq ""} {
        error "--output-dir is required"
    }
    
    return $options
}

# Main function
proc main {} {
    global ROOT
    
    set args [parse_args]
    
    set output_dir [file normalize [dict get $args output_dir]]
    file mkdir $output_dir
    
    # Read manifest to get version
    set manifest_file [file join $ROOT browser-extension manifest.json]
    set manifest_fh [open $manifest_file r]
    set manifest_content [read $manifest_fh]
    close $manifest_fh
    set manifest [::json::json2dict $manifest_content]
    set version [dict get $manifest version]
    
    # Define output files
    set extension_zip [file join $output_dir "tiktok-live-companion-extension-${version}.zip"]
    set plugin_zip [file join $output_dir "tiktok-live-companion-plugin-${version}.zip"]
    set service_zip [file join $output_dir "tiktok-live-companion-service-${version}.zip"]
    set ios_source_zip [file join $output_dir "tiktok-live-companion-ios-${version}-source.zip"]
    set android_source_zip [file join $output_dir "tiktok-live-companion-android-${version}-source.zip"]
    set android_apk [file join $output_dir "tiktok-live-companion-android-${version}.apk"]
    set extension_dir [file join $output_dir "tiktok-live-companion-extension-${version}"]
    set checksum_file [file join $output_dir "tiktok-live-companion-${version}-SHA256.txt"]
    
    # Validate extension directory location
    set resolved_extension_dir [file normalize $extension_dir]
    if {[file dirname $resolved_extension_dir] ne $output_dir} {
        error "Refusing to package outside the requested output directory"
    }
    
    # Clean up previous extension directory
    if {[file exists $extension_dir]} {
        file delete -force $extension_dir
    }
    
    # Copy directories
    file copy [file join $ROOT browser-extension] $extension_dir
    file copy [file join $ROOT companion-service] [file join $extension_dir companion-service]
    
    # Create batch file
    set batch_content "@echo off\r\ncall \"%~dp0companion-service\\\\Sprachdienst-reparieren.cmd\"\r\n"
    set batch_fh [open [file join $extension_dir "Sprachdienst-reparieren.cmd"] w]
    puts -nonewline $batch_fh $batch_content
    close $batch_fh
    
    # Create package.json
    set package_json [dict create \
        name "tiktok-live-companion-extension-package" \
        private true \
        version $version \
        scripts [dict create \
            setup "npm --prefix companion-service run setup --" \
            start "npm --prefix companion-service start" \
            test "npm --prefix companion-service test"]]
    
    set package_fh [open [file join $extension_dir package.json] w]
    puts $package_fh [::json::dict2json $package_json]
    close $package_fh
    
    # Create extension zip
    set ext_zip [zipfile::encode::open $extension_zip]
    add_tree $ext_zip $extension_dir
    zipfile::encode::close $ext_zip
    
    # Create plugin zip
    set plugin_zip_obj [zipfile::encode::open $plugin_zip]
    add_tree $plugin_zip_obj $ROOT "tiktok-live-companion"
    zipfile::encode::close $plugin_zip_obj
    
    # Create service zip
    set service_zip_obj [zipfile::encode::open $service_zip]
    add_tree $service_zip_obj [file join $ROOT companion-service]
    zipfile::encode::close $service_zip_obj
    
    # Resolve source directories
    set ios_source [file normalize [dict get $args ios_source]]
    set android_source [file normalize [dict get $args android_source]]
    
    if {![file isdirectory $ios_source] || ![file isdirectory $android_source]} {
        error "--ios-source and --android-source must point to existing source directories"
    }
    
    # Create iOS source zip
    set ios_zip_obj [zipfile::encode::open $ios_source_zip]
    add_tree $ios_zip_obj $ios_source "TikTokLiveCompanion-iOS"
    zipfile::encode::close $ios_zip_obj
    
    # Create Android source zip
    set android_zip_obj [zipfile::encode::open $android_source_zip]
    add_tree $android_zip_obj $android_source "TikTokLiveCompanion-Android"
    zipfile::encode::close $android_zip_obj
    
    # Handle Android APK if provided
    if {[dict get $args android_apk] ne ""} {
        set source_apk [file normalize [dict get $args android_apk]]
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
    
    set checksums [list]
    foreach artifact $artifacts {
        set fh [open $artifact rb]
        set content [read $fh]
        close $fh
        set digest [sha256::sha256 -hex $content]
        lappend checksums "$digest  [file tail $artifact]"
    }
    
    set checksum_fh [open $checksum_file w]
    puts $checksum_fh [join $checksums \n]
    close $checksum_fh
    
    # Output result JSON
    set result [dict create \
        extension_dir [file normalize $extension_dir] \
        extension_zip [file normalize $extension_zip] \
        plugin_zip [file normalize $plugin_zip] \
        service_zip [file normalize $service_zip] \
        ios_source_zip [file normalize $ios_source_zip] \
        android_source_zip [file normalize $android_source_zip] \
        android_apk [expr {[file exists $android_apk] ? [file normalize $android_apk] : ""}] \
        checksum_file [file normalize $checksum_file] \
        version $version]
    
    puts [::json::dict2json $result]
}

# Load required packages
if {[catch {package require sha256}]} {
    # If sha256 package is not available, implement our own
    proc sha256 {data} {
        error "SHA256 implementation needed but not available"
    }
} else {
    # Create a wrapper for the hex format
    proc sha256::sha256 {args} {
        set opts [lassign $args data]
        set hex 0
        foreach {opt val} $opts {
            if {$opt eq "-hex"} {
                set hex 1
            }
        }
        set result [::sha256::sha256 $data]
        if {$hex} {
            binary scan $result H* result
        }
        return $result
    }
}

# Run main function
main
