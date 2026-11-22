#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "4f52885c0b3966fa56b76611b3e3e121f1c77e77aea99307ec77594b5647deaa", "source_sha256": "d00d873eeab51d166892e3bc7f2dd08b6f535b2c11988d1bb7bc0c123b76e82d", "target_language": "tcl"}
# process.go — portiert nach tcl
# Quelle: go, workspace@local:skills/github-clones/openclaw/scripts/docs-i18n/process.go
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

# Tcl does not have native YAML support, so we'll need to implement basic parsing
# We'll also need to simulate some Go features like context, structs, etc.

# Global variables to simulate Go package-level variables
set workflowVersion "1.0"
array set tmCache {}

# Simulate context - Tcl doesn't have this, so we'll use a simple dict
proc createContext {} {
    return [dict create]
}

# Resolve docs path
proc resolveDocsPath {docsRoot filePath} {
    set absPath [file join $docsRoot $filePath]
    set relPath $filePath
    # In Tcl, error handling is done with catch
    if {![file exists $absPath]} {
        error "File not found: $absPath"
    }
    return [list $absPath $relPath]
}

# Split front matter from content
proc splitFrontMatter {content} {
    if {![string match "---*" $content]} {
        return [list "" $content]
    }
    
    set lines [split $content "\n"]
    if {[llength $lines] < 2} {
        return [list "" $content]
    }
    
    set endIndex -1
    for {set i 1} {$i < [llength $lines]} {incr i} {
        set line [lindex $lines $i]
        if {[string trim $line] eq "---"} {
            set endIndex $i
            break
        }
    }
    
    if {$endIndex == -1} {
        return [list "" $content]
    }
    
    set front [join [lrange $lines 1 [expr {$endIndex - 1}]] "\n"]
    set body [join [lrange $lines [expr {$endIndex + 1}] end] "\n"]
    if {[string index $body 0] eq "\n"} {
        set body [string range $body 1 end]
    }
    
    return [list $front $body]
}

# Simple YAML-like parser (very basic)
proc parseYAML {yamlStr} {
    array set result {}
    set lines [split $yamlStr "\n"]
    
    foreach line $lines {
        if {[regexp {^([^:]+):\s*(.*)$} $line -> key value]} {
            set result($key) $value
        }
    }
    
    return [array get result]
}

# Encode front matter
proc encodeFrontMatter {frontData relPath source} {
    global workflowVersion
    
    # Add i18n metadata
    dict set frontData "x-i18n" [dict create \
        "source_path" $relPath \
        "source_hash" [hashBytes $source] \
        "provider" [docsPiProvider] \
        "model" [docsPiModel] \
        "workflow" $workflowVersion \
        "generated_at" [clock format [clock seconds] -gmt true -format "%Y-%m-%dT%H:%M:%SZ"]]
    
    # Convert dict back to YAML-like format
    set yamlLines [list "---"]
    dict for {key value} $frontData {
        if {[dict size $value] > 0} {
            lappend yamlLines "$key:"
            dict for {subkey subvalue} $value {
                lappend yamlLines "  $subkey: $subvalue"
            }
        } else {
            lappend yamlLines "$key: $value"
        }
    }
    lappend yamlLines "---"
    lappend yamlLines ""
    
    return [join $yamlLines "\n"]
}

# Hash bytes (simple version)
proc hashBytes {data} {
    # This is a placeholder - in real implementation you'd use a proper hash function
    return [string length $data]
}

# Hash text
proc hashText {text} {
    return [string length $text]
}

# Cache key generation
proc cacheKey {namespace srcLang tgtLang segmentID textHash} {
    return "${namespace}:${srcLang}:${tgtLang}:${segmentID}:${textHash}"
}

# Cache namespace
proc cacheNamespace {} {
    return "default"
}

# Docs Pi Provider
proc docsPiProvider {} {
    return "openclaw"
}

