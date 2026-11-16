#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "52d2c5caa84276ef1b8a81def6a962c9db7a8418517e237c0eab37f819bcb052", "source_sha256": "ea352b99923506af9c3ce8c6a36ed51f94a6d895a48b5e6aeebdb0322ed9e62d", "target_language": "tcl"}
# bundled-plugin-root-runtime-mirrors.mjs — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/bundled-plugin-root-runtime-mirrors.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

# Tcl 8.6 port of bundled-plugin-root-runtime-mirrors.mjs

package require json
package require fileutil

namespace eval ::bundled_plugin_runtime_mirrors {
    variable JS_EXTENSIONS [dict create .cjs 1 .js 1 .mjs 1]

    # Collect runtime dependency specifications from package.json
    proc collectRuntimeDependencySpecs {{packageJson ""}} {
        set specs [dict create]
        
        if {$packageJson eq ""} {
            return $specs
        }
        
        # Process dependencies
        if {[dict exists $packageJson dependencies]} {
            dict for {name version [dict get $packageJson dependencies]} {
                if {$version ne ""} {
                    dict set specs $name $version
                }
            }
        }
        
        # Process optionalDependencies
        if {[dict exists $packageJson optionalDependencies]} {
            dict for {name version [dict get $packageJson optionalDependencies]} {
                if {$version ne ""} {
                    dict set specs $name $version
                }
            }
        }
        
        return $specs
    }

