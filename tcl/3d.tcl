#!/usr/bin/env tclsh
# 3d.html — portiert nach tcl
# Quelle: html, Projects@clawhub:public/3d.html
# Erzeugt: 2026-10-27 durch ABSTRACTIONS_MANAGER.py

# Tcl/Tk port of the 3D visualization HTML page using Tk canvas and basic 3D projection

package require Tk

# Create main window
wm title . "ClawHub-Git-Sync — Interaktive Architektur"
wm geometry . 1240x800

# Add scrollbar and canvas for scrolling
text .text -wrap word -state normal -yscrollcommand {.scroll set} -borderwidth 0
scrollbar .scroll -orient vertical -command {.text yview}
pack .scroll -side right -fill y
pack .text -side left -fill both -expand yes

# Configure text widget tags for styling
.text tag configure title -font {Arial 24 bold} -spacing1 10 -spacing3 5
.text tag configure subtitle -font {Arial 12} -foreground #5f6773 -spacing1 5 -spacing3 10
.text tag configure section -font {Arial 16 bold} -spacing1 20 -spacing3 10
.text tag configure normal -font {Arial 11} -spacing1 3 -spacing3 3
.text tag configure muted -font {Arial 10} -foreground #5f6773
.text tag configure link -font {Arial 10 underline} -foreground #f5654a
.text tag configure legend -font {Arial 11} -lmargin1 20 -lmargin2 20

# Insert content
.text insert end "three.js · r128\n" subtitle
.text insert end "ClawHub-Git-Sync\n" title
.text insert end "Zwei Seiten, ein Abgleich: Vergleich, Absicherung, Übertragung — drehen, zoomen, Knoten auswählen.\n\n" subtitle

.text insert end "Architekturübersicht\n" section

