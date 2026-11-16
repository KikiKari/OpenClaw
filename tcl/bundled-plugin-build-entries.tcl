#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "e0f732ec11e6d764859affd087cfc7c715e13eaa6124f716fedd9f50ff832b91", "source_sha256": "ddf85df3b9350046010bc7449b7c05ad91c9c7d97ce98d75578f16ec7e33cef1", "target_language": "tcl"}
# bundled-plugin-build-entries.mjs — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/bundled-plugin-build-entries.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

# Load required packages
package require json
package require fileutil

# Define constants
set TOP_LEVEL_PUBLIC_SURFACE_EXTENSIONS [dict create .ts 1 .js 1 .mts 1 .cts 1 .mjs 1 .cjs 1]
set NON_PACKAGED_BUNDLED_PLUGIN_DIRS [dict create qa-channel 1 qa-lab 1]

# Import paths and cluster functions (simulated)
source bundled-plugin-paths.tcl
source optional-bundled-clusters.tcl

proc to_posix_path {value} {
    return [string map {\\ /} $value]
}

proc read_bundled_plugin_package_json {package_json_path} {
    if {![file exists $package_json_path]} {
        return {}
    }
    if {[catch {open $package_json_path r} fh]} {
        return {}
    }
    set content [read $fh]
    close $fh
    if {[catch {::json::json2dict $content} result]} {
        return {}
    }
    return $result
}

proc is_manifestless_bundled_runtime_support_package {params} {
    array set p $params
    set package_name ""
    if {[info exists p(packageJson,name)] && $p(packageJson,name) ne ""} {
        set package_name $p(packageJson,name)
    }
    if {$package_name ne "@openclaw/$p(dirName)"} {
        return 0
    }
    return [expr {[llength $p(topLevelPublicSurfaceEntries)] > 0}]
}

proc collect_plugin_source_entries {package_json} {
    array set pkg $package_json
    set package_entries {}
    if {[info exists pkg(openclaw,extensions)] && [llength $pkg(openclaw,extensions)] > 0} {
        foreach entry $pkg(openclaw,extensions) {
            if {$entry ne "" && [string trim $entry] ne ""} {
                lappend package_entries $entry
            }
        }
    }
    set setup_entry ""
    if {[info exists pkg(openclaw,setupEntry)] && $pkg(openclaw,setupEntry) ne "" && [string trim $pkg(openclaw,setupEntry)] ne ""} {
        set setup_entry $pkg(openclaw,setupEntry)
    }
    if {$setup_entry ne ""} {
        set package_entries [lsort -unique [concat $package_entries $setup_entry]]
    }
    if {[llength $package_entries] > 0} {
        return $package_entries
    }
    return [list ./index.ts]
}

proc should_stage_bundled_plugin_runtime_dependencies {package_json} {
    array set pkg $package_json
    if {[info exists pkg(openclaw,bundle,stageRuntimeDependencies)] && $pkg(openclaw,bundle,stageRuntimeDependencies)} {
        return 1
    }
    return 0
}

proc collect_top_level_public_surface_entries {plugin_dir} {
    global TOP_LEVEL_PUBLIC_SURFACE_EXTENSIONS
    if {![file exists $plugin_dir]} {
        return {}
    }
    set entries {}
    set files [glob -nocomplain -dir $plugin_dir *]
    foreach f $files {
        if {![file isfile $f]} continue
        set fname [file tail $f]
        set ext [file extension $fname]
        if {![dict exists $TOP_LEVEL_PUBLIC_SURFACE_EXTENSIONS $ext]} continue
        
        set norm_name [string tolower $fname]
        if {[string match "*.d.ts" $norm_name]} continue
        if {[regexp {^config-api\.(?:[cm]?[jt]s)$} $norm_name]} continue
        if {[string match "*.test.*" $norm_name]} continue
        if {[string match "*.spec.*" $norm_name]} continue
        if {[string match "*.fixture.*" $norm_name]} continue
        if {[string match "*.snap*" $norm_name]} continue
        
        lappend entries ./$fname
    }
    return [lsort $entries]
}