# Docs Pi Model
proc docsPiModel {} {
    return "gpt-4"
}

# Verbose logs check
proc docsI18nVerboseLogs {} {
    set value [string trim [info exists ::env(OPENCLAW_DOCS_I18N_VERBOSE_LOGS)] ? $::env(OPENCLAW_DOCS_I18N_VERBOSE_LOGS) : ""]
    if {$value eq ""} {
        return 0
    }
    
    set lowerValue [string tolower $value]
    foreach trueValue {"1" "true" "yes" "on" "debug" "verbose"} {
        if {$lowerValue eq $trueValue} {
            return 1
        }
    }
    return 0
}

# Translate snippet
proc translateSnippet {ctx translator tm segmentID textValue srcLang tgtLang} {
    if {[string trim $textValue] eq ""} {
        return $textValue
    }
    
    set namespace [cacheNamespace]
    set textHash [hashText $textValue]
    set ck [cacheKey $namespace $srcLang $tgtLang $segmentID $textHash]
    
    # Check cache
    global tmCache
    if {[info exists tmCache($ck)]} {
        return $tmCache($ck)
    }
    
    # Call translator (simulated)
    set translated [$translator translate $ctx $textValue $srcLang $tgtLang]
    
    set shouldCache 1
    if {[validateFrontmatterScalarTranslation $textValue $translated]} {
        if {[docsI18nVerboseLogs]} {
            puts "docs-i18n: frontmatter fallback $segmentID reason=validation failed"
        }
        set translated $textValue
        set shouldCache 0
    }
    
    if {$shouldCache} {
        set tmCache($ck) $translated
    }
    
    return $translated
}

# Validate frontmatter scalar translation
proc validateFrontmatterScalarTranslation {source translated} {
    set trimmed [string trim $translated]
    if {$trimmed eq ""} {
        return 1
    }
    
    set lower [string tolower $trimmed]
    foreach tag {"<frontmatter>" "</frontmatter>" "<body>" "</body>"} {
        if {[string first $tag $lower] != -1} {
            return 1
        }
    }
    
    if {[string first "\[\[\[FM_" $trimmed] != -1} {
        return 1
    }
    
    if {[string first "\n---\n" $trimmed] != -1 || [string match "---\n*" $trimmed]} {
        return 1
    }
    
    if {![string match "*\n*" $source] && [regexp -all {\n} $trimmed] >= 3} {
        return 1
    }
    
    set sourceLen [string length [string trim $source]]
    set translatedLen [string length $trimmed]
    
    if {$sourceLen > 0} {
        set limit [expr {$sourceLen * 8 + 256}]
        if {$limit < 512} {
            set limit 512
        }
        if {$translatedLen > $limit} {
            return 1
        }
    }
    
    foreach key {"title:" "summary:" "read_when:"} {
        if {[string first "\n$key" $lower] != -1 || [string match "$key*" $lower]} {
            return 1
        }
    }
    
    return 0
}

