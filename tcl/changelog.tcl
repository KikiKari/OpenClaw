#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "e29a957f535e2a183bf3bfeb31270d9bca38edc5061a37e7d7cba285f83825b4", "source_sha256": "646ce6bf1521c1200f2204aa19a05521f8f53d734ec8c000b61f4290f2a05074", "target_language": "tcl"}
# changelog.sh — portiert nach tcl
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/pr-lib/changelog.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

proc normalize_pr_changelog_entries {pr} {
    set changelog_path "CHANGELOG.md"
    
    if {![file exists $changelog_path]} {
        return
    }
    
    set fh [open $changelog_path r]
    set original [read $fh]
    close $fh
    
    set lines [split $original "\n"]
    set prPattern "(?:\\(#${pr}\\)|openclaw#${pr})"
    
    proc findActiveSectionIndex {arr} {
        for {set i 0} {$i < [llength $arr]} {incr i} {
            set line [lindex $arr $i]
            if {[string trim $line] eq "## Unreleased"} {
                return $i
            }
        }
        return -1
    }
    
    proc findSectionEnd {arr start} {
        for {set i [expr {$start + 1}]} {$i < [llength $arr]} {incr i} {
            set line [lindex $arr $i]
            if {[regexp {^## } $line]} {
                return $i
            }
        }
        return [llength $arr]
    }
    
    proc ensureActiveSection {arr_var} {
        upvar $arr_var arr
        set activeIndex [findActiveSectionIndex $arr]
        if {$activeIndex != -1} {
            return $activeIndex
        }
        
        set insertAt -1
        for {set i 1} {$i < [llength $arr]} {incr i} {
            set line [lindex $arr $i]
            if {[regexp {^## } $line]} {
                set insertAt $i
                break
            }
        }
        if {$insertAt == -1} {
            set insertAt [llength $arr]
        }
        
        set block [list "## Unreleased" "" "### Changes" ""]
        if {$insertAt > 0 && [lindex $arr [expr {$insertAt - 1}]] ne ""} {
            set block [concat "" $block]
        }
        set arr [linsert $arr $insertAt {*}$block]
        return [findActiveSectionIndex $arr]
    }
    
    proc contextFor {arr index} {
        set major ""
        set minor ""
        for {set i $index} {$i >= 0} {incr i -1} {
            set line [lindex $arr $i]
            if {$minor eq "" && [regexp {^### } $line]} {
                set minor [string trim $line]
            }
            if {[regexp {^## } $line]} {
                set major [string trim $line]
                break
            }
        }
        return [list major $major minor $minor]
    }
    
    proc ensureSubsection {arr_var subsection} {
        upvar $arr_var arr
        set activeIndex [ensureActiveSection arr]
        set activeEnd [findSectionEnd $arr $activeIndex]
        set desired [expr {$subsection ne "" && [regexp {^### } $subsection] ? $subsection : "### Changes"}]
        
        for {set i [expr {$activeIndex + 1}]} {$i < $activeEnd} {incr i} {
            if {[string trim [lindex $arr $i]] eq $desired} {
                return $i
            }
        }
        
        set insertAt $activeEnd
        while {$insertAt > $activeIndex + 1 && [lindex $arr [expr {$insertAt - 1}]] eq ""} {
            incr insertAt -1
        }
        set block [list "" $desired ""]
        set arr [linsert $arr $insertAt {*}$block]
        return [expr {$insertAt + 1}]
    }
    
    proc sectionTailInsertIndex {arr subsectionIndex} {
        set nextHeading [llength $arr]
        for {set i [expr {$subsectionIndex + 1}]} {$i < [llength $arr]} {incr i} {
            set line [lindex $arr $i]
            if {[regexp {^### } $line] || [regexp {^## } $line]} {
                set nextHeading $i
                break
            }
        }
        
        set insertAt $nextHeading
        while {$insertAt > $subsectionIndex + 1 && [lindex $arr [expr {$insertAt - 1}]] eq ""} {
            incr insertAt -1
        }
        return $insertAt
    }
    
    ensureActiveSection lines
    
    set moved {}
    for {set i 0} {$i < [llength $lines]} {incr i} {
        set line [lindex $lines $i]
        if {![regexp -nocase $prPattern $line]} {
            continue
        }
        set ctx [contextFor $lines $i]
        lassign $ctx major major_val minor minor_val
        if {$major_val eq "## Unreleased"} {
            continue
        }
        lappend moved [dict create line $line subsection [expr {$minor_val ne "" ? $minor_val : "### Changes"}] index $i]
    }
    
    if {[llength $moved] == 0} {
        return
    }
    
    set removeIndexes {}
    foreach entry $moved {
        lappend removeIndexes [dict get $entry index]
    }
    
    set nextLines {}
    for {set i 0} {$i < [llength $lines]} {incr i} {
        if {$i ni $removeIndexes} {
            lappend nextLines [lindex $lines $i]
        }
    }
    
    foreach entry $moved {
        set subsectionIndex [ensureSubsection nextLines [dict get $entry subsection]]
        set insertAt [sectionTailInsertIndex $nextLines $subsectionIndex]
        
        set nextHeading [llength $nextLines]
        for {set i [expr {$subsectionIndex + 1}]} {$i < [llength $nextLines]} {incr i} {
            set line [lindex $nextLines $i]
            if {[regexp {^### } $line] || [regexp {^## } $line]} {
                set nextHeading $i
                break
            }
        }
        
        set alreadyPresent 0
        set slice_end [expr {$nextHeading < [llength $nextLines] ? $nextHeading : [llength $nextLines]}]
        set slice [lrange $nextLines [expr {$subsectionIndex + 1}] [expr {$slice_end - 1}]]
        foreach line $slice {
            if {$line eq [dict get $entry line]} {
                set alreadyPresent 1
                break
            }
        }
        
        if {!$alreadyPresent} {
            set nextLines [linsert $nextLines $insertAt [dict get $entry line]]
        }
    }
    
    set updated [join $nextLines "\n"]
    if {$updated ne $original} {
        set fh [open $changelog_path w]
        puts -nonewline $fh $updated
        close $fh
    }
}

proc validate_changelog_entry_for_pr {pr contrib} {
    # Get added lines from git diff
    set cmd "git diff --unified=0 origin/main...HEAD -- CHANGELOG.md"
    set diff_output [exec {*}[auto_execok sh] -c $cmd]
    
    set added_lines ""
    foreach line [split $diff_output "\n"] {
        if {[regexp {^\+} $line] && ![regexp {^\+\+\+} $line]} {
            append added_lines [string range $line 1 end] "\n"
        }
    }
    set added_lines [string trimright $added_lines]
    
    if {$added_lines eq ""} {
        puts "CHANGELOG.md is in diff but no added lines were detected."
        exit 1
    }
    
    set pr_pattern "(#$pr|openclaw#$pr)"
    
    # Check if any added line contains the PR reference
    set with_pr ""
    foreach line [split $added_lines "\n"] {
        if {[regexp -nocase $pr_pattern $line]} {
            set with_pr $line
            break
        }
    }
    
    if {$with_pr eq ""} {
        puts "CHANGELOG.md update must reference PR #$pr (for example, (#$pr))."
        exit 1
    }
    
    # Create temporary file for diff
    set temp_file [exec mktemp]
    set cmd "git diff --unified=0 origin/main...HEAD -- CHANGELOG.md"
    set fd [open $temp_file w]
    puts -nonewline $fd [exec {*}[auto_execok sh] -c $cmd]
    close $fd
    
    # Process diff to validate placement
    set issue_count 0
    set cmd [list awk -v pr_pattern=$pr_pattern {
BEGIN {
  line_no = 0
  file_line_count = 0
  issue_count = 0
}
FNR == NR {
  if ($0 ~ /^@@ /) {
    if (match($0, /\+[0-9]+/)) {
      line_no = substr($0, RSTART + 1, RLENGTH - 1) + 0
    } else {
      line_no = 0
    }
    next
  }
  if ($0 ~ /^\+\+\+/) {
    next
  }
  if ($0 ~ /^\+/) {
    if (line_no > 0) {
      added[line_no] = 1
      added_text = substr($0, 2)
      if (added_text ~ pr_pattern) {
        pr_added_lines[++pr_added_count] = line_no
        pr_added_text[line_no] = added_text
      }
      line_no++
    }
    next
  }
  if ($0 ~ /^-/) {
    next
  }
  if (line_no > 0) {
    line_no++
  }
  next
}
{
  changelog[FNR] = $0
  file_line_count = FNR
}
END {
  for (idx = 1; idx <= pr_added_count; idx++) {
    entry_line = pr_added_lines[idx]
    release_line = 0
    section_line = 0
    for (i = entry_line; i >= 1; i--) {
      if (section_line == 0 && changelog[i] ~ /^### /) {
        section_line = i
        continue
      }
      if (changelog[i] ~ /^## /) {
        release_line = i
        break
      }
    }
    if (release_line == 0 || changelog[release_line] != "## Unreleased") {
      printf "CHANGELOG.md PR-linked entry must be in ## Unreleased: line %d: %s\n", entry_line, pr_added_text[entry_line]
      issue_count++
      continue
    }
    if (section_line == 0) {
      printf "CHANGELOG.md entry must be inside a subsection (### ...): line %d: %s\n", entry_line, pr_added_text[entry_line]
      issue_count++
      continue
    }

    section_name = changelog[section_line]
    next_heading = file_line_count + 1
    for (i = entry_line + 1; i <= file_line_count; i++) {
      if (changelog[i] ~ /^### / || changelog[i] ~ /^## /) {
        next_heading = i
        break
      }
    }

    for (i = entry_line + 1; i < next_heading; i++) {
      line_text = changelog[i]
      if (line_text ~ /^[[:space:]]*$/) {
        continue
      }
      if (i in added) {
        continue
      }
      printf "CHANGELOG.md PR-linked entry must be appended at the end of section %s: line %d: %s\n", section_name, entry_line, pr_added_text[entry_line]
      printf "Found existing non-added line below it at line %d: %s\n", i, line_text
      issue_count++
      break
    }
  }

  if (issue_count > 0) {
    print "Move this PR changelog entry to the end of its section (just before the next heading)."
    exit 1
  }
}
} $temp_file CHANGELOG.md]
    
    if {[catch {exec {*}$cmd} result]} {
        file delete -force $temp_file
        exit 1
    }
    
    file delete -force $temp_file
    puts "changelog placement validated: PR-linked entries are appended at section tail"
    
    if {$contrib ne "" && $contrib ne "null"} {
        set with_pr_and_thanks ""
        foreach line [split $added_lines "\n"] {
            if {[regexp -nocase $pr_pattern $line] && [regexp -nocase "thanks @$contrib" $line]} {
                set with_pr_and_thanks $line
                break
            }
        }
        
        if {$with_pr_and_thanks eq ""} {
            puts "CHANGELOG.md update must include both PR #$pr and thanks @$contrib on the changelog entry line."
            exit 1
        }
        puts "changelog validated: found PR #$pr + thanks @$contrib"
        return
    }
    
    puts "changelog validated: found PR #$pr (contributor handle unavailable, skipping thanks check)"
}

proc validate_changelog_merge_hygiene {} {
    set cmd "git diff --unified=0 origin/main...HEAD -- CHANGELOG.md"
    set diff [exec {*}[auto_execok sh] -c $cmd]
    
    set removed_lines ""
    foreach line [split $diff "\n"] {
        if {[regexp {^-} $line] && ![regexp {^---} $line]} {
            append removed_lines [string range $line 1 end] "\n"
        }
    }
    set removed_lines [string trimright $removed_lines]
    
    if {$removed_lines eq ""} {
        return
    }
    
    # Extract removed refs using regex equivalent of rg -o '#[0-9]+'
    set removed_refs {}
    set matches [regexp -all -inline {#[0-9]+} $removed_lines]
    foreach match $matches {
        if {$match ni $removed_refs} {
            lappend removed_refs $match
        }
    }
    
    if {[llength $removed_refs] == 0} {
        return
    }
    
    set added_lines ""
    foreach line [split $diff "\n"] {
        if {[regexp {^\+} $line] && ![regexp {^\+\+\+} $line]} {
            append added_lines [string range $line 1 end] "\n"
        }
    }
    set added_lines [string trimright $added_lines]
    
    foreach ref $removed_refs {
        if {$ref eq ""} {
            continue
        }
        if {![string match "*$ref*" $added_lines]} {
            puts "CHANGELOG.md drops existing entry reference $ref without re-adding it."
            puts "Likely merge conflict loss; restore the dropped entry (or keep the same PR ref in rewritten text)."
            exit 1
        }
    }
    
    puts "changelog merge hygiene validated: no dropped PR references"
}
