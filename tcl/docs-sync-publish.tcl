#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "66401b87721942b0971cbfe36ff912230529e40099866f93a209a258f7e938af", "source_sha256": "51ab4d0a9d189c9eda9b410805bf753ea3df4406b70d58c8757e52b4551325b6", "target_language": "tcl"}
# docs-sync-publish.mjs — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/docs-sync-publish.mjs
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

package require json
package require fileutil

# Emulate path operations using file normalize and file dirname
proc path_dirname {path} {
    return [file dirname $path]
}

proc path_resolve {args} {
    set combined [join $args "/"]
    return [file normalize $combined]
}

proc path_join {args} {
    return [join $args "/"]
}

set HERE [path_dirname [info script]]
set ROOT [path_resolve $HERE ".."]
set SOURCE_DOCS_DIR [path_join $ROOT "docs"]
set SOURCE_CONFIG_PATH [path_join $SOURCE_DOCS_DIR "docs.json"]

# GENERATED_LOCALES array
array set GENERATED_LOCALES {
    0 {language zh-Hans dir zh-CN navFile zh-Hans-navigation.json tmFile zh-CN.tm.jsonl navMode overlay}
    1 {language ja dir ja-JP navFile ja-navigation.json tmFile ja-JP.tm.jsonl navMode clone-en}
    2 {language es dir es navFile es-navigation.json tmFile es.tm.jsonl navMode clone-en}
    3 {language pt-BR dir pt-BR navFile pt-BR-navigation.json tmFile pt-BR.tm.jsonl navMode clone-en}
    4 {language ko dir ko navFile ko-navigation.json tmFile ko.tm.jsonl navMode clone-en}
    5 {language de dir de navFile de-navigation.json tmFile de.tm.jsonl navMode clone-en}
    6 {language fr dir fr navFile fr-navigation.json tmFile fr.tm.jsonl navMode clone-en}
    7 {language ar dir ar navFile ar-navigation.json tmFile ar.tm.jsonl navMode clone-en}
    8 {language it dir it navFile it-navigation.json tmFile it.tm.jsonl navMode clone-en}
    9 {language tr dir tr navFile tr-navigation.json tmFile tr.tm.jsonl navMode clone-en}
    10 {language uk dir uk navFile uk-navigation.json tmFile uk.tm.jsonl navMode clone-en}
    11 {language id dir id navFile id-navigation.json tmFile id.tm.jsonl navMode clone-en}
    12 {language pl dir pl navFile pl-navigation.json tmFile pl.tm.jsonl navMode clone-en}
}

proc parseArgs {argv} {
    global argc argv0
    array set args {
        target ""
        sourceRepo ""
        sourceSha ""
    }

    for {set index 0} {$index < [llength $argv]} {incr index} {
        set part [lindex $argv $index]
        switch -- $part {
            --target {
                incr index
                set args(target) [lindex $argv $index]
            }
            --source-repo {
                incr index
                set args(sourceRepo) [lindex $argv $index]
            }
            --source-sha {
                incr index
                set args(sourceSha) [lindex $argv $index]
            }
            default {
                error "unknown arg: $part"
            }
        }
    }

    if {$args(target) eq ""} {
        error "missing --target"
    }

    return [array get args]
}

proc run {command args} {
    global ROOT
    set cmd [concat exec $command {*}$args]
    eval $cmd
}

proc ensureDir {dirPath} {
    if {![file exists $dirPath]} {
        file mkdir $dirPath
    }
}

proc readJson {filePath} {
    set fp [open $filePath r]
    set content [read $fp]
    close $fp
    return [::json::json2dict $content]
}

proc writeJson {filePath value} {
    ensureDir [file dirname $filePath]
    set fp [open $filePath w]
    puts $fp [::json::dict2json $value]
    close $fp
}

proc prefixLocalePage {entry localeDir} {
    if {[string equal [::json::typeof $entry] "string"]} {
        return "${localeDir}/${entry}"
    }
    if {[string equal [::json::typeof $entry] "array"]} {
        set result {}
        foreach item $entry {
            lappend result [prefixLocalePage $item $localeDir]
        }
        return $result
    }
    if {![dict exists $entry]} {
        return $entry
    }

    set clone [dict create]
    dict for {key val} $entry {
        if {[string equal $key "page"] && [string equal [::json::typeof $val] "string"]} {
            dict set clone page "${localeDir}/${val}"
        } elseif {[string equal $key "pages"] && [string equal [::json::typeof $val] "array"]} {
            set pages_result {}
            foreach item $val {
                lappend pages_result [prefixLocalePage $item $localeDir]
            }
            dict set clone pages $pages_result
        } else {
            dict set clone $key $val
        }
    }
    return $clone
}

proc cloneEnglishLanguageNav {englishNav locale} {
    if {![dict exists $englishNav]} {
        error "docs/docs.json is missing navigation.languages.en"
    }

    set result [dict create]
    dict for {key val} $englishNav {
        dict set result $key $val
    }
    dict set result language [dict get $locale language]

    if {[dict exists $englishNav tabs] && [string equal [::json::typeof [dict get $englishNav tabs]] "array"]} {
        set tabs_result {}
        foreach tab [dict get $englishNav tabs] {
            set tab_clone [dict create]
            dict for {tab_key tab_val} $tab {
                dict set tab_clone $tab_key $tab_val
            }

            if {[dict exists $tab pages] && [string equal [::json::typeof [dict get $tab pages]] "array"]} {
                set pages_result {}
                foreach entry [dict get $tab pages] {
                    lappend pages_result [prefixLocalePage $entry [dict get $locale dir]]
                }
                dict set tab_clone pages $pages_result
            }

            if {[dict exists $tab groups] && [string equal [::json::typeof [dict get $tab groups]] "array"]} {
                set groups_result {}
                foreach group [dict get $tab groups] {
                    set group_clone [dict create]
                    dict for {group_key group_val} $group {
                        dict set group_clone $group_key $group_val
                    }

                    if {[dict exists $group pages] && [string equal [::json::typeof [dict get $group pages]] "array"]} {
                        set group_pages_result {}
                        foreach entry [dict get $group pages] {
                            lappend group_pages_result [prefixLocalePage $entry [dict get $locale dir]]
                        }
                        dict set group_clone pages $group_pages_result
                    }
                    lappend groups_result $group_clone
                }
                dict set tab_clone groups $groups_result
            }
            lappend tabs_result $tab_clone
        }
        dict set result tabs $tabs_result
    }
    return $result
}

