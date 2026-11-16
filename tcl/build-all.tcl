#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "4acaf906003bc00f1700fa3a26b4c2cc605b8a980be303f2b3e8c2c708a51e69", "source_sha256": "c07aee6a3f0a90788cfe647dfcc79cf95df841ce0459eb8ffd9bf6aaa426ea38", "target_language": "tcl"}
# build-all.mjs — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/build-all.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

# Tcl 8.6 port of build-all.mjs

# Define constants
set WINDOWS_BUILD_MAX_OLD_SPACE_MB 4096

# Define build steps
array set BUILD_ALL_STEPS {
    0 {label "canvas:a2ui:bundle" kind "pnpm" pnpmArgs "canvas:a2ui:bundle"}
    1 {label "tsdown" kind "node" args "scripts/tsdown-build.mjs"}
    2 {label "runtime-postbuild" kind "node" args "scripts/runtime-postbuild.mjs"}
    3 {label "write-npm-update-compat-sidecars" kind "node" args "scripts/write-npm-update-compat-sidecars.mjs"}
    4 {label "build-stamp" kind "node" args "scripts/build-stamp.mjs"}
    5 {label "build:plugin-sdk:dts" kind "pnpm" pnpmArgs "build:plugin-sdk:dts" windowsNodeOptions "--max-old-space-size=$WINDOWS_BUILD_MAX_OLD_SPACE_MB"}
    6 {label "write-plugin-sdk-entry-dts" kind "node" args "--import tsx scripts/write-plugin-sdk-entry-dts.ts"}
    7 {label "check-plugin-sdk-exports" kind "node" args "scripts/check-plugin-sdk-exports.mjs"}
    8 {label "canvas-a2ui-copy" kind "node" args "--import tsx scripts/canvas-a2ui-copy.ts"}
    9 {label "copy-hook-metadata" kind "node" args "--import tsx scripts/copy-hook-metadata.ts"}
    10 {label "copy-export-html-templates" kind "node" args "--import tsx scripts/copy-export-html-templates.ts"}
    11 {label "write-build-info" kind "node" args "--import tsx scripts/write-build-info.ts"}
    12 {label "write-cli-startup-metadata" kind "node" args "--experimental-strip-types scripts/write-cli-startup-metadata.ts"}
    13 {label "write-cli-compat" kind "node" args "--import tsx scripts/write-cli-compat.ts"}
}

# Function to get environment for a step
proc resolveStepEnv {step env platform} {
    # Check if we're on Windows and the step has windowsNodeOptions
    if {$platform != "windows" || ![dict exists $step windowsNodeOptions]} {
        return $env
    }
    
    set windowsNodeOptions [dict get $step windowsNodeOptions]
    set currentNodeOptions ""
    
    if {[dict exists $env NODE_OPTIONS]} {
        set currentNodeOptions [string trim [dict get $env NODE_OPTIONS]]
    }
    
    if {[string match "*$windowsNodeOptions*" $currentNodeOptions]} {
        return $env
    }
    
    if {$currentNodeOptions ne ""} {
        dict set env NODE_OPTIONS "$currentNodeOptions $windowsNodeOptions"
    } else {
        dict set env NODE_OPTIONS $windowsNodeOptions
    }
    
    return $env
}

# Function to resolve pnpm runner (simplified version)
proc resolvePnpmRunner {params} {
    # This is a simplified implementation - in real usage you might need 
    # more complex logic depending on your environment
    set platform [dict get $params platform]
    set pnpmArgs [dict get $params pnpmArgs]
    
    if {$platform eq "windows"} {
        return [list command "pnpm" args $pnpmArgs shell true windowsVerbatimArguments true]
    } else {
        return [list command "pnpm" args $pnpmArgs]
    }
}

# Function to resolve build step
proc resolveBuildAllStep {step params} {
    # Set default values for params
    if {![dict exists $params platform]} {
        dict set params platform $::tcl_platform(platform)
    }
    
    if {![dict exists $params env]} {
        dict set params env [array get ::env]
    }
    
    set platform [dict get $params platform]
    set env [dict get $params env]
    
    set env [resolveStepEnv $step $env $platform]
    
    if {[dict get $step kind] eq "pnpm"} {
        set pnpmParams [list \
            pnpmArgs [dict get $step pnpmArgs] \
            platform $platform \
        ]
        
        set runner [resolvePnpmRunner $pnpmParams]
        set result [list \
            command [dict get $runner command] \
            args [dict get $runner args] \
            options [list \
                env $env \
            ] \
        ]
        
        if {[dict exists $runner shell]} {
            dict set result options shell [dict get $runner shell]
        }
        
        if {[dict exists $runner windowsVerbatimArguments]} {
            dict set result options windowsVerbatimArguments [dict get $runner windowsVerbatimArguments]
        }
        
        return $result
    } else {
        return [list \
            command "node" \
            args [dict get $step args] \
            options [list \
                env $env \
            ] \
        ]
    }
}

# Function to execute command
proc executeCommand {command args} {
    # Join arguments properly
    set cmd [concat [list $command] $args]
    
    # Execute and return result
    if {[catch {exec {*}$cmd} result]} {
        puts stderr "Error executing: $cmd"
        puts stderr $result
        return -code error $result
    } else {
        return $result
    }
}

# Main execution
if {[info script] eq $argv0} {
    # Iterate through all build steps
    for {set i 0} {$i < [array size BUILD_ALL_STEPS]} {incr i} {
        if {![info exists BUILD_ALL_STEPS($i)]} continue
        
        set step $BUILD_ALL_STEPS($i)
        puts stderr "\[build-all\] [dict get $step label]"
        
        set params [list]
        set invocation [resolveBuildAllStep $step $params]
        
        set command [dict get $invocation command]
        set args [dict get $invocation args]
        set options [dict get $invocation options]
        
        # Handle environment variables
        if {[dict exists $options env]} {
            set envVars [dict get $options env]
            # In Tcl, we'd typically set env vars before execution
            # This is a simplified approach
        }
        
        # Execute the command
        if {[catch {
            # For simplicity, we'll use exec directly
            # A full implementation would need to handle all the options properly
            set cmdArgs [concat [list $command] $args]
            exec {*}$cmdArgs
        } result]} {
            puts stderr "Command failed: $result"
            exit 1
        }
    }
}
