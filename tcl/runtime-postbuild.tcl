#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "d7a8212dabc3e7c03186b60b8a2675c5cb897181bf734d5b9aac87f5b9d0146c", "source_sha256": "fd0e09df4d2dcc4aafd9784f264f0b9e5a046c02335886978c614026a9f3648c", "target_language": "tcl"}
# runtime-postbuild.mjs — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/runtime-postbuild.mjs
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

# Tcl 8.6 port of runtime-postbuild.mjs
# This script handles post-build operations for runtime assets

# Define global constants
set ROOT [file normalize [file dirname [file dirname [info script]]]]
set ROOT_RUNTIME_ALIAS_PATTERN {^(.+\.((runtime)|(contract)))-[A-Za-z0-9_-]+\.js$}

# Static extension assets array
array set STATIC_EXTENSION_ASSETS {
    0 {src extensions/acpx/src/runtime-internals/mcp-proxy.mjs dest dist/extensions/acpx/mcp-proxy.mjs}
    1 {src extensions/diffs/assets/viewer-runtime.js dest dist/extensions/diffs/assets/viewer-runtime.js}
}

# Helper procedure to check if a file exists
proc fileExists {filename} {
    return [expr {[catch {open $filename r} fid] == 0 && ([close $fid], 1) || 0}]
}

# Helper procedure to create directory recursively
proc mkdirRecursive {dir} {
    if {![file exists $dir]} {
        file mkdir $dir
    }
}

# Helper procedure to copy file
proc copyFile {src dest} {
    if {[fileExists $src]} {
        set in [open $src r]
        set out [open $dest w]
        fcopy $in $out
        close $in
        close $out
    }
}

# Procedure to list static extension asset outputs
proc listStaticExtensionAssetOutputs {{assets ""}} {
    if {$assets eq ""} {
        global STATIC_EXTENSION_ASSETS
        set assets [array get STATIC_EXTENSION_ASSETS]
    }
    
    set results {}
    foreach {index item} $assets {
        dict with item {dest}
        lappend results [string map {\\ /} $dest]
    }
    
    return [lsort -dictionary $results]
}

# Procedure to copy static extension assets
proc copyStaticExtensionAssets {{params ""}} {
    # Set default values
    set rootDir [dict getOrElse $params rootDir $::ROOT]
    set assets [dict getOrElse $params assets $::STATIC_EXTENSION_ASSETS]
    set warnProc [dict getOrElse $params warn {puts stderr}]
    
    foreach {index item} $assets {
        dict with item {src dest}
        set srcPath [file join $rootDir $src]
        set destPath [file join $rootDir $dest]
        
        if {[file exists $srcPath]} {
            mkdirRecursive [file dirname $destPath]
            copyFile $srcPath $destPath
        } else {
            {*}$warnProc "\[runtime-postbuild\] static asset not found, skipping: $src"
        }
    }
}

# Procedure to write text file if changed
proc writeTextFileIfChanged {filepath content} {
    set shouldWrite 1
    
    if {[file exists $filepath]} {
        set fh [open $filepath r]
        set existingContent [read $fh]
        close $fh
        
        if {$existingContent eq $content} {
            set shouldWrite 0
        }
    }
    
    if {$shouldWrite} {
        set fh [open $filepath w]
        puts -nonewline $fh $content
        close $fh
    }
}

# Procedure to write stable root runtime aliases
proc writeStableRootRuntimeAliases {{params ""}} {
    set rootDir [dict getOrElse $params rootDir $::ROOT]
    set distDir [file join $rootDir dist]
    
    if {![file isdirectory $distDir]} {
        return
    }
    
    set entries [glob -nocomplain -tails -directory $distDir *]
    
    foreach entry $entries {
        if {![file isfile [file join $distDir $entry]]} {
            continue
        }
        
        if {[regexp $::ROOT_RUNTIME_ALIAS_PATTERN $entry -> base]} {
            set aliasPath [file join $distDir ${base}.js]
            set content "export * from \"./$entry\";\n"
            writeTextFileIfChanged $aliasPath $content
        }
    }
}

# Main procedure to run all post-build operations
proc runRuntimePostBuild {{params ""}} {
    # These procedures would need to be implemented based on the imported modules
    # For now, we'll just call placeholder procedures
    
    # Placeholder implementations - these would need actual logic from other files
    proc copyPluginSdkRootAlias {args} {}
    proc copyBundledPluginMetadata {args} {}
    proc writeOfficialChannelCatalog {args} {}
    proc stageBundledPluginRuntimeDeps {args} {}
    proc stageBundledPluginRuntime {args} {}
    
    copyPluginSdkRootAlias $params
    copyBundledPluginMetadata $params
    writeOfficialChannelCatalog $params
    stageBundledPluginRuntimeDeps $params
    stageBundledPluginRuntime $params
    writeStableRootRuntimeAliases $params
    copyStaticExtensionAssets $params
}

# Run main procedure if this script is executed directly
if {[info script] eq $argv0} {
    runRuntimePostBuild
}

# Utility procedure for dictionary get with default
proc dict getOrElse {dict key default} {
    if {[dict exists $dict $key]} {
        return [dict get $dict $key]
    } else {
        return $default
    }
}