# Create canvas for 3D visualization
set canvas [canvas .c -width 800 -height 520 -bg #0e1420]
.text window create end -window $canvas -padx 10 -pady 10

# Add legend
.text insert end "\n\nLegende:\n" section
.text insert end "• Fluss von unten nach oben\n" legend

.text insert end "\n\nSchematische Dokumentationsansicht — Blockgrößen messen weder Datenmenge noch Leistung. Keine Telemetrie, keine Fernabfragen: Die Seite lädt einmalig three.js vom CDN und rechnet danach ausschließlich lokal.\n" muted

# Function to draw 3D-like blocks on canvas
proc drawBlocks {} {
    global canvas
    
    # Clear canvas
    $canvas delete all
    
    # Define layers and blocks
    set layers {
        {name "Seiten" color "#5f6773" blocks {
            {id "workspace-skills" name "workspace/skills" subtitle "ClawHub-Seite"}
            {id "workspace-git-skills" name "workspace/git/skills" subtitle "Git-Seite"}
        }}
        {name "Vergleich" color "#2481cc" blocks {
            {id "zeitstempel" name "Zeitstempel" subtitle "welche Seite neuer"}
            {id "hash" name "Hash" subtitle "ob geaendert"}
            {id "konfliktfall" name "Konfliktfall" subtitle "melden statt raten"}
        }}
        {name "Absicherung" color "#6d5bd0" blocks {
            {id "backup" name "Backup" subtitle "vor jeder Aenderung"}
            {id "dry-run" name "Dry-Run" subtitle "Plan zeigen"}
            {id "freigabe" name "Freigabe" subtitle "manuell"}
        }}
        {name "Uebertragung" color "#b45309" blocks {
            {id "sync-agent-py" name "sync_agent.py" subtitle "der Abgleich"}
            {id "git-commit" name "git commit" subtitle "Historie"}
            {id "clawhub-publish" name "clawhub publish" subtitle "Veroeffentlichung"}
        }}
        {name "Takt" color "#f5654a" blocks {
            {id "cron-alle-12-h" name "Cron alle 12 h" subtitle "unbeaufsichtigt"}
            {id "gateway-skripte" name "Gateway-Skripte" subtitle "mit Sperre"}
        }}
    }
    
    # Draw grid
    for {set i 0} {$i <= 34} {incr i} {
        set x [expr {20 + $i * 22}]
        $canvas create line $x 20 $x 500 -fill #25324a -width 1
    }
    for {set i 0} {$i <= 15} {incr i} {
        set y [expr {20 + $i * 30}]
        $canvas create line 20 $y 780 $y -fill #25324a -width 1
    }
    
    # Draw layers
    set layer_y 60
    foreach layer $layers {
        set layer_name [dict get $layer name]
        set layer_color [dict get $layer color]
        set blocks [dict get $layer blocks]
        
        # Draw layer label
        $canvas create text 10 $layer_y -text $layer_name -fill $layer_color -anchor w -font {Arial 10 bold}
        
        # Draw blocks
        set block_x 100
        foreach block $blocks {
            set block_id [dict get $block id]
            set block_name [dict get $block name]
            set block_subtitle [dict get $block subtitle]
            
            # Draw block rectangle
            $canvas create rectangle $block_x $layer_y [expr {$block_x + 120}] [expr {$layer_y + 40}] \
                -fill $layer_color -outline "" -tags [list block $block_id]
            
            # Draw block border
            $canvas create rectangle $block_x $layer_y [expr {$block_x + 120}] [expr {$layer_y + 40}] \
                -outline #0e1420 -width 2
            
            # Draw block text
            $canvas create text [expr {$block_x + 60}] [expr {$layer_y + 15}] \
                -text $block_name -fill white -font {Arial 8 bold} -anchor center
            $canvas create text [expr {$block_x + 60}] [expr {$layer_y + 30}] \
                -text $block_subtitle -fill white -font {Arial 7} -anchor center
            
            set block_x [expr {$block_x + 140}]
        }
        
        set layer_y [expr {$layer_y + 60}]
    }
    
    # Draw connections
    set connections {
        {from "workspace-skills" to "zeitstempel" color "#f5654a"}
        {from "workspace-git-skills" to "hash" color "#f5654a"}
        {from "zeitstempel" to "backup" color "#f5654a"}
        {from "hash" to "dry-run" color "#f5654a"}
        {from "konfliktfall" to "freigabe" color "#f5654a"}
        {from "backup" to "sync-agent-py" color "#f5654a"}
        {from "dry-run" to "git-commit" color "#f5654a"}
        {from "freigabe" to "clawhub-publish" color "#f5654a"}
        {from "sync-agent-py" to "cron-alle-12-h" color "#f5654a"}
        {from "git-commit" to "gateway-skripte" color "#f5654a"}
        {from "clawhub-publish" to "cron-alle-12-h" color "#f5654a"}
    }
    
    foreach conn $connections {
        set from_id [dict get $conn from]
        set to_id [dict get $conn to]
        set color [dict get $conn color]
        
        # Find coordinates of blocks (simplified)
        set from_coords [$canvas bbox block$from_id]
        set to_coords [$canvas bbox block$to_id]
        
        if {$from_coords != "" && $to_coords != ""} {
            set from_x [expr {[lindex $from_coords 0] + 60}]
            set from_y [lindex $from_coords 1]
            set to_x [expr {[lindex $to_coords 0] + 60}]
            set to_y [lindex $to_coords 3]
            
            $canvas create line $from_x $from_y $to_x $to_y -fill $color -arrow last -width 2
        }
    }
}

# Call function to draw blocks
drawBlocks

# Add control buttons frame
frame .controls -bg white
.text window create end -window .controls -padx 10 -pady 10

# Add buttons
button .controls.plus -text "+" -command {puts "Zoom in"}
button .controls.minus -text "-" -command {puts "Zoom out"}
button .controls.reset -text "Reset" -command {puts "Reset view"}
button .controls.iso -text "Iso" -command {puts "Toggle perspective"}

pack .controls.plus .controls.minus .controls.reset .controls.iso -side left -padx 5 -pady 5

# Make sure the text widget is scrollable
.text configure -state disabled

# Handle command line argument for output file
if {$argc > 0} {
    set filename [lindex $argv 0]
    set fd [open $filename w]
    puts $fd [.text get 1.0 end]
    close $fd
    puts "Content written to $filename"
} else {
    puts "No output file specified. Running in interactive mode."
}
