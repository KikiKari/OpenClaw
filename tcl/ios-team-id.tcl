#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "1ef4e01ce8b571aff9456feb4730aba45157e944ccb6dee791e4639c1d348d08", "source_sha256": "ff0a573c1d18ce8554e3d7311f3c2ae463c9664ad4b824e0cb5888b499733213", "target_language": "tcl"}
# ios-team-id.sh — portiert nach tcl
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/ios-team-id.sh
# Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

proc getenv_default {var default} {
    if {[info exists ::env($var)] && $::env($var) ne ""} {
        return $::env($var)
    } else {
        return $default
    }
}

proc getenv_bool {var default} {
    set val [getenv_default $var $default]
    return [expr {$val eq "1" || $val eq "true" || $val eq "yes"}]
}

# Prüfe ob IOS_DEVELOPMENT_TEAM gesetzt ist
if {[info exists ::env(IOS_DEVELOPMENT_TEAM)] && $::env(IOS_DEVELOPMENT_TEAM) ne ""} {
    puts $::env(IOS_DEVELOPMENT_TEAM)
    exit 0
}

# Konfigurationsvariablen
set preferred_team [string map {"\r" ""} [getenv_default IOS_PREFERRED_TEAM_ID \
    [getenv_default OPENCLAW_IOS_DEFAULT_TEAM_ID "Y5PE65HELJ"]]]
set preferred_team_name [string map {"\r" ""} [getenv_default IOS_PREFERRED_TEAM_NAME ""]]
set allow_keychain_fallback [getenv_bool IOS_ALLOW_KEYCHAIN_TEAM_FALLBACK 0]
set prefer_non_free_team [getenv_bool IOS_PREFER_NON_FREE_TEAM 1]

# Arrays für Teams initialisieren
set team_ids [list]
set team_is_free [list]
set team_names [list]

# Python-Befehl finden
proc detect_python {} {
    foreach candidate [list \
        [getenv_default IOS_PYTHON_BIN ""] \
        "python3" "python" "/usr/bin/python3"] {
        if {$candidate eq ""} continue
        if {[catch {exec which $candidate} result]} continue
        if {$result ne ""} {
            return $candidate
        }
    }
    return ""
}

set python_cmd [detect_python]

# Team hinzufügen (ohne Duplikate)
proc append_team {candidate_id candidate_is_free candidate_name} {
    global team_ids team_is_free team_names
    
    set candidate_id [string map {"\r" ""} $candidate_id]
    set candidate_is_free [string map {"\r" ""} $candidate_is_free]
    set candidate_name [string map {"\r" ""} $candidate_name]
    
    if {$candidate_id eq ""} return
    
    # Prüfe auf Duplikate
    if {[lsearch -exact $team_ids $candidate_id] != -1} return
    
    lappend team_ids $candidate_id
    lappend team_is_free $candidate_is_free
    lappend team_names $candidate_name
}

