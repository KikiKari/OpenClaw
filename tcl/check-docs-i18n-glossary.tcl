#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "31b208e04ac62696789498a6621848fd27095b99ce4c9911672aa8a68363ccf7", "source_sha256": "e290d06e27f18dbd9a54def6168fe32ba54f3cdb01ec2175510727f412ff6a70", "target_language": "tcl"}
# check-docs-i18n-glossary.mjs — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-docs-i18n-glossary.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

package require json
package require fileutil

# Konstanten definieren
set ROOT [pwd]
set GLOSSARY_PATH [file join $ROOT docs .i18n glossary.zh-CN.json]
set DOC_FILE_RE {^docs/(?!zh-CN/).+\.(md|mdx)$}
set LIST_ITEM_LINK_RE {^\s*(?:[-*]|\d+\.)\s+\[([^\]]+)\]\((/[^)]+)\)}
set MAX_TITLE_WORDS 8
set MAX_LABEL_WORDS 6
set MAX_TERM_LENGTH 80

# Globale Variablen für Kommandozeilenargumente
set BASE ""
set HEAD ""

proc parse_args {argv} {
    global BASE HEAD
    set i 0
    while {$i < [llength $argv]} {
        set arg [lindex $argv $i]
        if {$arg eq "--base"} {
            incr i
            set BASE [lindex $argv $i]
        } elseif {$arg eq "--head"} {
            incr i
            set HEAD [lindex $argv $i]
        }
        incr i
    }
}

proc run_git {args} {
    global ROOT
    set cmd [list git {*}$args]
    if {[catch {exec {*}$cmd} result]} {
        error "Git command failed: $result"
    }
    return [string trim $result]
}

proc resolve_base {explicitBase} {
    if {$explicitBase ne ""} {
        return $explicitBase
    }

    set envBase [getenv DOCS_I18N_GLOSSARY_BASE ""]
    if {$envBase ne ""} {
        return [string trim $envBase]
    }

    foreach candidate {origin/main fork/main main} {
        if {![catch {run_git merge-base $candidate HEAD} result]} {
            return $result
        }
    }

    return ""
}

proc list_changed_docs {base head} {
    set args [list diff --name-only --diff-filter=ACMR $base]
    if {$head ne ""} {
        lappend args $head
    }
    lappend args -- docs

    set output [run_git {*}$args]
    set files {}
    foreach line [split $output "\n"] {
        set trimmed [string trim $line]
        if {[regexp -nocase $::DOC_FILE_RE $trimmed]} {
            lappend files $trimmed
        }
    }
    return $files
}

proc load_glossary_sources {} {
    global GLOSSARY_PATH
    set data [read_file $GLOSSARY_PATH]
    set entries [json::json2dict $data]
    set sources {}
    foreach entry $entries {
        dict with entry {
            if {[info exists source] && [string trim $source] ne ""} {
                lappend sources [string trim $source]
            }
        }
    }
    return [lsort -unique $sources]
}

proc contains_latin {text} {
    return [regexp {[A-Za-z]} $text]
}

proc word_count {text} {
    set trimmed [string trim $text]
    if {$trimmed eq ""} {
        return 0
    }
    return [llength [split [regsub -all {\s+} $trimmed " "]]]
}

proc unquote_scalar {raw} {
    set value [string trim $raw]
    if {([string range $value 0 0] eq "\"" && [string range $value end end] eq "\"") ||
        ([string range $value 0 0] eq "'" && [string range $value end end] eq "'")} {
        set value [string range $value 1 end-1]
    }
    return [string trim $value]
}

proc is_glossary_candidate {term maxWords} {
    global MAX_TERM_LENGTH
    if {$term eq ""} {
        return 0
    }
    if {![contains_latin $term]} {
        return 0
    }
    if {[string first "`" $term] != -1} {
        return 0
    }
    if {[string length $term] > $MAX_TERM_LENGTH} {
        return 0
    }
    return [expr {[word_count $term] <= $maxWords}]
}

proc read_git_file {base relPath} {
    if {[catch {run_git show "$base:$relPath"} result]} {
        return ""
    }
    return $result
}

proc extract_terms {file text} {
    global MAX_TITLE_WORDS MAX_LABEL_WORDS LIST_ITEM_LINK_RE
    set terms [dict create]
    set lines [split $text "\n"]

    # Prüfen ob Frontmatter vorhanden ist
    if {[llength $lines] > 0 && [string trim [lindex $lines 0]] eq "---"} {
        for {set index 1} {$index < [llength $lines]} {incr index} {
            set line [lindex $lines $index]
            if {[string trim $line] eq "---"} {
                break
            }

            if {[regexp {^title:\s*(.+)\s*$} $line -> title_match]} {
                set title [unquote_scalar $title_match]
                if {[is_glossary_candidate $title $MAX_TITLE_WORDS]} {
                    dict set terms $title [dict create file $file line [expr {$index + 1}] kind "title" term $title]
                }
                break
            }
        }
    }

    # Durch alle Zeilen gehen und Link-Labels extrahieren
    for {set index 0} {$index < [llength $lines]} {incr index} {
        set line [lindex $lines $index]
        if {[regexp $LIST_ITEM_LINK_RE $line -> label]} {
            set label [string trim $label]
            if {[is_glossary_candidate $label $MAX_LABEL_WORDS]} {
                if {![dict exists $terms $label]} {
                    dict set terms $label [dict create file $file line [expr {$index + 1}] kind "link label" term $label]
                }
            }
        }
    }

    return $terms
}

proc read_file {filename} {
    set fh [open $filename r]
    set data [read $fh]
    close $fh
    return $data
}

proc getenv {var default} {
    if {[info exists ::env($var)]} {
        return $::env($var)
    } else {
        return $default
    }
}

proc main {} {
    global BASE HEAD
    parse_args $::argv
    set base [resolve_base $BASE]

    if {$base eq ""} {
        puts stderr "docs:check-i18n-glossary: no merge base found; skipping glossary coverage check."
        exit 0
    }

    set changedDocs [list_changed_docs $base $HEAD]
    if {[llength $changedDocs] == 0} {
        exit 0
    }

    set glossary [load_glossary_sources]
    set missing {}

    foreach relPath $changedDocs {
        set absPath [file join [pwd] $relPath]
        if {![file exists $absPath]} {
            continue
        }

        set currentText [read_file $absPath]
        set currentTerms [extract_terms $relPath $currentText]
        set baseText [read_git_file $base $relPath]
        set baseTerms [extract_terms $relPath $baseText]

        dict for {term match} $currentTerms {
            if {[dict exists $baseTerms $term]} {
                continue
            }
            if {[lsearch -exact $glossary $term] != -1} {
                continue
            }
            lappend missing $match
        }
    }

    if {[llength $missing] == 0} {
        exit 0
    }

    puts stderr "docs:check-i18n-glossary: missing zh-CN glossary entries for changed doc labels:"
    foreach match $missing {
        dict with match {
            puts stderr "- $file:$line $kind \"$term\""
        }
    }
    puts stderr ""
    puts stderr "Add exact source terms to docs/.i18n/glossary.zh-CN.json before rerunning docs-i18n."
    puts stderr "Checked changed English docs relative to $base."
    exit 1
}

main
