#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "1ddbc681438591587c7b4ad7d22cd59a68bb9ed9c881320690eebe5e0f426be1", "source_sha256": "9846e805dd3219c9d0bd40ccd4a368fb397647c0f7db6d88a1eab2f1d73061f3", "target_language": "tcl"}
# docs-link-audit.mjs — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/docs-link-audit.mjs
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

package require Tcl 8.6
package require fileutil
package require json
package require uri

set ROOT [pwd]
set DOCS_DIR [file join $ROOT docs]
set DOCS_JSON_PATH [file join $DOCS_DIR docs.json]
set MINTLIFY_BROKEN_LINKS_ARGS [list dlx mint broken-links --check-anchors]
set NODE_25_UNSUPPORTED_BY_MINTLIFY 25

if {![file exists $DOCS_DIR] || ![file isdirectory $DOCS_DIR]} {
    puts stderr "docs:check-links: missing docs directory; run from repo root."
    exit 1
}

if {![file exists $DOCS_JSON_PATH]} {
    puts stderr "docs:check-links: missing docs/docs.json."
    exit 1
}

proc walk {dir} {
    set out {}
    set entries [glob -nocomplain -directory $dir -types {hidden hidden,file directory} *]
    foreach entry $entries {
        set name [file tail $entry]
        if {[string index $name 0] eq "."} {
            continue
        }
        if {[file isdirectory $entry]} {
            lappend out {*}[walk $entry]
        } elseif {[file isfile $entry]} {
            lappend out $entry
        }
    }
    return $out
}

proc normalizeSlashes {p} {
    return [string map {\\ /} $p]
}

