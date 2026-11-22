#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "8a4cd133989254b517c5f9ec589dfd91bcfbd1fbaa0706afa632f921b4186d3d", "source_sha256": "0ea8eb8a8b99710853b26300ab5929582995da3d28a8c027c201b8c2daca6811", "target_language": "tcl"}
# relocalize_test.go — portiert nach tcl
# Quelle: go, workspace@local:skills/github-clones/openclaw/scripts/docs-i18n/relocalize_test.go
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

# Tcl 8.6 port of relocalize_test.go
# This script provides a testing framework for the postprocessLocalizedDocs function

# Helper functions to simulate Go functionality
proc stringsJoin {lines} {
    return [join $lines "\n"]
}

proc mustReadFile {path} {
    if {[catch {open $path r} fileId]} {
        error "read failed for $path: $fileId"
    }
    set content [read $fileId]
    close $fileId
    return $content
}

proc writeFile {path content} {
    # Create directory if it doesn't exist
    set dir [file dirname $path]
    if {![file exists $dir]} {
        file mkdir $dir
    }
    
    if {[catch {open $path w} fileId]} {
        error "write failed for $path: $fileId"
    }
    puts -nonewline $fileId $content
    close $fileId
}

proc containsLine {text want} {
    foreach line [split $text "\n"] {
        if {$line eq $want} {
            return true
        }
    }
    return false
}

# Mock testing framework
set test_results [list]
set current_test ""

proc runTest {name testProc} {
    global test_results current_test
    set current_test $name
    if {[catch {$testProc} errorMsg]} {
        lappend test_results "$name: FAIL - $errorMsg"
        puts "FAIL: $name - $errorMsg"
    } else {
        lappend test_results "$name: PASS"
        puts "PASS: $name"
    }
}

proc fail {message} {
    global current_test
    error "$current_test: $message"
}

proc fatal {message} {
    fail $message
}

# Main test functions (these would need to be implemented based on actual logic)
proc postprocessLocalizedDocs {docsRoot lang files} {
    # This is a placeholder - actual implementation would go here
    # For now we just return success
    return ""
}

# Test implementations
proc TestPostprocessLocalizedDocsFixesStaleLinksAfterLaterPagesExist {} {
    # Create temporary directory
    set docsRoot [exec mktemp -d]
    
    # Cleanup function
    proc cleanup {dir} {
        if {[file exists $dir]} {
            exec rm -rf $dir
        }
    }
    
    # Ensure cleanup on exit
    set cleanup_registered 0
    if {!$cleanup_registered} {
        trace add command cleanup delete [list cleanup $docsRoot]
        set cleanup_registered 1
    }
    
    writeFile [file join $docsRoot docs.json] "{\"redirects\":[]}"
    writeFile [file join $docsRoot gateway index.md] "# Gateway\n"
    writeFile [file join $docsRoot gateway troubleshooting.md] "# Troubleshooting\n"
    
    set zhCNIndex [file join $docsRoot zh-CN gateway index.md]
    writeFile $zhCNIndex [stringsJoin {
        "---"
        "title: 网关"
        "x-i18n:"
        "  source_hash: test"
        "---"
        ""
        "See \[Troubleshooting\](/gateway/troubleshooting)."
    }]
    
    set zhCNTrouble [file join $docsRoot zh-CN gateway troubleshooting.md]
    writeFile $zhCNTrouble [stringsJoin {
        "---"
        "title: 故障排除"
        "x-i18n:"
        "  source_hash: test"
        "---"
        ""
        "# 故障排除"
    }]
    
    set result [postprocessLocalizedDocs $docsRoot "zh-CN" [list $zhCNIndex $zhCNTrouble]]
    if {$result ne ""} {
        fatal "postprocessLocalizedDocs failed: $result"
    }
    
    set got [mustReadFile $zhCNIndex]
    if {![containsLine $got "---\ntitle: 网关\nx-i18n:\n  source_hash: test\n---\n"]} {
        fatal "front matter corrupted after rewrite:\n$got"
    }
    
    set want "See \[Troubleshooting\](/zh-CN/gateway/troubleshooting)."
    if {![containsLine $got $want]} {
        fatal "expected rewritten localized link \"$want\" in output:\n$got"
    }
    
    # Cleanup
    cleanup $docsRoot
}

proc TestPostprocessLocalizedDocsRewritesPublishedPageLinksForEachLocale {} {
    # Define test cases
    set tests [list \
        [list "zh-CN" "zh-CN" "网关" "/zh-CN"] \
        [list "ja-JP" "ja-JP" "ゲートウェイ" "/ja-JP"]]
    
    foreach test $tests {
        foreach {name lang title wantPrefix} $test {break}
        
        # Create temporary directory
        set docsRoot [exec mktemp -d]
        
        # Cleanup function
        proc cleanup {dir} {
            if {[file exists $dir]} {
                exec rm -rf $dir
            }
        }
        
        writeFile [file join $docsRoot docs.json] "{\"redirects\":[]}"
        writeFile [file join $docsRoot gateway index.md] "# Gateway\n"
        writeFile [file join $docsRoot gateway troubleshooting.md] "# Troubleshooting\n"
        writeFile [file join $docsRoot providers example-provider.md] "# Example provider\n"
        writeFile [file join $docsRoot $lang gateway troubleshooting.md] "# Localized troubleshooting\n"
        writeFile [file join $docsRoot $lang providers example-provider.md] "# Localized example provider\n"
        
        set pagePath [file join $docsRoot $lang gateway index.md]
        writeFile $pagePath [stringsJoin [list \
            "---" \
            "title: $title" \
            "x-i18n:" \
            "  source_hash: test" \
            "---" \
            "" \
            "See \[Troubleshooting\](/gateway/troubleshooting)." \
            "" \
            "See \[Example provider\](/providers/example-provider)." \
            "" \
            "<Card href=\"/gateway/troubleshooting\" title=\"Troubleshooting\" />" \
            "<Card href=\"$wantPrefix/providers/example-provider\" title=\"Example provider\" />"]]
        
        set result [postprocessLocalizedDocs $docsRoot $lang [list $pagePath]]
        if {$result ne ""} {
            fatal "postprocessLocalizedDocs failed: $result"
        }
        
        set got [mustReadFile $pagePath]
        set expectedLinks [list \
            "See \[Troubleshooting\]($wantPrefix/gateway/troubleshooting)." \
            "See \[Example provider\]($wantPrefix/providers/example-provider)." \
            "<Card href=\"$wantPrefix/gateway/troubleshooting\" title=\"Troubleshooting\" />" \
            "<Card href=\"$wantPrefix/providers/example-provider\" title=\"Example provider\" />"]
            
        foreach want $expectedLinks {
            if {![containsLine $got $want]} {
                fatal "expected rewritten link \"$want\" in output:\n$got"
            }
        }
        
        # Cleanup
        cleanup $docsRoot
    }
}

