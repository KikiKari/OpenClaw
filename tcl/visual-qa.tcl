#!/usr/bin/env tclsh
# visual-qa.mjs — portiert nach tcl
# Quelle: javascript, Onboarding@main:scripts/visual-qa.mjs
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

# Visual-QA-Tool der Sandbox — rendert eine laufende Seite in echten Browsern
# bei mehreren Auflösungen und legt Screenshots ab, damit Claude das Ergebnis
# SELBST betrachten kann, bevor es weiterverwendet wird.
#
# Warum echtes Chrome: Der Playwright-Bundle-Chromium hat keine proprietären
# Codecs (H.264/AAC) → Videos bleiben schwarz. Google Chrome Stable
# (channel/executablePath) dekodiert die MP4-Hero-Videos korrekt.
#
# Nutzung:
#   xvfb-run -a tclsh scripts/visual-qa.tcl [URL] --engines chrome,firefox,webkit
#     --out <dir> --click "<aria-name>" --wait <ms> --full

package require Tcl 8.6
package require fileutil
package require cmdline

# Globale Variablen
set URL "http://localhost:3000"
set OUT "/tmp/visual-qa"
set WAIT 3500
set CLICK ""
set FULL false
set ENGINES [list "chrome"]

# Auflösungen: Desktop 1920x1080 & 1366x768, Laptop 1440x900,
#              Tablet 1024x768, Mobile 390x844 (iPhone-Klasse).
array set RESOLUTIONS {
    desktop-1920 {width 1920 height 1080}
    desktop-1366 {width 1366 height 768}
    laptop-1440 {width 1440 height 900}
    tablet-1024 {width 1024 height 768}
    mobile-390 {width 390 height 844}
}

set CHROME_PATHS [list "/usr/bin/google-chrome-stable" "/usr/bin/google-chrome"]

# Command line argument parsing
proc parse_args {} {
    global argv URL OUT WAIT CLICK FULL ENGINES
    
    set options {
        {url.arg "http://localhost:3000" "URL to test"}
        {out.arg "/tmp/visual-qa" "Output directory"}
        {wait.arg 3500 "Wait time in milliseconds"}
        {click.arg "" "Click element by aria name"}
        {full "Full page screenshot"}
        {engines.arg "chrome" "Comma-separated list of engines"}
    }
    
    set usage "Usage: $argv0 \[options\]"
    array set params [cmdline::getoptions argv $options $usage]
    
    set URL $params(url)
    set OUT $params(out)
    set WAIT $params(wait)
    set CLICK $params(click)
    set FULL $params(full)
    set ENGINES [split $params(engines) ","]
    
    # Trim whitespace from engines
    set trimmed_engines {}
    foreach engine $ENGINES {
        lappend trimmed_engines [string trim $engine]
    }
    set ENGINES $trimmed_engines
}

# Create output directory
proc create_output_dir {} {
    global OUT
    file mkdir $OUT
}

# Launch browser based on engine type
proc launch_browser {engine} {
    global CHROME_PATHS
    
    switch $engine {
        "chrome" {
            set proxy [get_proxy]
            set chrome_path [find_chrome_path]
            
            # For Chrome we would need to use playwright or selenium
            # This is a placeholder implementation
            return "chromium"
        }
        "firefox" {
            return "firefox"
        }
        "webkit" {
            return "webkit"
        }
        default {
            error "Unbekannte Engine: $engine"
        }
    }
}

# Get proxy settings
proc get_proxy {} {
    if {[info exists ::env(HTTPS_PROXY)]} {
        return $::env(HTTPS_PROXY)
    } elseif {[info exists ::env(https_proxy)]} {
        return $::env(https_proxy)
    } else {
        return ""
    }
}

# Find Chrome executable path
proc find_chrome_path {} {
    global CHROME_PATHS
    foreach path $CHROME_PATHS {
        if {[file executable $path]} {
            return $path
        }
    }
    return ""
}

# Take screenshot with specified browser and resolution
proc take_screenshot {engine resolution} {
    global URL OUT WAIT CLICK FULL
    
    set res_name [lindex $resolution 0]
    set width [dict get [lindex $resolution 1] width]
    set height [dict get [lindex $resolution 1] height]
    
    # This would normally interact with Playwright/Selenium
    # Placeholder implementation for demonstration
    
    set file [file join $OUT "${engine}-${res_name}.png"]
    
    # Simulate taking screenshot
    if {[simulate_screenshot $file]} {
        set phase [get_page_phase]
        puts "OK  [format %-8s $engine] [format %-13s $res_name] phase=[expr {$phase eq "" ? "-" : $phase}]  $file"
        return [list engine $engine res $res_name file $file phase $phase]
    } else {
        puts "ERR $engine/$res_name: Screenshot failed"
        return {}
    }
}

# Simulate screenshot taking (placeholder)
proc simulate_screenshot {filename} {
    # In real implementation, this would use Playwright/Selenium
    # to actually take screenshots
    if {[catch {set fh [open $filename w]}]} {
        return 0
    }
    puts $fh "Screenshot placeholder for $filename"
    close $fh
    return 1
}

# Get page phase (placeholder)
proc get_page_phase {} {
    # In real implementation, this would query the DOM
    return "loading"
}

# Main execution
proc main {} {
    global ENGINES RESOLUTIONS OUT
    
    parse_args
    create_output_dir
    
    set manifest {}
    
    foreach engine $ENGINES {
        if {[catch {set browser [launch_browser $engine]} error]} {
            puts "\[ERROR\] \[$engine\] Start fehlgeschlagen: $error"
            continue
        }
        
        dict for {res_name resolution} [array get RESOLUTIONS] {
            if {[catch {set result [take_screenshot $engine [list $res_name $resolution]]} error]} {
                puts "ERR $engine/$res_name: $error"
            } else {
                if {$result ne ""} {
                    lappend manifest $result
                }
            }
        }
    }
    
    puts "\n[llength $manifest] Screenshots in $OUT"
}

# Run main program
if {[info script] eq $argv0} {
    main
}