# Teams aus Xcode-Einstellungen laden
proc load_teams_from_xcode_preferences {} {
    global python_cmd
    if {$python_cmd eq ""} return
    
    set plist_path [file join $::env(HOME) Library Preferences com.apple.dt.Xcode.plist]
    if {![file exists $plist_path]} return
    
    if {[catch {exec plutil -extract IDEProvisioningTeams json -o - $plist_path} json_data]} return
    
    if {[catch {exec $python_cmd << "
import json
import sys

try:
    data = json.load(sys.stdin)
except Exception:
    raise SystemExit(0)

if not isinstance(data, dict):
    raise SystemExit(0)

for teams in data.values():
    if not isinstance(teams, list):
        continue
    for team in teams:
        if not isinstance(team, dict):
            continue
        team_id = str(team.get(\"teamID\", \"\")).strip()
        if not team_id:
            continue
        is_free = \"1\" if bool(team.get(\"isFreeProvisioningTeam\", False)) else \"0\"
        team_name = str(team.get(\"teamName\", \"\")).replace(\"\\t\", \" \").strip()
        print(f\"{team_id}\\t{is_free}\\t{team_name}\")
"} result]} return
    
    foreach line [split $result "\n"] {
        if {$line eq ""} continue
        set parts [split $line "\t"]
        if {[llength $parts] >= 3} {
            append_team [lindex $parts 0] [lindex $parts 1] [lindex $parts 2]
        } elseif {[llength $parts] >= 2} {
            append_team [lindex $parts 0] [lindex $parts 1] ""
        } elseif {[llength $parts] >= 1} {
            append_team [lindex $parts 0] "0" ""
        }
    }
}

# Teams aus Legacy-Schlüssel laden
proc load_teams_from_legacy_defaults_key {} {
    if {[catch {exec defaults read com.apple.dt.Xcode IDEProvisioningTeamIdentifiers} result]} return
    
    set teams [regexp -all -inline {[A-Z0-9]{10}} $result]
    foreach team $teams {
        append_team $team "0" ""
    }
}

# Teams aus Xcode-Profilen laden
proc load_teams_from_xcode_managed_profiles {} {
    global python_cmd
    if {$python_cmd eq ""} return
    
    set profiles_dir [file join $::env(HOME) Library MobileDevice "Provisioning Profiles"]
    if {![file isdirectory $profiles_dir]} return
    
    set teams_list [list]
    foreach p [glob -nocomplain [file join $profiles_dir *.mobileprovision]] {
        if {![file exists $p]} continue
        
        if {![catch {exec security cms -D -i $p} plist_data]} {
            if {[catch {exec $python_cmd << "
import plistlib, sys
try:
    raw = sys.stdin.buffer.read()
    if not raw:
        raise SystemExit(0)
    d = plistlib.loads(raw)
    for tid in d.get(\"TeamIdentifier\", []):
        print(tid)
except Exception:
    pass
"} team_result]} {
                foreach team [split $team_result "\n"] {
                    if {$team ne ""} {
                        lappend teams_list $team
                    }
                }
            }
        }
    }
    
    set teams_list [lsort -unique $teams_list]
    foreach team $teams_list {
        append_team $team "0" ""
    }
}

# Prüfen ob Xcode-Account vorhanden ist
proc has_xcode_account {} {
    set plist_path [file join $::env(HOME) Library Preferences com.apple.dt.Xcode.plist]
    if {![file exists $plist_path]} return 0
    
    if {[catch {exec defaults read com.apple.dt.Xcode DVTDeveloperAccountManagerAppleIDLists} accts]} {
        return 0
    }
    
    return [expr {[string length $accts] > 0 && ![string match "*does not exist*" $accts] && [string match "*identifier*" $accts]}]
}

# Hauptausführung
load_teams_from_xcode_preferences
load_teams_from_legacy_defaults_key

if {[llength $team_ids] == 0} {
    load_teams_from_xcode_managed_profiles
}

if {[llength $team_ids] == 0 && $allow_keychain_fallback} {
    if {![catch {exec security find-identity -p codesigning -v} identities]} {
        set teams [regexp -all -inline {\(([A-Z0-9]{10})\)} $identities]
        foreach {match team} $teams {
            append_team $team "0" ""
        }
    }
}

if {[llength $team_ids] == 0} {
    if {[has_xcode_account]} {
        puts stderr "An Apple account is signed in to Xcode, but no Team ID could be resolved."
        puts stderr ""
        puts stderr "On Xcode 16+, team data is not written until you build a project."
        puts stderr "To fix this, do ONE of the following:"
        puts stderr ""
        puts stderr "  1. Open the iOS project in Xcode, select your Team in Signing &"
        puts stderr "     Capabilities, and build once. Then re-run this script."
        puts stderr ""
        puts stderr "  2. Set your Team ID directly:"
        puts stderr "       export IOS_DEVELOPMENT_TEAM=<your-10-char-team-id>"
        puts stderr "     Find your Team ID at: https://developer.apple.com/account#MembershipDetailsCard"
    } elseif {$allow_keychain_fallback} {
        puts stderr "No Apple Team ID found. Open Xcode or install signing certificates first."
    } else {
        puts stderr "No Apple Team ID found in Xcode accounts. Open Xcode → Settings → Accounts and sign in, then retry."
        puts stderr "(Set IOS_ALLOW_KEYCHAIN_TEAM_FALLBACK=1 to allow keychain-only team detection.)"
    }
    exit 1
}

# Suche nach bevorzugtem Team
for {set i 0} {$i < [llength $team_ids]} {incr i} {
    if {[lindex $team_ids $i] eq $preferred_team} {
        puts [lindex $team_ids $i]
        exit 0
    }
}

# Suche nach Team-Namen
if {$preferred_team_name ne ""} {
    set preferred_team_name_lc [string tolower $preferred_team_name]
    for {set i 0} {$i < [llength $team_names]} {incr i} {
        set team_name_lc [string tolower [lindex $team_names $i]]
        if {$team_name_lc eq $preferred_team_name_lc} {
            puts [lindex $team_ids $i]
            exit 0
        }
    }
}

# Bevorzuge nicht-kostenlose Teams
if {$prefer_non_free_team} {
    for {set i 0} {$i < [llength $team_is_free]} {incr i} {
        if {[lindex $team_is_free $i] eq "0"} {
            puts [lindex $team_ids $i]
            exit 0
        }
    }
}

# Gib das erste Team zurück
puts [lindex $team_ids 0]