proc TestPostprocessLocalizedDocsOnlyTouchesScopedFiles {} {
    # Create temporary directory
    set docsRoot [exec mktemp -d]
    
    # Cleanup function
    proc cleanup {dir} {
        if {[file exists $dir]} {
            exec rm -rf $dir
        }
    }
    
    writeFile [file join $docsRoot docs.json] "{\"redirects\":[]}"
    writeFile [file join $docsRoot gateway troubleshooting.md] "# Troubleshooting\n"
    writeFile [file join $docsRoot zh-CN gateway troubleshooting.md] "# 故障排除\n"
    
    set scopedPath [file join $docsRoot zh-CN gateway index.md]
    set unscopedPath [file join $docsRoot zh-CN help index.md]
    
    writeFile $scopedPath [stringsJoin {
        "---"
        "title: 网关"
        "---"
        ""
        "See \[Troubleshooting\](/gateway/troubleshooting)."
    }]
    
    writeFile $unscopedPath [stringsJoin {
        "---"
        "title: 帮助"
        "---"
        ""
        "See \[Troubleshooting\](/gateway/troubleshooting)."
    }]
    
    set beforeUnscoped [mustReadFile $unscopedPath]
    set result [postprocessLocalizedDocs $docsRoot "zh-CN" [list $scopedPath]]
    if {$result ne ""} {
        fatal "postprocessLocalizedDocs failed: $result"
    }
    
    set gotScoped [mustReadFile $scopedPath]
    if {![containsLine $gotScoped "See \[Troubleshooting\](/zh-CN/gateway/troubleshooting)."]} {
        fatal "expected scoped file rewrite, got:\n$gotScoped"
    }
    
    set afterUnscoped [mustReadFile $unscopedPath]
    if {$afterUnscoped ne $beforeUnscoped} {
        fatal "expected unscoped file to remain unchanged\nbefore:\n$beforeUnscoped\nafter:\n$afterUnscoped"
    }
    
    # Cleanup
    cleanup $docsRoot
}

proc TestPostprocessLocalizedDocsContinuesAfterUnchangedFile {} {
    # Create temporary directory
    set docsRoot [exec mktemp -d]
    
    # Cleanup function
    proc cleanup {dir} {
        if {[file exists $dir]} {
            exec rm -rf $dir
        }
    }
    
    writeFile [file join $docsRoot docs.json] "{\"redirects\":[]}"
    writeFile [file join $docsRoot gateway troubleshooting.md] "# Troubleshooting\n"
    writeFile [file join $docsRoot zh-CN gateway troubleshooting.md] "# 故障排除\n"
    
    set unchangedPath [file join $docsRoot zh-CN gateway already-localized.md]
    set needsRewritePath [file join $docsRoot zh-CN gateway index.md]
    
    writeFile $unchangedPath [stringsJoin {
        "---"
        "title: 已本地化"
        "---"
        ""
        "See \[Troubleshooting\](/zh-CN/gateway/troubleshooting)."
    }]
    
    writeFile $needsRewritePath [stringsJoin {
        "---"
        "title: 网关"
        "---"
        ""
        "See \[Troubleshooting\](/gateway/troubleshooting)."
    }]
    
    set result [postprocessLocalizedDocs $docsRoot "zh-CN" [list $unchangedPath $needsRewritePath]]
    if {$result ne ""} {
        fatal "postprocessLocalizedDocs failed: $result"
    }
    
    set got [mustReadFile $needsRewritePath]
    if {![containsLine $got "See \[Troubleshooting\](/zh-CN/gateway/troubleshooting)."]} {
        fatal "expected later file rewrite after unchanged file, got:\n$got"
    }
    
    # Cleanup
    cleanup $docsRoot
}

# Run all tests
runTest "TestPostprocessLocalizedDocsFixesStaleLinksAfterLaterPagesExist" TestPostprocessLocalizedDocsFixesStaleLinksAfterLaterPagesExist
runTest "TestPostprocessLocalizedDocsRewritesPublishedPageLinksForEachLocale" TestPostprocessLocalizedDocsRewritesPublishedPageLinksForEachLocale
runTest "TestPostprocessLocalizedDocsOnlyTouchesScopedFiles" TestPostprocessLocalizedDocsOnlyTouchesScopedFiles
runTest "TestPostprocessLocalizedDocsContinuesAfterUnchangedFile" TestPostprocessLocalizedDocsContinuesAfterUnchangedFile

puts "\nTest Results:"
foreach result $test_results {
    puts $result
}