proc normalizeRoute {p} {
    set withoutFragment [lindex [split $p #] 0]
    set withoutQuery [lindex [split $withoutFragment ?] 0]
    regsub {^/+|/+$} $withoutQuery {} stripped
    return [expr {$stripped eq "" ? "/" : "/$stripped"}]
}

proc stripInlineCode {text} {
    regsub -all {`[^`]+`} $text "" result
    return $result
}

set docsConfig [::json::json2dict [readFile $DOCS_JSON_PATH]]
array set redirects {}
foreach item [dict get $docsConfig redirects {}] {
    set source [normalizeRoute [dict get $item source ""]]
    set destination [normalizeRoute [dict get $item destination ""]]
    dict set redirects $source $destination
}

set allFiles [walk $DOCS_DIR]
set relAllFiles {}
foreach abs $allFiles {
    set rel [normalizeSlashes [fileutil::relative $DOCS_DIR $abs]]
    lappend relAllFiles $rel
}
set relAllFiles [lsort -unique $relAllFiles]

proc isLocalizedDocPath {p} {
    return [regexp {^/?[a-z]{2}(?:-[A-Za-z]{2,8})+/} $p]
}

proc isGeneratedTranslatedDoc {relPath} {
    return [isLocalizedDocPath $relPath]
}

set markdownFiles {}
foreach abs $allFiles {
    if {![regexp -nocase {\.(md|mdx)$} $abs]} {
        continue
    }
    set rel [normalizeSlashes [fileutil::relative $DOCS_DIR $abs]]
    if {![isGeneratedTranslatedDoc $rel]} {
        lappend markdownFiles $abs
    }
}
set routes {}

foreach abs $markdownFiles {
    set rel [normalizeSlashes [fileutil::relative $DOCS_DIR $abs]]
    set text [readFile $abs]
    set slug [regsub -nocase {\.(md|mdx)$} $rel ""]
    set route [normalizeRoute $slug]
    lappend routes $route
    if {[string range $slug end-5 end] eq "/index"} {
        lappend routes [normalizeRoute [string range $slug 0 end-6]]
    }

    if {![string match "---*" $text]} {
        continue
    }

    set end [string first "\n---" $text 3]
    if {$end == -1} {
        continue
    }
    set frontMatter [string range $text 3 $end-1]
    if {[regexp -lineanchor {^permalink:\s*(.+)\s*$} $frontMatter -> match]} {
        set permalink [string trim $match "'\""]
        lappend routes [normalizeRoute $permalink]
    }
}

proc resolveRoute {route {redirectsVar ""} {routesVar ""}} {
    upvar 1 redirects redirectMap routes publishedRoutes
    
    if {$redirectsVar ne ""} {
        array set redirectMap $redirectsVar
    }
    if {$routesVar ne ""} {
        set publishedRoutes $routesVar
    }
    
    set current [normalizeRoute $route]
    if {$current eq "/"} {
        return [list ok true terminal /]
    }

    array set seen [list $current 1]
    while {[dict exists $redirectMap $current]} {
        set current [normalizeRoute [dict get $redirectMap $current]]
        if {[info exists seen($current)]} {
            return [list ok false terminal $current loop true]
        }
        set seen($current) 1
    }
    return [list ok [expr {[lsearch -exact $publishedRoutes $current] != -1}] terminal $current]
}

proc collectNavPageEntries {node} {
    set entries {}
    if {[llength $node] > 0 && [llength $node] == 1 && [llength [lindex $node 0]] > 1} {
        foreach item $node {
            lappend entries {*}[collectNavPageEntries $item]
        }
        return $entries
    }

    if {![dict size $node]} {
        return $entries
    }

    if {[dict exists $node pages]} {
        set pages [dict get $node pages]
        foreach page $pages {
            if {[llength $page] == 1} {
                lappend entries $page
            } else {
                lappend entries {*}[collectNavPageEntries $page]
            }
        }
    }

    dict for {key value} $node {
        if {$key ne "pages"} {
            lappend entries {*}[collectNavPageEntries $value]
        }
    }

    return $entries
}

set markdownLinkRegex {(?:!\[.*?\]$$[^)]+$$)}

proc sanitizeDocsConfigForEnglishOnly {value} {
    if {[llength $value] > 0 && [llength $value] == 1 && [llength [lindex $value 0]] > 1} {
        set result {}
        foreach item $value {
            set next [sanitizeDocsConfigForEnglishOnly $item]
            if {$next ne "undefined"} {
                lappend result $next
            }
        }
        return $result
    }

    if {![dict size $value]} {
        if {[dict size $value] == 1 && [dict exists $value language] && [dict get $value language] ne "en"} {
            return "undefined"
        }
        return $value
    }

    array set record {}
    dict for {key child} $value {
        set next [sanitizeDocsConfigForEnglishOnly $child]
        if {$next ne "undefined"} {
            if {[llength $next] > 0 && [llength $next] == 1 && [llength [lindex $next 0]] > 1 && [llength $next] == 0} {
                continue
            }
            if {[dict size $next] > 0 && [dict size $next] == 0} {
                continue
            }
            dict set record $key $next
        }
    }

    if {[dict exists $value pages] && ![dict exists $record pages]} {
        return "undefined"
    }
    if {[dict exists $value groups] && ![dict exists $record groups]} {
        return "undefined"
    }
    if {[dict exists $value tabs] && ![dict exists $record tabs]} {
        return "undefined"
    }
    if {[dict exists $value source] && [dict exists $record source] && [dict get $value source] ne "" && ![dict exists $record source]} {
        return "undefined"
    }
    if {[dict exists $value destination] && [dict exists $record destination] && [dict get $value destination] ne "" && ![dict exists $record destination]} {
        return "undefined"
    }

    return [expr {[dict size $record] > 0 ? [array get record] : "undefined"}]
}

proc prepareAnchorAuditDocsDir {{sourceDir ""}} {
    global DOCS_DIR
    if {$sourceDir eq ""} {
        set sourceDir $DOCS_DIR
    }
    
    set tempDir [exec mktemp -d openclaw-docs-anchor-audit-XXXXXX]
    exec cp -r $sourceDir/* $tempDir/

    set entries [glob -nocomplain -directory $tempDir *]
    foreach entry $entries {
        if {![file isdirectory $entry]} {
            continue
        }
        set name [file tail $entry]
        if {![isGeneratedTranslatedDoc "$name/"]} {
            continue
        }
        file delete -force $entry
    }

    set docsJsonPath [file join $tempDir docs.json]
    set docsConfig [::json::json2dict [readFile $docsJsonPath]]
    set sanitized [sanitizeDocsConfigForEnglishOnly $docsConfig]
    writeFile $docsJsonPath "[::json::dict2json $sanitized]\n"

    return $tempDir
}

proc parseNodeMajor {version} {
    set parts [split $version .]
    set major [lindex $parts 0]
    if {[string is integer $major]} {
        return $major
    }
    return 0
}

proc resolveMintlifyAnchorAuditInvocation {params} {
    upvar 1 params paramsDict
    set nodeVersion [dict get $paramsDict nodeVersion]
    if {[parseNodeMajor $nodeVersion] < $NODE_25_UNSUPPORTED_BY_MINTLIFY} {
        return [list command pnpm args $MINTLIFY_BROKEN_LINKS_ARGS]
    }

    set node22Probe "exit([expr {[lindex [split [exec node -v] .] 0] eq "v22"} ? 0 : 1)])"
    set candidates [list \
        [list command fnm probeArgs [list exec --using=22 node -e $node22Probe] args [list exec --using=22 pnpm {*}$MINTLIFY_BROKEN_LINKS_ARGS]] \
        [list command mise probeArgs [list exec node@22 -- node -e $node22Probe] args [list exec node@22 -- pnpm {*}$MINTLIFY_BROKEN_LINKS_ARGS]] \
    ]

    foreach candidate $candidates {
        set cmd [dict get $candidate command]
        set probeArgs [dict get $candidate probeArgs]
        if {[catch {exec $cmd {*}$probeArgs}]} {
            continue
        }
        return [list command $cmd args [dict get $candidate args]]
    }

    return [list command pnpm args $MINTLIFY_BROKEN_LINKS_ARGS]
}

proc auditDocsLinks {} {
    global DOCS_DIR markdownFiles relAllFiles routes redirects
    
    set broken {}
    set checked 0

    foreach abs $markdownFiles {
        set rel [normalizeSlashes [fileutil::relative $DOCS_DIR $abs]]
        set baseDir [normalizeSlashes [file dirname $rel]]
        set rawText [readFile $abs]
        set lines [split $rawText \n]

        set inCodeFence false

        for {set lineNum 0} {$lineNum < [llength $lines]} {incr lineNum} {
            set line [lindex $lines $lineNum]

            if {[string match "*\`\`\`*" $line]} {
                set inCodeFence [expr {!$inCodeFence}]
                continue
            }
            if {$inCodeFence} {
                continue
            }

            set line [stripInlineCode $line]

            set matches [regexp -inline -all $markdownLinkRegex $line]
            foreach match $matches {
                if {[regexp {\(([^)]+)\)} $match -> rawMatch]} {
                    set raw [string trim $rawMatch]
                    if {$raw eq ""} {
                        continue
                    }
                    if {[regexp -nocase {^(https?:|mailto:|tel:|data:|#)} $raw]} {
                        continue
                    }

                    set pathPart [lindex [split $raw #] 0]
                    set clean [lindex [split $pathPart ?] 0]
                    if {$clean eq ""} {
                        continue
                    }
                    incr checked

                    if {[string index $clean 0] eq "/"} {
                        set route [normalizeRoute $clean]
                        set resolvedRoute [resolveRoute $route]
                        if {![dict get $resolvedRoute ok]} {
                            set staticRel [string range $route 1 end]
                            if {[lsearch -exact $relAllFiles $staticRel] == -1} {
                                lappend broken [list file $rel line [expr {$lineNum + 1}] link $raw reason "route/file not found (terminal: [dict get $resolvedRoute terminal])"]
                                continue
                            }
                        }
                        continue
                    }

                    if {![string match ".*" $clean] && ![string match "*/*" $clean]} {
                        continue
                    }

                    set normalizedRel [normalizeSlashes [file normalize [file join $baseDir $clean]]]

                    if {[regexp {\.[a-zA-Z0-9]+$} $normalizedRel]} {
                        if {[lsearch -exact $relAllFiles $normalizedRel] == -1} {
                            lappend broken [list file $rel line [expr {$lineNum + 1}] link $raw reason "relative file not found"]
                        }
                        continue
                    }

                    set candidates [list \
                        $normalizedRel \
                        "$normalizedRel.md" \
                        "$normalizedRel.mdx" \
                        "$normalizedRel/index.md" \
                        "$normalizedRel/index.mdx" \
                    ]

                    set found false
                    foreach candidate $candidates {
                        if {[lsearch -exact $relAllFiles $candidate] != -1} {
                            set found true
                            break
                        }
                    }
                    if {!$found} {
                        lappend broken [list file $rel line [expr {$lineNum + 1}] link $raw reason "relative doc target not found"]
                    }
                }
            }
        }
    }

    foreach page [collectNavPageEntries [dict get $docsConfig navigation {}]] {
        if {[isGeneratedTranslatedDoc $page]} {
            continue
        }
        incr checked
        set route [normalizeRoute $page]
        set resolvedRoute [resolveRoute $route]
        if {[dict get $resolvedRoute ok]} {
            continue
        }

        lappend broken [list file docs.json line 0 link $page reason "navigation page not published (terminal: [dict get $resolvedRoute terminal])"]
    }

    return [list checked $checked broken $broken]
}

proc runDocsLinkAuditCli {{options ""}} {
    global DOCS_DIR MINTLIFY_BROKEN_LINKS_ARGS
    
    set args [dict get $options args {}]
    if {$args eq ""} {
        set args [lrange $::argv 0 end]
    }
    
    if {[lsearch -exact $args --anchors] != -1} {
        set spawnSyncImpl [dict get $options spawnSyncImpl exec]
        set prepareAnchorAuditDocsDirImpl [dict get $options prepareAnchorAuditDocsDirImpl prepareAnchorAuditDocsDir]
        set cleanupAnchorAuditDocsDirImpl [dict get $options cleanupAnchorAuditDocsDirImpl [list apply {{dir} {file delete -force $dir}}]]
        
        set anchorDocsDir [$prepareAnchorAuditDocsDirImpl $DOCS_DIR]

        set status 1
        if {[catch {
            set invocation [resolveMintlifyAnchorAuditInvocation [list nodeVersion [dict get $options nodeVersion ""] spawnSyncImpl $spawnSyncImpl]]
            set command [dict get $invocation command]
            set args [dict get $invocation args]
            set result [exec $command {*}$args]
            set status 0
        } error]} {
            puts stderr $error
        }
        
        $cleanupAnchorAuditDocsDirImpl $anchorDocsDir
        return $status
    }

    set result [auditDocsLinks]
    set checked [dict get $result checked]
    set broken [dict get $result broken]
    
    puts "checked_internal_links=$checked"
    puts "broken_links=[llength $broken]"

    foreach item $broken {
        puts "[dict get $item file]:[dict get $item line] :: [dict get $item link] :: [dict get $item reason]"
    }

    return [expr {[llength $broken] > 0 ? 1 : 0}]
}

proc readFile {filename} {
    set fh [open $filename r]
    set content [read $fh]
    close $fh
    return $content
}

proc writeFile {filename content} {
    set fh [open $filename w]
    puts -nonewline $fh $content
    close $fh
}

set status [runDocsLinkAuditCli]
exit $status