proc collect_bundled_plugin_build_entries {{params {}}} {
    global BUNDLED_PLUGIN_ROOT_DIR
    array set p $params
    
    set cwd [expr {[info exists p(cwd)] ? $p(cwd) : [pwd]}]
    set env_vars [expr {[info exists p(env)] ? $p(env) : [array get ::env]}]
    
    set extensions_root [file join $cwd $BUNDLED_PLUGIN_ROOT_DIR]
    set entries {}
    
    set dirs [glob -nocomplain -dir $extensions_root *]
    foreach d $dirs {
        if {![file isdirectory $d]} continue
        
        set dir_name [file tail $d]
        set plugin_dir [file join $extensions_root $dir_name]
        set manifest_path [file join $plugin_dir openclaw.plugin.json]
        set has_manifest [file exists $manifest_path]
        set package_json_path [file join $plugin_dir package.json]
        set package_json [read_bundled_plugin_package_json $package_json_path]
        set top_level_entries [collect_top_level_public_surface_entries $plugin_dir]
        
        set manifestless_check_params [list \
            dirName $dir_name \
            packageJson $package_json \
            topLevelPublicSurfaceEntries $top_level_entries]
            
        if {!$has_manifest && ![is_manifestless_bundled_runtime_support_package $manifestless_check_params]} {
            continue
        }
        
        if {![should_build_bundled_cluster $dir_name $env_vars [list packageJson $package_json]]} {
            continue
        }
        
        set source_entries {}
        if {$has_manifest} {
            set source_entries [collect_plugin_source_entries $package_json]
        }
        set all_entries [lsort -unique [concat $source_entries $top_level_entries]]
        
        lappend entries [dict create \
            id $dir_name \
            hasManifest $has_manifest \
            hasPackageJson [expr {$package_json ne ""}] \
            packageJson $package_json \
            sourceEntries $all_entries]
    }
    
    return $entries
}

proc list_bundled_plugin_build_entries {{params {}}} {
    global BUNDLED_PLUGIN_ROOT_DIR
    set entries [collect_bundled_plugin_build_entries $params]
    set result {}
    
    foreach entry $entries {
        set id [dict get $entry id]
        set source_entries [dict get $entry sourceEntries]
        
        foreach src_entry $source_entries {
            set normalized_entry [regsub {^\./} $src_entry ""]
            set base_name [regsub {\.[^.]+$} $normalized_entry ""]
            set entry_key [bundled_plugin_file $id $base_name]
            set full_path [to_posix_path [file join $BUNDLED_PLUGIN_ROOT_DIR $id $normalized_entry]]
            dict set result $entry_key $full_path
        }
    }
    
    return $result
}

proc list_bundled_plugin_pack_artifacts {{params {}}} {
    global NON_PACKAGED_BUNDLED_PLUGIN_DIRS
    set all_entries [collect_bundled_plugin_build_entries $params]
    set filtered_entries {}
    
    foreach entry $all_entries {
        set id [dict get $entry id]
        if {![dict exists $NON_PACKAGED_BUNDLED_PLUGIN_DIRS $id]} {
            lappend filtered_entries $entry
        }
    }
    
    set artifacts {}
    foreach entry $filtered_entries {
        set id [dict get $entry id]
        set has_manifest [dict get $entry hasManifest]
        set has_package_json [dict get $entry hasPackageJson]
        set source_entries [dict get $entry sourceEntries]
        
        if {$has_manifest} {
            lappend artifacts [bundled_dist_plugin_file $id openclaw.plugin.json]
        }
        if {$has_package_json} {
            lappend artifacts [bundled_dist_plugin_file $id package.json]
        }
        foreach src_entry $source_entries {
            set normalized_entry [regsub {^\./} $src_entry ""]
            set base_name [regsub {\.[^.]+$} $normalized_entry ""]
            lappend artifacts [bundled_dist_plugin_file $id ${base_name}.js]
        }
    }
    
    return [lsort -unique $artifacts]
}

proc list_bundled_plugin_runtime_dependencies {{params {}}} {
    set entries [collect_bundled_plugin_build_entries $params]
    set runtime_deps {}
    
    foreach entry $entries {
        set package_json [dict get $entry packageJson]
        if {![should_stage_bundled_plugin_runtime_dependencies $package_json]} {
            continue
        }
        
        array set pkg $package_json
        if {[info exists pkg(dependencies)]} {
            foreach dep [dict keys $pkg(dependencies)] {
                lappend runtime_deps $dep
            }
        }
        if {[info exists pkg(optionalDependencies)]} {
            foreach dep [dict keys $pkg(optionalDependencies)] {
                lappend runtime_deps $dep
            }
        }
    }
    
    return [lsort -unique $runtime_deps]
}
