#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "13e593cbb585a8935def25423eb1fb7fc4bf354cad76f54601ceb53358f35083", "source_sha256": "44c9196ec2dbaf8ef45323397e44f66d128313ddae44f9dfc8bba7439fe6e844", "target_language": "tcl"}
# sync-plugin-sdk-exports.mjs — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/sync-plugin-sdk-exports.mjs
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

package require json
package require json::write

# Function to check if a list contains a value
proc contains {list value} {
    expr {[lsearch -exact $list $value] != -1}
}

# Function to read file and parse JSON
proc read_package_json {path} {
    set fh [open $path r]
    set content [read $fh]
    close $fh
    return [json::json2dict $content]
}

# Function to write package.json with proper formatting
proc write_package_json {path data} {
    set formatted [json::write::indented $data]
    append formatted "\n"
    set fh [open $path w]
    puts -nonewline $fh $formatted
    close $fh
}

# Function to build plugin SDK exports (stub - replace with actual implementation)
proc buildPluginSdkPackageExports {} {
    # This should be replaced with the actual logic from lib/plugin-sdk-entries.mjs
    # For now, returning an empty dict as placeholder
    return [dict create]
}

# Main script logic
set argv $::argv
set checkOnly [contains $argv "--check"]

# Get current working directory and package.json path
set cwd [pwd]
set packageJsonPath [file join $cwd "package.json"]

# Read and parse package.json
set packageJson [read_package_json $packageJsonPath]

# Get current exports or empty dict if not exists
if {[dict exists $packageJson "exports"]} {
    set currentExports [dict get $packageJson "exports"]
} else {
    set currentExports [dict create]
}

# Build synced plugin SDK exports
set syncedPluginSdkExports [buildPluginSdkPackageExports]

# Build next exports
set nextExports [dict create]
set insertedPluginSdkExports false

# Iterate through current exports
foreach {key value} $currentExports {
    if {[string match "./plugin-sdk*" $key]} {
        if {!$insertedPluginSdkExports} {
            # Merge syncedPluginSdkExports into nextExports
            foreach {sdk_key sdk_value} $syncedPluginSdkExports {
                dict set nextExports $sdk_key $sdk_value
            }
            set insertedPluginSdkExports true
        }
        # Skip this key (continue)
    } else {
        dict set nextExports $key $value
        if {$key eq "." && !$insertedPluginSdkExports} {
            # Merge syncedPluginSdkExports into nextExports
            foreach {sdk_key sdk_value} $syncedPluginSdkExports {
                dict set nextExports $sdk_key $sdk_value
            }
            set insertedPluginSdkExports true
        }
    }
}

# If we haven't inserted plugin SDK exports yet, do it now
if {!$insertedPluginSdkExports} {
    foreach {sdk_key sdk_value} $syncedPluginSdkExports {
        dict set nextExports $sdk_key $sdk_value
    }
}

# Convert dicts to JSON strings for comparison
set nextExportsJson [json::write::indented $nextExports]
set currentExportsJson [json::write::indented $currentExports]

if {$checkOnly} {
    if {$currentExportsJson ne $nextExportsJson} {
        puts stderr "plugin-sdk exports out of sync. Run `pnpm plugin-sdk:sync-exports`."
        exit 1
    }
    puts "plugin-sdk exports synced."
    exit 0
}

# Update package.json with new exports
dict set packageJson "exports" $nextExports
write_package_json $packageJsonPath $packageJson
