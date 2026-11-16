#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "a6baae2dbe6af1f6dab5aefbbf1ea0a00093bf6092f76bdc0ca53c8400a7c13a", "source_sha256": "13f974bf78b140bc88bd9f3afe27c500660ef59498ed533c38c18bca0c6f6331", "target_language": "tcl"}
# changelog-to-html.sh — portiert nach tcl
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/changelog-to-html.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

proc extract_version_section {version file} {
    set found 0
    set result ""
    
    if {[catch {open $file r} fh]} {
        error "Could not open file $file: $fh"
    }
    
    while {[gets $fh line] >= 0} {
        if {[regexp {^## } $line]} {
            if {[regexp "^##\[\\s\]+${version}(\\\[\\s\\\]|$)" $line]} {
                set found 1
                continue
            }
            if {$found} {
                break
            }
        }
        if {$found} {
            append result "$line\n"
        }
    }
    
    close $fh
    return $result
}

proc markdown_to_html {text} {
    # Convert headers
    regsub -all {^##### (.*)$} $text {<h5>\1</h5>} text
    regsub -all {^#### (.*)$} $text {<h4>\1</h4>} text
    regsub -all {^### (.*)$} $text {<h3>\1</h3>} text
    regsub -all {^## (.*)$} $text {<h2>\1</h2>} text
    
    # Convert list items with bold text
    regsub -all {^- \*\*([^*]*)\*\*(.*)$} $text {<li><strong>\1</strong>\2</li>} text
    
    # Convert regular list items
    regsub -all {^- ([^*].*)$} $text {<li>\1</li>} text
    
    # Convert bold text
    regsub -all {\*\*([^*]*)\*\*} $text {<strong>\1</strong>} text
    
    # Convert inline code
    regsub -all {`([^`]*)`} $text {<code>\1</code>} text
    
    # Convert links
    regsub -all {\[([^\]]*)\]\(([^\)]*)\)} $text {<a href="\2">\1</a>} text
    
    return $text
}

# Main script logic
if {$argc < 1} {
    puts stderr "Usage: [info script] <version> \[changelog_file\]"
    exit 1
}

set VERSION [lindex $argv 0]
set CHANGELOG_FILE ""

if {$argc > 1} {
    set CHANGELOG_FILE [lindex $argv 1]
}

# Find changelog file if not provided
if {$CHANGELOG_FILE eq ""} {
    set script_dir [file dirname [info script]]
    foreach path [list \
        [file join $script_dir .. CHANGELOG.md] \
        "CHANGELOG.md" \
        [file join .. CHANGELOG.md]] {
        if {[file exists $path]} {
            set CHANGELOG_FILE $path
            break
        }
    }
    
    if {$CHANGELOG_FILE eq ""} {
        puts stderr "Error: Could not find CHANGELOG.md"
        exit 1
    }
}

if {![file exists $CHANGELOG_FILE]} {
    puts stderr "Error: Changelog file '$CHANGELOG_FILE' not found"
    exit 1
}

set version_content [extract_version_section $VERSION $CHANGELOG_FILE]

puts "<h2>OpenClaw $VERSION</h2>"

if {$version_content eq ""} {
    puts "<p>Latest OpenClaw update.</p>"
    puts "<p><a href=\"https://github.com/openclaw/openclaw/blob/main/CHANGELOG.md\">View full changelog</a></p>"
    exit 0
}

set in_list false
foreach line [split $version_content "\n"] {
    if {[regexp {^-} $line]} {
        if {!$in_list} {
            puts "<ul>"
            set in_list true
        }
        puts [markdown_to_html $line]
    } else {
        if {$in_list} {
            puts "</ul>"
            set in_list false
        }
        if {$line ne ""} {
            puts [markdown_to_html $line]
        }
    }
}

if {$in_list} {
    puts "</ul>"
}

puts "<p><a href=\"https://github.com/openclaw/openclaw/blob/main/CHANGELOG.md\">View full changelog</a></p>"
