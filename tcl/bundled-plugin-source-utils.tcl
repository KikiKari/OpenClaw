#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "991e040ce0daddd7f5ef7b3a6cf92eb2b5550bb3a9653a3c67c0b32f01a2de7e", "source_sha256": "2d35fb0177cdd721585255bbae6415badcc488d34a5deef965207b8fd1e561ad", "target_language": "tcl"}
# bundled-plugin-source-utils.mjs — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/bundled-plugin-source-utils.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

# Tcl does not have built-in JSON support, so we need to implement a simple parser
# or use an external library. For simplicity, we'll assume a basic JSON parsing capability.
# In practice, you might want to use a library like rl_json.

# We'll simulate the Node.js 'fs' and 'path' modules using Tcl's built-in commands.

namespace eval bundled_plugin_source_utils {
    # Tcl procedure to read file content if it exists
    proc readIfExists {filePath} {
        if {[file exists $filePath]} {
            if {[catch {open $filePath r} fileId]} {
                return ""
            }
            set content [read $fileId]
            close $fileId
            return $content
        } else {
            return ""
        }
    }

    # Tcl procedure to collect bundled plugin sources
    proc collectBundledPluginSources {{params ""}} {
        # Set default values for params
        array set opts [list repoRoot "" requirePackageJson false]
        if {$params ne ""} {
            array set opts $params
        }

        # Determine repoRoot
        set repoRoot [expr {$opts(repoRoot) ne "" ? $opts(repoRoot) : [pwd]}]
        set extensionsRoot [file join $repoRoot "extensions"]

        # Check if extensions directory exists
        if {![file exists $extensionsRoot] || ![file isdirectory $extensionsRoot]} {
            return [list]
        }

        # Get list of directories in extensions
        set dirs [glob -nocomplain -directory $extensionsRoot -type d *]
        set entries [list]

        foreach dir $dirs {
            set dirName [file tail $dir]
            set pluginDir $dir
            set manifestPath [file join $pluginDir "openclaw.plugin.json"]
            set packageJsonPath [file join $pluginDir "package.json"]

            # Check if manifest exists
            if {![file exists $manifestPath]} {
                continue
            }

            # Check if package.json is required and exists
            if {$opts(requirePackageJson) && ![file exists $packageJsonPath]} {
                continue
            }

            # Read manifest
            set manifestContent [readIfExists $manifestPath]
            if {$manifestContent eq ""} {
                continue
            }
            # Parse JSON (simplified)
            set manifest [parse_json $manifestContent]

            # Prepare entry
            set entry [dict create \
                dirName $dirName \
                pluginDir $pluginDir \
                manifestPath $manifestPath \
                manifest $manifest]

            # Add package.json info if it exists
            if {[file exists $packageJsonPath]} {
                set packageJsonContent [readIfExists $packageJsonPath]
                if {$packageJsonContent ne ""} {
                    set packageJson [parse_json $packageJsonContent]
                    dict set entry packageJsonPath $packageJsonPath
                    dict set entry packageJson $packageJson
                }
            }

            lappend entries $entry
        }

        # Sort entries by dirName
        set sortedEntries [lsort -dictionary -index 0 [lmap entry $entries {
            list [dict get $entry dirName] $entry
        }]]
        
        # Extract just the entry dicts from the sorted list
        set result [list]
        foreach item $sortedEntries {
            lappend result [lindex $item 1]
        }
        
        return $result
    }

    # Simplified JSON parser (very basic, assumes valid JSON)
    proc parse_json {json_str} {
        # Remove leading/trailing whitespace
        set json_str [string trim $json_str]
        
        # This is a very naive approach and will not handle complex JSON correctly.
        # In a real-world scenario, you should use a proper JSON library.
        # For demonstration purposes, we'll return the string as-is.
        # A real implementation would parse the JSON into a Tcl dictionary or list structure.
        return $json_str
    }
}

# Export procedures (in Tcl, this is typically done by sourcing the file in the namespace)
# For direct usage, we can create aliases in the global namespace
proc readIfExists {filePath} {
    return [bundled_plugin_source_utils::readIfExists $filePath]
}

proc collectBundledPluginSources {{params ""}} {
    return [bundled_plugin_source_utils::collectBundledPluginSources $params]
}