# Translate front matter
proc translateFrontMatter {ctx translator tm data relPath srcLang tgtLang} {
    if {[dict size $data] == 0} {
        return
    }
    
    # Translate summary
    if {[dict exists $data "summary"]} {
        set summary [dict get $data "summary"]
        if {[docsI18nVerboseLogs]} {
            puts "docs-i18n: frontmatter start $relPath field=summary bytes=[string length $summary]"
        }
        set translated [translateSnippet $ctx $translator $tm "${relPath}:frontmatter:summary" $summary $srcLang $tgtLang]
        if {[docsI18nVerboseLogs]} {
            puts "docs-i18n: frontmatter done $relPath field=summary out_bytes=[string length $translated]"
        }
        dict set data "summary" $translated
    }
    
    # Translate title
    if {[dict exists $data "title"]} {
        set title [dict get $data "title"]
        if {[docsI18nVerboseLogs]} {
            puts "docs-i18n: frontmatter start $relPath field=title bytes=[string length $title]"
        }
        set translated [translateSnippet $ctx $translator $tm "${relPath}:frontmatter:title" $title $srcLang $tgtLang]
        if {[docsI18nVerboseLogs]} {
            puts "docs-i18n: frontmatter done $relPath field=title out_bytes=[string length $translated]"
        }
        dict set data "title" $translated
    }
    
    # Translate read_when
    if {[dict exists $data "read_when"]} {
        set readWhen [dict get $data "read_when"]
        set translated [list]
        set idx 0
        foreach item $readWhen {
            if {[catch {set textValue [string cat $item]}]} {
                lappend translated $item
                continue
            }
            if {[docsI18nVerboseLogs]} {
                puts "docs-i18n: frontmatter start $relPath field=read_when\[$idx\] bytes=[string length $textValue]"
            }
            set value [translateSnippet $ctx $translator $tm "${relPath}:frontmatter:read_when:$idx" $textValue $srcLang $tgtLang]
            if {[docsI18nVerboseLogs]} {
                puts "docs-i18n: frontmatter done $relPath field=read_when\[$idx\] out_bytes=[string length $value]"
            }
            lappend translated $value
            incr idx
        }
        dict set data "read_when" $translated
    }
}

# Process file main function
proc processFile {ctx translator tm docsRoot filePath srcLang tgtLang} {
    # Resolve path
    if {[catch {resolveDocsPath $docsRoot $filePath} result]} {
        return [list 0 "" $result]
    }
    foreach {absPath relPath} $result break
    
    # Read file
    if {[catch {set fd [open $absPath r]}] || [catch {set content [read $fd]}] || [catch {close $fd}]} {
        return [list 0 "" "Failed to read file: $absPath"]
    }
    
    # Split front matter
    foreach {frontMatter body} [splitFrontMatter $content] break
    
    # Parse front matter
    set frontData [dict create]
    if {$frontMatter ne ""} {
        set frontData [parseYAML $frontMatter]
    }
    
    # Translate front matter
    if {[catch {translateFrontMatter $ctx $translator $tm $frontData $relPath $srcLang $tgtLang} err]} {
        return [list 0 "" $err]
    }
    
    # Translate HTML blocks (placeholder)
    # In a real implementation, this would be more complex
    set body $body
    
    # Extract segments (placeholder)
    set segments [list]
    
    # Process segments
    set namespace [cacheNamespace]
    set processedSegments [list]
    foreach seg $segments {
        # This is simplified - in reality segments would have more structure
        set segmentID "seg_id"  ;# Placeholder
        set textHash [hashText $seg]
        set cacheKey [cacheKey $namespace $srcLang $tgtLang $segmentID $textHash]
        
        global tmCache
        if {[info exists tmCache($cacheKey)]} {
            lappend processedSegments $tmCache($cacheKey)
            continue
        }
        
        # Translate
        if {[catch {set translated [$translator translate $ctx $seg $srcLang $tgtLang]} err]} {
            return [list 0 "" "translate failed ($relPath): $err"]
        }
        
        set tmCache($cacheKey) $translated
        lappend processedSegments $translated
    }
    
    # Apply translations (placeholder)
    set translatedBody $body
    
    # Encode front matter
    if {[catch {set updatedFront [encodeFrontMatter $frontData $relPath $content]} err]} {
        return [list 0 "" $err]
    }
    
    # Write output
    set outputPath [file join $docsRoot $tgtLang $relPath]
    set outputDir [file dirname $outputPath]
    
    if {[catch {file mkdir $outputDir}]} {
        return [list 0 "" "Failed to create directory: $outputDir"]
    }
    
    set output "$updatedFront$translatedBody"
    if {[catch {set fd [open $outputPath w]}] || [catch {puts -nonewline $fd $output}] || [catch {close $fd}]} {
        return [list 0 "" "Failed to write file: $outputPath"]
    }
    
    return [list 0 $outputPath ""]
}
