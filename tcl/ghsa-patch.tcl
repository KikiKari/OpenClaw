#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "0ee71f810656db680582972a5392d28ec658f1b83fb2a6e9354b9b08812c8432", "source_sha256": "f198925e5c21dc828628def1707ba79512014dafa5a425580bbf80881a4b0ed7", "target_language": "tcl"}
# ghsa-patch.mjs — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/ghsa-patch.mjs
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

proc usage {} {
    puts stderr [join {
        "Usage:"
        "  tclsh ghsa-patch.tcl --ghsa <GHSA-id-or-url> \[--repo owner/name\]"
        "    --summary <text> --severity <low|medium|high|critical>"
        "    --description-file <path>"
        "    --vulnerable-version-range <range>"
        "    --patched-versions <range-or-null>"
        "    \[--package openclaw\] \[--ecosystem npm\] \[--cvss <vector>\]"
    } "\n"]
}

proc fail {message} {
    puts stderr $message
    exit 1
}

proc parseArgs {argv} {
    array set out {}
    for {set i 0} {$i < [llength $argv]} {incr i} {
        set arg [lindex $argv $i]
        if {![string match "--*" $arg]} {
            fail "Unexpected argument: $arg"
        }
        set key [string range $arg 2 end]
        set value [lindex $argv [expr {$i + 1}]]
        if {$value eq "" || [string match "--*" $value]} {
            fail "Missing value for --$key"
        }
        set out($key) $value
        incr i
    }
    return [array get out]
}

proc runGh {args} {
    set cmd [list exec gh {*}$args]
    if {[catch {eval $cmd} result]} {
        set errorOutput [lindex $result 0]
        if {$errorOutput eq ""} {
            fail "gh [join $args " "] failed"
        } else {
            fail $errorOutput
        }
    }
    return $result
}

proc deriveRepoFromOrigin {} {
    if {[catch {exec git remote get-url origin} remote]} {
        fail "Could not get origin remote URL"
    }
    set remote [string trim $remote]
    if {[regexp {github\.com[/:]([^/]+)/([^/.]+)(?:\.git)?$} $remote -> owner name]} {
        return "$owner/$name"
    } else {
        fail "Could not parse origin remote: $remote"
    }
}

proc parseGhsaId {value} {
    if {[regexp {(?i)GHSA-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}} $value match]} {
        return $match
    } else {
        fail "Could not parse GHSA id from: $value"
    }
}

proc writeTempJson {data} {
    set tempDir [exec mktemp -d]
    set file [file join $tempDir "ghsa-patch.json"]
    set fh [open $file w]
    puts $fh [format "%s\n" $data]
    close $fh
    return $file
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

# Main script logic
array set args [parseArgs $argv]

if {![info exists args(ghsa)] || ![info exists args(summary)] || 
    ![info exists args(severity)] || ![info exists args(description-file)]} {
    usage
    exit 1
}

set repo [expr {[info exists args(repo)] ? $args(repo) : [deriveRepoFromOrigin]}]
set ghsaId [parseGhsaId $args(ghsa)]
set advisoryPath "/repos/$repo/security-advisories/$ghsaId"
set descriptionPath [file normalize $args(description-file)]

if {![file exists $descriptionPath]} {
    fail "Description file does not exist: $descriptionPath"
}

set currentJson [runGh api -H "X-GitHub-Api-Version: 2022-11-28" $advisoryPath]
if {[catch {::json::json2dict $currentJson} currentDict]} {
    fail "Failed to parse JSON response from GitHub API"
}

set restoredCvss ""
if {[info exists args(cvss)] && $args(cvss) ne ""} {
    set restoredCvss $args(cvss)
} elseif {[dict exists $currentDict cvss vector_string]} {
    set restoredCvss [dict get $currentDict cvss vector_string]
}

set ecosystem [expr {[info exists args(ecosystem)] ? $args(ecosystem) : "npm"}]
set packageName [expr {[info exists args(package)] ? $args(package) : "openclaw"}]
set vulnerableRange [expr {[info exists args(vulnerable-version-range)] ? $args(vulnerable-version-range) : ""}]
set patchedVersionsRaw [expr {[info exists args(patched-versions)] ? $args(patched-versions) : ""}]

if {$vulnerableRange eq ""} {
    fail "Missing --vulnerable-version-range"
}
if {$patchedVersionsRaw eq ""} {
    fail "Missing --patched-versions"
}

set patchedVersions [expr {$patchedVersionsRaw eq "null" ? "" : $patchedVersionsRaw}]
set description [readFile $descriptionPath]

# Build vulnerability object as JSON string
set vulnerabilitiesJson "\[\{\"package\":\{\"ecosystem\":\"$ecosystem\",\"name\":\"$packageName\"\},\"vulnerable_version_range\":\"$vulnerableRange\",\"patched_versions\":\"$patchedVersions\",\"vulnerable_functions\":\[\]\}\]"

set payloadJson "\{\"summary\":\"[string map {"\"" "\\\"" "\n" "\\n"} $args(summary)]\",\"severity\":\"$args(severity)\",\"description\":\"[string map {"\"" "\\\"" "\n" "\\n"} $description]\",\"vulnerabilities\":$vulnerabilitiesJson\}"

set patchFile [writeTempJson $payloadJson]

# Update the advisory with main data
runGh api -H "X-GitHub-Api-Version: 2022-11-28" -X PATCH $advisoryPath --input $patchFile

# Restore CVSS if needed
if {$restoredCvss ne ""} {
    runGh api -H "X-GitHub-Api-Version: 2022-11-28" -X PATCH $advisoryPath -f "cvss_vector_string=$restoredCvss"
}

# Get final state and output it
set refreshedJson [runGh api -H "X-GitHub-Api-Version: 2022-11-28" $advisoryPath]

puts $refreshedJson
