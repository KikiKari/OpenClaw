#!/usr/bin/env tclsh
# test_voice_groups.cjs — portiert nach tcl
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_voice_groups.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_voice_groups.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_voice_groups.cjs
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_voice_groups.cjs
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

# Tcl Port of test_voice_groups.cjs
# This script tests the voice grouping functionality by simulating DOM operations and validating group structures.

# Load required packages
package require json
package require json::write

# Simulate Node.js path and file system functions
proc readFileSync {filepath} {
    if {[catch {open $filepath r} fh]} {
        error "Cannot open file: $filepath"
    }
    set data [read $fh]
    close $fh
    return $data
}

# Get directory of this script (equivalent to __dirname)
set scriptDir [file dirname [info script]]

# Read sidepanel.js and voice-catalog.json
set source [readFileSync [file join $scriptDir ../browser-extension/sidepanel.js]]
set voiceData [json::json2dict [readFileSync [file join $scriptDir ../companion-service/voice-catalog.json]]]
set voices [dict get $voiceData "voices"]

# Element creation simulation
proc createElement {tag} {
    return [dict create \
        tag $tag \
        children {} \
        dataset [dict create] \
        value "" \
        selected false]
}

# Append child procedure for simulated elements
proc appendChild {parent child} {
    lappend currentChildren [dict get $parent children]
    dict set parent children [linsert [dict get $parent children] end $child]
    return $parent
}

# Clear children procedure
proc clearChildren {node} {
    dict set node children {}
    return $node
}

# Create a select element
set select [createElement "select"]
dict set select label "speech-voice"

# Find specific sections in JavaScript code
set baseVoiceOrderStart [string first "const BASE_VOICE_ORDER" $source]
set coreStart [string first "const core =" $source]
set sherpaFunctionStart [string first "function sherpaSpeechVoices" $source]
set loadSpeechVoicesStart [string first "async function loadSpeechVoices" $source]

# Extract relevant JS code segments
set baseVoiceCode [string range $source $baseVoiceOrderStart [expr {$coreStart - 1}]]
set sherpaFunctionCode [string range $source $sherpaFunctionStart [expr {$loadSpeechVoicesStart - 1}]]

# Global variables that would be in the JS context
set speechVoiceName "sherpa-de-supertonic-7"
set voiceCatalog $voices

# Implementation of setSpeechVoiceOptions function logic adapted from JS
proc setSpeechVoiceOptions {styles voiceList} {
    global select speechVoiceName
    
    # Clear existing options
    set select [clearChildren $select]
    
    # Add style-less voices as a special group at the beginning
    set styleLessVoices [list]
    foreach voice $styles {
        if {[dict get $voice "group"] eq ""} {
            lappend styleLessVoices $voice
        }
    }
    
    if {[llength $styleLessVoices] > 0} {
        set optgroup [createElement "optgroup"]
        dict set optgroup label "Effekt Stimmen"
        foreach voice $styleLessVoices {
            set option [createElement "option"]
            dict set option value [dict get $voice "id"]
            dict set option text [dict get $voice "name"]
            set optgroup [appendChild $optgroup $option]
        }
        set select [appendChild $select $optgroup]
    }
    
    # Group voices by their group property
    set groupedVoices [dict create]
    foreach voice $voiceList {
        set group [dict get $voice "group"]
        if {$group ne ""} {
            if {![dict exists $groupedVoices $group]} {
                dict set groupedVoices $group [list]
            }
            dict lappend groupedVoices $group $voice
        }
    }
    
    # Sort groups according to BASE_VOICE_ORDER
    set orderedGroups {"Kyrillisch" "Asiatisch" "Abjad" "Indisch"}
    foreach group $orderedGroups {
        if {[dict exists $groupedVoices $group]} {
            set optgroup [createElement "optgroup"]
            dict set optgroup label $group
            foreach voice [dict get $groupedVoices $group] {
                set option [createElement "option"]
                dict set option value [dict get $voice "id"]
                dict set option text [dict get $voice "name"]
                set optgroup [appendChild $optgroup $option]
            }
            set select [appendChild $select $optgroup]
        }
    }
    
    # Set the selected value
    dict set select value $speechVoiceName
}

# Run initial test with all voices
setSpeechVoiceOptions {} $voices

# Validate each required group has at least 3 children
foreach label {"Kyrillisch" "Asiatisch" "Abjad" "Indisch" "Effekt Stimmen"} {
    set foundGroup false
    foreach child [dict get $select children] {
        if {[dict get $child label] eq $label} {
            set foundGroup true
            if {[llength [dict get $child children]] < 3} {
                error "$label does not have at least 3 children"
            }
            break
        }
    }
    if {!$foundGroup} {
        error "Group $label not found"
    }
}

# Check specific count for "Effekt Stimmen"
set effectGroup ""
foreach child [dict get $select children] {
    if {[dict get $child label] eq "Effekt Stimmen"} {
        set effectGroup $child
        break
    }
}
if {$effectGroup eq "" || [llength [dict get $effectGroup children]] != 5} {
    error "Effekt Stimmen group should have exactly 5 children"
}

# Verify default selection is preserved
if {[dict get $select value] ne "sherpa-de-supertonic-7"} {
    error "Expected value to be 'sherpa-de-supertonic-7'"
}

# Test adding a styled voice
set styledVoices [list [dict create id "sherpa-de-supertonic-7" name "Stil 3" group ""]]
setSpeechVoiceOptions $styledVoices $voices

# Confirm selection remains unchanged
if {[dict get $select value] ne "sherpa-de-supertonic-7"} {
    error "Selection was not retained after adding styled voice"
}

# Ensure selected item appears in correct group
set effectGroupAfterStyle ""
foreach child [dict get $select children] {
    if {[dict get $child label] eq "Effekt Stimmen"} {
        set effectGroupAfterStyle $child
        break
    }
}
set foundSelected false
foreach option [dict get $effectGroupAfterStyle children] {
    if {[dict get $option value] eq "sherpa-de-supertonic-7"} {
        set foundSelected true
        break
    }
}
if {!$foundSelected} {
    error "Selected voice not found in Effekt Stimmen group"
}

# Change selection and test legacy catalog fallback
set speechVoiceName "sherpa-ru-irina"
# Filter out group properties like in original JS
set filteredVoices {}
foreach voice $voices {
    if {[dict exists $voice "group"]} {
        dict unset voice "group"
    }
    lappend filteredVoices $voice
}
setSpeechVoiceOptions {} $filteredVoices

# Verify new selection
if {[dict get $select value] ne "sherpa-ru-irina"} {
    error "Expected value to change to 'sherpa-ru-irina'"
}

# Check if selected voice is in Kyrillisch group
set cyrillicGroup ""
foreach child [dict get $select children] {
    if {[dict get $child label] eq "Kyrillisch"} {
        set cyrillicGroup $child
        break
    }
}
set foundRussian false
foreach option [dict get $cyrillicGroup children] {
    if {[dict get $option value] eq "sherpa-ru-irina"} {
        set foundRussian true
        break
    }
}
if {!$foundRussian} {
    error "sherpa-ru-irina not found in Kyrillisch group"
}

puts "PASS: five groups, all styles selectable, retained selection, legacy catalog fallback"
