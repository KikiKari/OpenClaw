#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "7b383a129c002621ab5840cae639ab324639f2d3bed0a9d854c32667f47342f3", "source_sha256": "dc65d4759ce1efe8d0c6f037b64d65c1aa1f73b83a3cd928ceebdaf24ed53da6", "target_language": "tcl"}
# stage-bundled-plugin-runtime.mjs — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/stage-bundled-plugin-runtime.mjs
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

package require Tcl 8.6

# Helper functions
proc removePathIfExists {targetPath} {
    if {[file exists $targetPath]} {
        if {[catch {file delete -force $targetPath} err]} {
            error "Failed to remove path: $err"
        }
    }
}

proc symlinkType {} {
    if {$::tcl_platform(platform) eq "windows"} {
        return "junction"
    } else {
        return "dir"
    }
}

proc relativeSymlinkTarget {sourcePath targetPath} {
    set sourceDir [file dirname $targetPath]
    set relativeTarget [file join [file dirname $sourceDir] [file tail $sourcePath]]
    if {$relativeTarget eq ""} {
        return "."
    }
    return $relativeTarget
}

proc shouldFallbackToCopy {errorCode} {
    if {$::tcl_platform(platform) eq "windows"} {
        if {$errorCode in {"EPERM" "EINVAL" "UNKNOWN"}} {
            return 1
        }
    }
    return 0
}

proc copyPathFallback {sourcePath targetPath} {
    removePathIfExists $targetPath
    file mkdir [file dirname $targetPath]
    
    if {[file isdirectory $sourcePath]} {
        # Recursively copy directory
        foreach item [glob -nocomplain -dir $sourcePath *] {
            set itemName [file tail $item]
            copyPathFallback $item [file join $targetPath $itemName]
        }
    } else {
        # Copy file
        file copy $sourcePath $targetPath
    }
}

proc ensureSymlink {targetValue targetPath type fallbackSourcePath} {
    if {[catch {
        file link -symbolic $targetPath $targetValue
    } error]} {
        set errorCode [lindex [split $error ":"] 0]
        if {$fallbackSourcePath ne "" && [shouldFallbackToCopy $errorCode]} {
            copyPathFallback $fallbackSourcePath $targetPath
            return
        }
        
        if {![string match "*file already exists*" $error]} {
            error $error
        }
    }
    
    # Check if existing symlink matches our target
    if {[catch {
        if {[file type $targetPath] eq "link" && [file readlink $targetPath] eq $targetValue} {
            return
        }
    }]} {
        # Fall through and recreate if inspection fails
    }
    
    removePathIfExists $targetPath
    if {[catch {
        file link -symbolic $targetPath $targetValue
    } error]} {
        set errorCode [lindex [split $error ":"] 0]
        if {$fallbackSourcePath ne "" && [shouldFallbackToCopy $errorCode]} {
            copyPathFallback $fallbackSourcePath $targetPath
            return
        }
        error $error
    }
}

proc symlinkPath {sourcePath targetPath} {
    set type [symlinkType]
    ensureSymlink [relativeSymlinkTarget $sourcePath $targetPath] $targetPath $type $sourcePath
}

proc shouldWrapRuntimeJsFile {sourcePath} {
    return [string equal [file extension $sourcePath] ".js"]
}

proc shouldCopyRuntimeFile {sourcePath} {
    set normalizedPath [string map {\\ /} $sourcePath]
    set endings [list "/package.json" "/openclaw.plugin.json" "/.codex-plugin/plugin.json" \
                 "/.claude-plugin/plugin.json" "/.cursor-plugin/plugin.json" "/SKILL.md"]
    
    foreach ending $endings {
        if {[string match "*$ending" $normalizedPath]} {
            return 1
        }
    }
    return 0
}