proc composeLocaleNav {locale englishNav} {
    global SOURCE_DOCS_DIR
    set navMode [dict get $locale navMode]
    if {[string equal $navMode "clone-en"]} {
        return [cloneEnglishLanguageNav $englishNav $locale]
    }
    set navFile [dict get $locale navFile]
    return [readJson [path_join $SOURCE_DOCS_DIR ".i18n" $navFile]]
}

proc composeDocsConfig {} {
    global SOURCE_CONFIG_PATH GENERATED_LOCALES
    set sourceConfig [readJson $SOURCE_CONFIG_PATH]
    
    if {![dict exists $sourceConfig navigation languages]} {
        error "docs/docs.json is missing navigation.languages"
    }
    
    set languages [dict get $sourceConfig navigation languages]
    if {![string equal [::json::typeof $languages] "array"]} {
        error "docs/docs.json is missing navigation.languages"
    }

    set englishNav {}
    foreach entry $languages {
        if {[dict exists $entry language] && [string equal [dict get $entry language] "en"]} {
            set englishNav $entry
            break
        }
    }

    # Create generated language set
    set generatedLanguageSet {}
    for {set i 0} {$i <= 12} {incr i} {
        lappend generatedLanguageSet [dict get $GENERATED_LOCALES($i) language]
    }

    # Filter out generated languages
    set withoutGenerated {}
    foreach entry $languages {
        if {[dict exists $entry language] && [lsearch $generatedLanguageSet [dict get $entry language]] == -1} {
            lappend withoutGenerated $entry
        }
    }

    # Find English index
    set enIndex -1
    for {set i 0} {$i < [llength $withoutGenerated]} {incr i} {
        set entry [lindex $withoutGenerated $i]
        if {[dict exists $entry language] && [string equal [dict get $entry language] "en"]} {
            set enIndex $i
            break
        }
    }

    # Generate locales
    set generated {}
    for {set i 0} {$i <= 12} {incr i} {
        lappend generated [composeLocaleNav $GENERATED_LOCALES($i) $englishNav]
    }

    # Insert generated after English or at end
    if {$enIndex == -1} {
        set withoutGenerated [concat $withoutGenerated $generated]
    } else {
        set before [lrange $withoutGenerated 0 $enIndex]
        set after [lrange $withoutGenerated [expr {$enIndex + 1}] end]
        set withoutGenerated [concat $before $generated $after]
    }

    # Update config
    set result [dict create]
    dict for {key val} $sourceConfig {
        dict set result $key $val
    }
    dict set result navigation languages $withoutGenerated
    
    return $result
}

proc syncDocsTree {targetRoot} {
    global SOURCE_DOCS_DIR GENERATED_LOCALES ROOT
    set targetDocsDir [path_join $targetRoot "docs"]
    ensureDir $targetDocsDir

    # Build rsync filters
    set localeFilters {}
    for {set i 0} {$i <= 12} {incr i} {
        set entry $GENERATED_LOCALES($i)
        lappend localeFilters "--filter" "P [dict get $entry dir]/"
        lappend localeFilters "--filter" "P .i18n/[dict get $entry tmFile]"
        lappend localeFilters "--exclude" "[dict get $entry dir]/"
        lappend localeFilters "--exclude" ".i18n/[dict get $entry tmFile]"
    }

    set rsync_args [concat "-a" "--delete" "--filter" "P .i18n/README.md" "--exclude" ".i18n/README.md" \
                   {*}$localeFilters "${SOURCE_DOCS_DIR}/" "${targetDocsDir}/"]
    
    cd $ROOT
    exec rsync {*}$rsync_args

    # Copy TM files if needed
    for {set i 0} {$i <= 12} {incr i} {
        set locale $GENERATED_LOCALES($i)
        set sourceTmPath [path_join $SOURCE_DOCS_DIR ".i18n" [dict get $locale tmFile]]
        set targetTmPath [path_join $targetDocsDir ".i18n" [dict get $locale tmFile]]
        
        if {![file exists $targetTmPath] && [file exists $sourceTmPath]} {
            ensureDir [file dirname $targetTmPath]
            file copy $sourceTmPath $targetTmPath
        }
    }

    writeJson [path_join $targetDocsDir "docs.json"] [composeDocsConfig]
}

proc writeSyncMetadata {targetRoot args_array} {
    upvar $args_array args
    set metadata [dict create \
        repository [dict get $args sourceRepo] \
        sha [dict get $args sourceSha] \
        syncedAt [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%SZ" -gmt true]]
    
    writeJson [path_join $targetRoot ".openclaw-sync" "source.json"] $metadata
}

proc main {} {
    global argv
    array set args [parseArgs $argv]
    set targetRoot [path_resolve [dict get $args target]]

    if {![file exists $targetRoot]} {
        error "target does not exist: $targetRoot"
    }

    syncDocsTree $targetRoot
    writeSyncMetadata $targetRoot args
}

main
