#!/usr/bin/env tclsh
# optimize-media.mjs — portiert nach tcl
# Quelle: javascript, Onboarding@main:scripts/optimize-media.mjs
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

# Tcl 8.6 port of optimize-media.mjs
# This script converts PNG files to WebP and AVIF formats using ImageMagick

package require Tcl 8.6

# Function to get directory contents
proc getDirectoryContents {dir} {
    if {[catch {glob -directory $dir -tails *.*} files]} {
        return {}
    }
    return $files
}

# Get the public/media directory path
set scriptDir [file dirname [file normalize $argv0]]
set mediaDir [file join $scriptDir ".." "public" "media"]

# Check if directory exists
if {![file isdirectory $mediaDir]} {
    puts stderr "Media directory not found: $mediaDir"
    exit 1
}

# Process each PNG file
set pngFiles [getDirectoryContents $mediaDir]
foreach file $pngFiles {
    # Skip non-PNG files
    if {![string match "*.png" $file]} {
        continue
    }
    
    # Get the base name without extension
    set stem [file rootname $file]
    
    # Source file path
    set sourcePath [file join $mediaDir $file]
    
    # Output paths
    set webpPath [file join $mediaDir "${stem}.webp"]
    set avifPath [file join $mediaDir "${stem}.avif"]
    
    # Convert to WebP with quality 84
    if {[catch {
        exec magick convert $sourcePath -quality 84 $webpPath
    } error]} {
        puts stderr "Failed to convert $file to WebP: $error"
    }
    
    # Convert to AVIF with quality 58
    if {[catch {
        exec magick convert $sourcePath -quality 58 $avifPath
    } error]} {
        puts stderr "Failed to convert $file to AVIF: $error"
    }
}

puts "WebP- und AVIF-Derivate erzeugt."