proc writeRuntimeModuleWrapper {sourcePath targetPath} {
    set specifier [relativeSymlinkTarget $sourcePath $targetPath]
    set specifier [string map {\\ /} $specifier]
    
    if {![string match ".*" $specifier] && ![string match "/"* $specifier]} {
        set normalizedSpecifier "./$specifier"
    } else {
        set normalizedSpecifier $specifier
    }
    
    set content "export \\* from \[JSON::stringify $normalizedSpecifier\];\n"
    append content "import \\* as module from \[JSON::stringify $normalizedSpecifier\];\n"
    append content "export default module.default;\n\n"
    
    set fh [open $targetPath w]
    puts -nonewline $fh $content
    close $fh
}

proc stagePluginRuntimeOverlay {sourceDir targetDir} {
    file mkdir $targetDir
    
    set dirList [lsort [glob -nocomplain -dir $sourceDir *]]
    foreach item $dirList {
        set itemName [file tail $item]
        if {$itemName eq "node_modules"} {
            continue
        }
        
        set sourcePath $item
        set targetPath [file join $targetDir $itemName]
        
        if {[file isdirectory $sourcePath]} {
            stagePluginRuntimeOverlay $sourcePath $targetPath
            continue
        }
        
        if {[file type $sourcePath] eq "link"} {
            ensureSymlink [file readlink $sourcePath] $targetPath "" $sourcePath
            continue
        }
        
        if {![file isfile $sourcePath]} {
            continue
        }
        
        if {[shouldWrapRuntimeJsFile $sourcePath]} {
            writeRuntimeModuleWrapper $sourcePath $targetPath
            continue
        }
        
        if {[shouldCopyRuntimeFile $sourcePath]} {
            file copy $sourcePath $targetPath
            continue
        }
        
        symlinkPath $sourcePath $targetPath
    }
}

proc linkPluginNodeModules {params} {
    array set p $params
    set runtimeNodeModulesDir [file join $p(runtimePluginDir) "node_modules"]
    removePathIfExists $runtimeNodeModulesDir
    
    if {![file exists $p(sourcePluginNodeModulesDir)]} {
        return
    }
    
    ensureSymlink $p(sourcePluginNodeModulesDir) $runtimeNodeModulesDir [symlinkType] $p(sourcePluginNodeModulesDir)
}

proc stageBundledPluginRuntime {{params ""}} {
    # Default parameters handling
    if {$params eq ""} {
        set params [dict create]
    }
    
    if {[dict exists $params cwd]} {
        set repoRoot [dict get $params cwd]
    } elseif {[dict exists $params repoRoot]} {
        set repoRoot [dict get $params repoRoot]
    } else {
        set repoRoot [pwd]
    }
    
    set distRoot [file join $repoRoot "dist"]
    set runtimeRoot [file join $repoRoot "dist-runtime"]
    set distExtensionsRoot [file join $distRoot "extensions"]
    set runtimeExtensionsRoot [file join $runtimeRoot "extensions"]
    
    if {![file exists $distExtensionsRoot]} {
        removePathIfExists $runtimeRoot
        return
    }
    
    removePathIfExists $runtimeRoot
    file mkdir $runtimeExtensionsRoot
    
    set dirList [lsort [glob -nocomplain -dir $distExtensionsRoot *]]
    foreach item $dirList {
        if {![file isdirectory $item]} {
            continue
        }
        
        set pluginName [file tail $item]
        set distPluginDir $item
        set runtimePluginDir [file join $runtimeExtensionsRoot $pluginName]
        set distPluginNodeModulesDir [file join $distPluginDir "node_modules"]
        
        stagePluginRuntimeOverlay $distPluginDir $runtimePluginDir
        
        set linkParams [dict create \
            runtimePluginDir $runtimePluginDir \
            sourcePluginNodeModulesDir $distPluginNodeModulesDir]
        linkPluginNodeModules $linkParams
    }
}

# JSON stringify helper
proc ::JSON::stringify {str} {
    # Simple implementation for string quoting
    set result "\""
    foreach char [split $str ""] {
        switch $char {
            "\"" { append result "\\\"" }
            "\\" { append result "\\\\" }
            "\n" { append result "\\n" }
            "\r" { append result "\\r" }
            "\t" { append result "\\t" }
            default { append result $char }
        }
    }
    append result "\""
    return $result
}

# Main execution
if {[info script] eq $argv0} {
    stageBundledPluginRuntime
}