    # Extract package name from module specifier
    proc packageNameFromSpecifier {specifier} {
        # Check invalid specifiers
        if {![string is list $specifier] || 
            [string match .* $specifier] || 
            [string match /* $specifier] || 
            [string match node:* $specifier] || 
            [string match #* $specifier]} {
            return ""
        }
        
        # Split and process
        set parts [split $specifier /]
        if {[llength $parts] == 0} {
            return ""
        }
        
        set first [lindex $parts 0]
        if {[string match @* $first] && [llength $parts] >= 2} {
            return "$first/[lindex $parts 1]"
        } else {
            return $first
        }
    }

    # Read JSON file
    proc readJson {filePath} {
        set fd [open $filePath r]
        set content [read $fd]
        close $fd
        return [::json::json2dict $content]
    }

    # Collect package.json paths in directory
    proc collectPackageJsonPaths {rootDir} {
        set paths [list]
        
        if {![file exists $rootDir]} {
            return $paths
        }
        
        set entries [glob -nocomplain -directory $rootDir -types d *]
        foreach entry $entries {
            set packageJsonPath [file join $entry package.json]
            if {[file exists $packageJsonPath]} {
                lappend paths $packageJsonPath
            }
        }
        
        return [lsort $paths]
    }

    # Collect bundled plugin runtime dependency specifications
    proc collectBundledPluginRuntimeDependencySpecs {bundledPluginsDir} {
        set specs [dict create]
        
        foreach packageJsonPath [collectPackageJsonPaths $bundledPluginsDir] {
            set packageJson [readJson $packageJsonPath]
            set pluginId [file tail [file dirname $packageJsonPath]]
            
            foreach {name spec} [collectRuntimeDependencySpecs $packageJson] {
                if {[dict exists $specs $name]} {
                    set existing [dict get $specs $name]
                    set existingSpec [dict get $existing spec]
                    set conflicts [dict get $existing conflicts]
                    set pluginIds [dict get $existing pluginIds]
                    
                    if {$existingSpec ne $spec} {
                        lappend conflicts [dict create pluginId $pluginId spec $spec]
                        dict set specs $name conflicts $conflicts
                    } elseif {![lsearch -exact $pluginIds $pluginId] >= 0} {
                        lappend pluginIds $pluginId
                        dict set specs $name pluginIds $pluginIds
                    }
                } else {
                    dict set specs $name [dict create conflicts [list] pluginIds [list $pluginId] spec $spec]
                }
            }
        }
        
        return $specs
    }

    # Walk JavaScript files recursively
    proc walkJavaScriptFiles {rootDir} {
        set files [list]
        
        if {![file exists $rootDir]} {
            return $files
        }
        
        set queue [list $rootDir]
        while {[llength $queue] > 0} {
            set current [lindex $queue 0]
            set queue [lrange $queue 1 end]
            
            set entries [glob -nocomplain -directory $current *]
            foreach entry $entries {
                set fullPath $entry
                if {[file isdirectory $fullPath]} {
                    # Skip extensions directories
                    if {[string match "*extensions*" $fullPath]} {
                        continue
                    }
                    lappend queue $fullPath
                    continue
                }
                
                if {[file isfile $fullPath]} {
                    set ext [file extension $fullPath]
                    variable JS_EXTENSIONS
                    if {[dict exists $JS_EXTENSIONS $ext]} {
                        lappend files $fullPath
                    }
                }
            }
        }
        
        return [lsort $files]
    }

    # Extract module specifiers from source code
    proc extractModuleSpecifiers {source} {
        set specifiers [dict create]
        
        # Patterns to match import/require statements
        set patterns [list \
            {\yfrom\s*["']([^"']+)["']} \
            {\yimport\s*["']([^"']+)["']} \
            {\yimport\s*\(\s*["']([^"']+)["']\s*\)} \
            {\yrequire\s*\(\s*["']([^"']+)["']\s*\)} \
        ]
        
        foreach pattern $patterns {
            set matches [regexp -all -inline $pattern $source]
            foreach match $matches {
                set specifier [lindex [regexp -inline $pattern $source] 1]
                if {$specifier ne ""} {
                    dict set specifiers $specifier 1
                }
            }
        }
        
        return $specifiers
    }

    # Collect root distribution bundled runtime mirrors
    proc collectRootDistBundledRuntimeMirrors {params} {
        set distDir [dict get $params distDir]
        set bundledSpecs [dict get $params bundledRuntimeDependencySpecs]
        set mirrors [dict create]
        
        foreach filePath [walkJavaScriptFiles $distDir] {
            set fd [open $filePath r]
            set source [read $fd]
            close $fd
            
            # Calculate relative path
            set relativePath [string map {\\ /} [fileutil::stripPath $distDir $filePath]]
            
            foreach specifier [dict keys [extractModuleSpecifiers $source]] {
                set dependencyName [packageNameFromSpecifier $specifier]
                if {$dependencyName eq "" || ![dict exists $bundledSpecs $dependencyName]} {
                    continue
                }
                
                set bundledSpec [dict get $bundledSpecs $dependencyName]
                if {[dict exists $mirrors $dependencyName]} {
                    set existing [dict get $mirrors $dependencyName]
                    set importers [dict get $existing importers]
                    dict set importers $relativePath 1
                    dict set existing importers $importers
                    dict set mirrors $dependencyName $existing
                } else {
                    set pluginIds [dict get $bundledSpec pluginIds]
                    set spec [dict get $bundledSpec spec]
                    dict set mirrors $dependencyName [dict create importers [dict create $relativePath 1] pluginIds $pluginIds spec $spec]
                }
            }
        }
        
        return $mirrors
    }

    # Collect bundled plugin root runtime mirror errors
    proc collectBundledPluginRootRuntimeMirrorErrors {params} {
        set rootPackageJson [dict get $params rootPackageJson]
        set bundledRuntimeDependencySpecs [dict get $params bundledRuntimeDependencySpecs]
        set requiredRootMirrors [dict get $params requiredRootMirrors]
        
        set rootRuntimeDeps [collectRuntimeDependencySpecs $rootPackageJson]
        set errors [list]
        
        # Check for conflicts in bundled dependencies
        dict for {dependencyName record $bundledRuntimeDependencySpecs} {
            set conflicts [dict get $record conflicts]
            foreach conflict $conflicts {
                set pluginIds [dict get $record pluginIds]
                set spec [dict get $record spec]
                set conflictPluginId [dict get $conflict pluginId]
                set conflictSpec [dict get $conflict spec]
                lappend errors "bundled runtime dependency '$dependencyName' has conflicting plugin specs: [join $pluginIds ", "] use '$spec', $conflictPluginId uses '$conflictSpec'."
            }
        }
        
        # Check required root mirrors
        dict for {dependencyName mirror $requiredRootMirrors} {
            set rootSpec ""
            if {[dict exists $rootRuntimeDeps $dependencyName]} {
                set rootSpec [dict get $rootRuntimeDeps $dependencyName]
            }
            
            set importers [lsort [dict keys [dict get $mirror importers]]]
            set importerLabel [join $importers ", "]
            set pluginIds [dict get $mirror pluginIds]
            set pluginLabel [join [lsort $pluginIds] ", "]
            set spec [dict get $mirror spec]
            
            if {$rootSpec eq ""} {
                lappend errors "root dist imports bundled plugin runtime dependency '$dependencyName' from $importerLabel; mirror '$dependencyName: $spec' in root package.json (declared by $pluginLabel)."
                continue
            }
            
            if {$rootSpec ne $spec} {
                lappend errors "root dist imports bundled plugin runtime dependency '$dependencyName' from $importerLabel; root package.json has '$rootSpec' but plugin manifest declares '$spec' ($pluginLabel)."
            }
        }
        
        return $errors
    }
}

# Export functions
proc collectRuntimeDependencySpecs {{packageJson ""}} {
    return [::bundled_plugin_runtime_mirrors::collectRuntimeDependencySpecs $packageJson]
}

proc packageNameFromSpecifier {specifier} {
    return [::bundled_plugin_runtime_mirrors::packageNameFromSpecifier $specifier]
}

proc collectBundledPluginRuntimeDependencySpecs {bundledPluginsDir} {
    return [::bundled_plugin_runtime_mirrors::collectBundledPluginRuntimeDependencySpecs $bundledPluginsDir]
}

proc collectRootDistBundledRuntimeMirrors {params} {
    return [::bundled_plugin_runtime_mirrors::collectRootDistBundledRuntimeMirrors $params]
}

proc collectBundledPluginRootRuntimeMirrorErrors {params} {
    return [::bundled_plugin_runtime_mirrors::collectBundledPluginRootRuntimeMirrorErrors $params]
}
