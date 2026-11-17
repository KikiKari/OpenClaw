#!/usr/bin/env tclsh8.6
# abstraction-provenance: {"artifact_sha256": "23f989b0faebba4638da96342dd04ae3cc0ad2a6858e3a0625e98bbe46aa664a", "source_sha256": "4c10c6b6fd911cb95da119f761f402073d1a836cab6b40a9f3b989536d5df5ec", "target_language": "tcl"}
# git_publish.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/git-publish-agent/scripts/git_publish.py
# auch in: OpenClaw@gateway2:skills/git-publish-agent/scripts/git_publish.py
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

# Git Publish Agent - Automatisierte Skill-Veröffentlichung

package require cmdline
package require fileutil
package require json

set SKILLS_DIR [file join $env(HOME) .openclaw workspace skills]

proc git_commit {skill_path {message ""}} {
    global SKILLS_DIR
    
    if {$message eq ""} {
        set timestamp [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S"]
        set message "[skill] Auto-update [file tail $skill_path] - $timestamp"
    }
    
    set parent_dir [file dirname $SKILLS_DIR]
    
    if {[catch {exec git add $skill_path} err]} {
        puts stderr "Git add failed: $err"
        return 0
    }
    
    if {[catch {exec git commit -m $message} result]} {
        if {[string match "*nothing to commit*" $result]} {
            return 1
        } else {
            puts stderr "Git commit failed: $result"
            return 0
        }
    }
    
    return 1
}

proc clawhub_publish {skill_name} {
    global SKILLS_DIR
    
    set skill_path [file join $SKILLS_DIR $skill_name]
    
    if {[catch {exec clawhub publish $skill_path \
                 --slug $skill_name \
                 --version 1.0.0} result]} {
        return [list 0 $result]
    }
    
    return [list 1 $result]
}

proc batch_publish {} {
    global SKILLS_DIR
    
    if {[catch {exec git status --short $SKILLS_DIR} result]} {
        puts stderr "Git status failed: $result"
        return
    }
    
    set changed {}
    foreach line [split $result \n] {
        if {[string trim $line] ne "" && [string match "*skills/*" $line]} {
            set parts [split $line "/"]
            set skill_index [lsearch $parts "skills"]
            if {$skill_index >= 0 && $skill_index < [expr {[llength $parts] - 1}]} {
                set skill [lindex $parts [expr {$skill_index + 1}]]
                if {$skill ni $changed} {
                    lappend changed $skill
                }
            }
        }
    }
    
    puts "Changed skills: $changed"
    
    # Publish with delay (limit to first 5)
    set count 0
    foreach skill [lrange $changed 0 4] {
        if {$count > 0} {
            puts "Waiting 15min for rate limit..."
            # In real: after 900000
        }
        
        puts "Publishing $skill..."
        set commit_ok [git_commit [file join $SKILLS_DIR $skill]]
        if {$commit_ok} {
            foreach {pub_ok output} [clawhub_publish $skill] break
            set mark [expr {$pub_ok ? "✓" : "✗"}]
            puts "  $mark $output"
        }
        incr count
    }
}

proc main {} {
    global SKILLS_DIR
    
    set optionsSpec {
        {skill.arg "" "Single skill to publish"}
        {all "Publish all changed"}
        {no-publish "Commit only"}
        {message.arg "" "Custom commit message"}
    }
    
    if {[catch {cmdline::getoptions argv $optionsSpec} params]} {
        puts stderr "Error parsing arguments: $params"
        exit 1
    }
    
    array set opts $params
    
    if {$opts(skill) ne ""} {
        set skill_path [file join $SKILLS_DIR $opts(skill)]
        if {$opts(no-publish)} {
            git_commit $skill_path $opts(message)
        } else {
            git_commit $skill_path $opts(message)
            clawhub_publish $opts(skill)
        }
    } elseif {$opts(all)} {
        batch_publish
    } else {
        puts "Use --skill <name> or --all"
    }
}

if {[info script] eq $argv0} {
    main
}
